-- Syncline: experience overview of the group. The game only tells each
-- player his own experience, so every Syncline measures its own and sends it:
--   X^<protocol>^<level>^<xp>^<max>^<rested>^<xp per hour>^<ready>^<all>
-- ready: experience of the quests in the log that can be turned in now,
-- all: of every quest in the log. xp per hour over the last 30 minutes.

local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local C = T.C
local X = {}
ns.XP = X

local WINDOW = 30 * 60      -- xp per hour over this many seconds
local MIN_TIME = 120        -- no rate before this many seconds of data
local info = {}             -- [bare name] = { level, xp, max, rested, rate, ready, all, at }
local samples = {}          -- { { t, total } }, total = xp gained since login, over level-ups
local total, lastXP, lastMax = 0, nil, nil

local function Now() return GetTime and GetTime() or 0 end

---------------------------------------------------------------------------
-- Measuring myself
---------------------------------------------------------------------------
local function Num(v) return tonumber(v) or 0 end

-- experience of quests in the log: ready to turn in, all
local function QuestXP()
    local ready, all = 0, 0
    local function Reward(questID, index)
        if not GetQuestLogRewardXP then return 0 end
        local ok, xp = pcall(GetQuestLogRewardXP, questID)
        if (not ok or not tonumber(xp)) and index and SelectQuestLogEntry then
            pcall(SelectQuestLogEntry, index)
            ok, xp = pcall(GetQuestLogRewardXP)
        end
        return ok and Num(xp) or 0
    end
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local ok, n = pcall(C_QuestLog.GetNumQuestLogEntries)
        for i = 1, ok and Num(n) or 0 do
            local ok2, q = pcall(C_QuestLog.GetInfo, i)
            if ok2 and type(q) == "table" and not q.isHeader and q.questID then
                local xp = Reward(q.questID, i)
                all = all + xp
                local done = C_QuestLog.IsComplete and C_QuestLog.IsComplete(q.questID)
                if done then ready = ready + xp end
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, Num(GetNumQuestLogEntries()) do
            local _, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
            if not isHeader and questID then
                local xp = Reward(questID, i)
                all = all + xp
                if isComplete == 1 or isComplete == true then ready = ready + xp end
            end
        end
    end
    return ready, all
end

-- count gained experience (also over a level-up)
function X:Sample()
    local xp, max = Num(UnitXP("player")), Num(UnitXPMax("player"))
    if lastXP then
        if xp >= lastXP then total = total + (xp - lastXP)
        else total = total + ((lastMax or max) - lastXP) + xp end   -- level-up
    end
    lastXP, lastMax = xp, max
    local now = Now()
    samples[#samples + 1] = { now, total }
    while #samples > 2 and now - samples[2][1] > WINDOW do table.remove(samples, 1) end
end

-- xp per hour (nil while there isn't enough data)
function X:Rate()
    local first, last = samples[1], samples[#samples]
    if not first or not last then return nil end
    local dt = Now() - first[1]
    if dt < MIN_TIME then return nil end
    return (last[2] - first[2]) / dt * 3600
end

function X:Mine()
    local ready, all = QuestXP()
    local max = Num(UnitXPMax("player"))
    return {
        level = Num(UnitLevel("player")), xp = Num(UnitXP("player")), max = max,
        rested = Num(GetXPExhaustion and GetXPExhaustion()), rate = X:Rate(),
        ready = ready, all = all, at = Now(),
    }
end

function X:Send()
    if not ns.Send or not (IsInGroup and IsInGroup()) then return end
    local m = X:Mine()
    ns.Send("X", m.level, m.xp, m.max, m.rested, m.rate and math.floor(m.rate) or "", m.ready, m.all)
end

function X:OnMessage(who, f)
    info[who] = {
        level = Num(f[3]), xp = Num(f[4]), max = Num(f[5]), rested = Num(f[6]),
        rate = tonumber(f[7]), ready = Num(f[8]), all = Num(f[9]), at = Now(),
    }
    if ns.Changed then ns.Changed() end
end

-- data for a group member (name as in the window; nil when unknown)
function X:Get(name, me)
    if me then return X:Mine() end
    return info[(name or ""):gsub("[%- ].*", "")]
end

function X:Forget() wipe(info) end

---------------------------------------------------------------------------
-- Numbers
---------------------------------------------------------------------------
local function Short(n)
    n = Num(n)
    local function f(v, unit) return (("%.1f"):format(v):gsub("%.0$", "")) .. unit end
    if n >= 1e6 then return f(n / 1e6, "M") end
    if n >= 1e5 then return ("%.0fk"):format(n / 1e3) end
    if n >= 1e3 then return f(n / 1e3, "k") end
    return tostring(math.floor(n))
end
X.Short = Short

local function Duration(sec)
    if not sec or sec ~= sec or sec == math.huge then return nil end
    sec = math.floor(sec)
    if sec >= 3600 then return ("%d:%02d h"):format(sec / 3600, (sec % 3600) / 60) end
    return ("%d min"):format(math.max(1, math.floor(sec / 60 + 0.5)))
end
X.Duration = Duration

-- missing, time to level, time to level after turning in the ready quests
function X:Times(d)
    if not d or d.max <= 0 then return end
    local missing = math.max(0, d.max - d.xp)
    local afterTurnIn = math.max(0, missing - d.ready)
    local t = d.rate and d.rate > 0 and missing / d.rate * 3600 or nil
    local t2 = d.rate and d.rate > 0 and afterTurnIn / d.rate * 3600 or nil
    return missing, t, afterTurnIn, t2
end

---------------------------------------------------------------------------
-- In the group window: a card with one row per member
---------------------------------------------------------------------------
local card, rows, empty
local ROW_H, SHOW = 26, 10

function X:Attach(parent, x, width)
    card = T.Card(parent, "Experience", x, 0, width, 100)
    empty = T.Text(card, "", 12, C.muted, true)
    empty:SetPoint("TOPLEFT", 20, -34)
    empty:SetPoint("RIGHT", -12, 0)
    empty:SetWordWrap(true)
    rows = {}
    for i = 1, SHOW do
        local r = CreateFrame("Frame", nil, card)
        r:SetSize(width - 2, ROW_H)
        r:SetPoint("TOPLEFT", 1, -30 - (i - 1) * ROW_H)
        r.name = T.Text(r, "", 13, C.text, true)
        r.name:SetPoint("LEFT", 14, 0)
        r.name:SetWidth(92)
        r.name:SetWordWrap(false)
        -- bar: experience, rested, ready quests
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetPoint("LEFT", 110, 0)
        r.bg:SetSize(150, 14)
        r.bg:SetColorTexture(0.12, 0.13, 0.15, 1)
        r.fill = r:CreateTexture(nil, "BORDER")
        r.fill:SetPoint("LEFT", r.bg, "LEFT")
        r.fill:SetHeight(14)
        r.rest = r:CreateTexture(nil, "BORDER")
        r.rest:SetHeight(14)
        r.quest = r:CreateTexture(nil, "ARTWORK")
        r.quest:SetHeight(14)
        r.barText = T.Text(r, "", 11, C.text, true)
        r.barText:SetPoint("CENTER", r.bg, "CENTER")
        r.right = T.Text(r, "", 11, C.muted, true)
        r.right:SetPoint("LEFT", 268, 0)
        r.right:SetPoint("RIGHT", -8, 0)
        r.right:SetWordWrap(false)
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self) X:Tooltip(self) end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = r
    end
    return card
end

function X:Tooltip(r)
    local d = r.data
    if not d then return end
    local missing, t, after, t2 = X:Times(d)
    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
    GameTooltip:AddLine(r.who or "")
    GameTooltip:AddDoubleLine(L["Level"], d.level, C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
    if d.max > 0 then
        GameTooltip:AddDoubleLine(L["Experience"], ("%s / %s"):format(Short(d.xp), Short(d.max)),
            C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
        GameTooltip:AddDoubleLine(L["Missing"], Short(missing), C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
        if d.rested > 0 then
            GameTooltip:AddDoubleLine(L["Rested"], Short(d.rested), C.muted[1], C.muted[2], C.muted[3], 0.5, 0.75, 1)
        end
    end
    GameTooltip:AddDoubleLine(L["Ready to turn in"], Short(d.ready), C.muted[1], C.muted[2], C.muted[3],
        C.good[1], C.good[2], C.good[3])
    GameTooltip:AddDoubleLine(L["All quests in the log"], Short(d.all), C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Per hour"], d.rate and Short(d.rate) or L["measuring ..."],
        C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
    if d.max > 0 then
        if d.ready >= missing and d.ready > 0 then
            GameTooltip:AddLine(L["Turning in the ready quests is enough for the level-up!"], C.good[1], C.good[2], C.good[3], true)
        end
        if t then GameTooltip:AddDoubleLine(L["Level-up in"], Duration(t), C.muted[1], C.muted[2], C.muted[3], 1, 1, 1) end
        if t2 and d.ready > 0 and after > 0 then
            GameTooltip:AddDoubleLine(L["After turning in"], Duration(t2), C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

-- place the card at y; returns its height (0 when hidden)
function X:Layout(y, snap)
    if not card then return 0 end
    if not (snap.inGroup and ns.db.xpOverview) then
        card:Hide()
        return 0
    end
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", 12, y)
    card:Show()
    local shown = 0
    for _, m in ipairs(snap.members) do
        local d = X:Get(m.name, m.me)
        if d and shown < SHOW then
            shown = shown + 1
            local r = rows[shown]
            r.data, r.who = d, m.name:gsub("[%- ].*", "")
            r.name:SetText("|cff" .. T.ClassHex(m.class) .. r.who .. "|r  |cff" .. T.Hex(C.faint) .. d.level .. "|r")
            local w = 150
            if d.max > 0 then
                local p = math.min(1, d.xp / d.max)
                local rp = math.min(1 - p, d.rested / d.max)
                local qp = math.min(1 - p, d.ready / d.max)
                r.fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
                r.fill:SetWidth(math.max(1, w * p))
                r.rest:ClearAllPoints()
                r.rest:SetPoint("LEFT", r.bg, "LEFT", w * p, 0)
                r.rest:SetWidth(math.max(0.01, w * rp))
                r.rest:SetColorTexture(0.35, 0.55, 1, 0.35)
                r.quest:ClearAllPoints()
                r.quest:SetPoint("LEFT", r.bg, "LEFT", w * p, 0)
                r.quest:SetWidth(math.max(0.01, w * qp))
                r.quest:SetColorTexture(C.good[1], C.good[2], C.good[3], 0.55)
                local missing, t, after = X:Times(d)
                r.barText:SetText(L["%s missing"]:format(Short(missing)))
                local right = d.rate and (Short(d.rate) .. L["/h"]) or "–"
                if after == 0 and d.ready > 0 then
                    right = right .. "  |cff" .. T.Hex(C.good) .. L["turn in!"] .. "|r"
                elseif t then
                    right = right .. "  ≈ " .. Duration(t)
                end
                r.right:SetText(right)
            else
                r.fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
                r.fill:SetWidth(w)
                r.rest:SetWidth(0.01); r.quest:SetWidth(0.01)
                r.barText:SetText(L["max level"])
                r.right:SetText("")
            end
            r:Show()
        end
    end
    for i = shown + 1, SHOW do rows[i]:Hide() end
    empty:SetText(L["Nobody sent experience yet (everyone needs Syncline)."])
    empty:SetShown(shown == 0)
    local h = shown > 0 and (30 + shown * ROW_H + 8) or 64
    card:SetHeight(h)
    return h
end

---------------------------------------------------------------------------
-- Events: measure, and tell the group now and then
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        lastXP, lastMax = nil, nil
        X:Sample()
    else
        X:Sample()
    end
    -- the group hears about it at most every 10 seconds
    if not X.pending then
        X.pending = true
        C_Timer.After(10, function() X.pending = false; X:Send() end)
    end
end)
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "QUEST_LOG_UPDATE",
                     "UPDATE_EXHAUSTION", "GROUP_ROSTER_UPDATE" }) do
    ev:RegisterEvent(e)
end
-- keep the rate going even without new experience (it falls while nothing happens)
C_Timer.NewTicker(60, function() X:Sample() end)
