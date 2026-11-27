-- Syncline: share quests. Every Syncline sends the quests its guide still
-- wants from here on (to accept, complete or turn in) that are neither in its
-- log nor turned in:
--   H^<protocol>^<quest id,quest id,...>   (the next 30, in guide order)
-- I see which quests of my log the others want, and share them with a click,
-- or Syncline shares them by itself (/sl autoshare).

local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local C = T.C
local S = {}
ns.Share = S

local MAX_SENT = 30
local AGAIN_AFTER = 60     -- seconds before the same quest is shared again
local wanted = {}          -- [bare name] = { [quest id] = true }
local mineWanted = {}      -- my wanted quests, in guide order
local sharedAt = {}        -- [quest id] = time I last shared it
local lastSent

local function H() return ns.Missing end
local function Now() return GetTime and GetTime() or 0 end

---------------------------------------------------------------------------
-- What my guide still wants that I don't have
---------------------------------------------------------------------------
function S:Scan()
    local guide, cur = H().CurrentStep()
    local list, seen = {}, {}
    if guide and cur then
        for i = cur, #guide.steps do
            for _, e in ipairs(H().Elements(guide.steps[i])) do
                local q = type(e) == "table" and tonumber(e.questId)
                if q and not seen[q] and (e.tag == "accept" or e.tag == "complete" or e.tag == "turnin") then
                    seen[q] = true
                    if not H().OnQuest(q) and not H().TurnedIn(q) then list[#list + 1] = q end
                    if #list >= MAX_SENT then break end
                end
            end
            if #list >= MAX_SENT then break end
        end
    end
    mineWanted = list
    return list
end

function S:Send(force)
    if not ns.Send or not (IsInGroup and IsInGroup()) then return end
    local text = table.concat(mineWanted, ",")
    if text == lastSent and not force then return end
    lastSent = text
    ns.Send("H", text)
end

function S:OnMessage(who, f)
    local set = {}
    for q in tostring(f[3] or ""):gmatch("%d+") do set[tonumber(q)] = true end
    wanted[who] = set
    if ns.Changed then ns.Changed() end
    if ns.db and ns.db.autoShare then S:AutoShare() end
end

function S:Forget() wipe(wanted); lastSent = nil end

---------------------------------------------------------------------------
-- What I can give: quests in my log that others want
---------------------------------------------------------------------------
local function LogQuests()
    local out = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local ok, n = pcall(C_QuestLog.GetNumQuestLogEntries)
        for i = 1, ok and tonumber(n) or 0 do
            local q = C_QuestLog.GetInfo(i)
            if type(q) == "table" and not q.isHeader and q.questID then out[#out + 1] = q.questID end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, (GetNumQuestLogEntries()) or 0 do
            local _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(i)
            if not isHeader and id then out[#out + 1] = id end
        end
    end
    return out
end

-- log index and whether the game lets me share it
local function Pushable(q)
    local rxp = H().RXP()
    if rxp and rxp.GetLogIndexForQuestID then
        local ok, index, pushable = pcall(rxp.GetLogIndexForQuestID, q)
        if ok then return index, pushable and true or false end
    end
    local index = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(q)
    local pushable = C_QuestLog and C_QuestLog.IsPushableQuest and C_QuestLog.IsPushableQuest(q)
    return index, pushable and true or false
end

-- { { quest, who = { names } } }: my shareable quests that someone wants
function S:Offers()
    local out = {}
    for _, q in ipairs(LogQuests()) do
        local who = {}
        for name, set in pairs(wanted) do if set[q] then who[#who + 1] = name end end
        if #who > 0 then
            local _, pushable = Pushable(q)
            if pushable then
                table.sort(who)
                out[#out + 1] = { quest = q, who = who }
            end
        end
    end
    return out
end

-- share one quest with the group (the game sends it to everyone in it)
function S:ShareQuest(q, quiet)
    if InCombatLockdown() then return false end
    local index, pushable = Pushable(q)
    if not index or not pushable then return false end
    if C_QuestLog and C_QuestLog.SetSelectedQuest then pcall(C_QuestLog.SetSelectedQuest, q) end
    if SelectQuestLogEntry then pcall(SelectQuestLogEntry, index) end
    local ok = pcall(QuestLogPushQuest, index)
    if not ok then return false end
    sharedAt[q] = Now()
    if not quiet and ns.Print then
        local who = {}
        for name, set in pairs(wanted) do if set[q] then who[#who + 1] = name end end
        table.sort(who)
        ns.Print(L.SHARED, ns.QuestName and ns.QuestName(q) or ("#" .. q), table.concat(who, ", "))
    end
    return true
end

-- share everything others want, one quest after another
function S:ShareAll()
    local list = S:Offers()
    for i, o in ipairs(list) do
        C_Timer.After((i - 1) * 1.5, function() S:ShareQuest(o.quest) end)
    end
    return #list
end

-- automatically: quests not shared in the last minute
function S:AutoShare()
    if InCombatLockdown() then return end
    local delay = 0
    for _, o in ipairs(S:Offers()) do
        if not sharedAt[o.quest] or Now() - sharedAt[o.quest] > AGAIN_AFTER then
            sharedAt[o.quest] = Now()   -- reserve, so a second call doesn't queue it again
            C_Timer.After(delay, function() S:ShareQuest(o.quest) end)
            delay = delay + 1.5
        end
    end
end

function S:SetAuto(on)
    ns.db.autoShare = on and true or false
    if ns.Print then ns.Print(ns.db.autoShare and L.AUTOSHARE_ON or L.AUTOSHARE_OFF) end
    if ns.db.autoShare then S:AutoShare() end
    if ns.Changed then ns.Changed() end
end

---------------------------------------------------------------------------
-- In the group window: what I can share
---------------------------------------------------------------------------
local card, rows, allBtn, autoText
local ROW_H, SHOW = 24, 6

function S:Attach(parent, x, width)
    card = T.Card(parent, "Share quests", x, 0, width, 100)
    allBtn = T.FlatButton(card, L["Share all"], 90, 20)
    allBtn:SetPoint("TOPRIGHT", -8, -6)
    allBtn:SetScript("OnClick", function() S:ShareAll() end)
    autoText = T.Text(card, "", 11, C.faint, true)
    autoText:SetPoint("TOPRIGHT", allBtn, "TOPLEFT", -8, -4)
    rows = {}
    for i = 1, SHOW do
        local r = CreateFrame("Frame", nil, card)
        r:SetSize(width - 2, ROW_H)
        r:SetPoint("TOPLEFT", 1, -30 - (i - 1) * ROW_H)
        r.quest = T.Text(r, "", 13, C.text, true)
        r.quest:SetPoint("LEFT", 14, 0)
        r.quest:SetWidth(180)
        r.quest:SetWordWrap(false)
        r.who = T.Text(r, "", 11, C.muted, true)
        r.who:SetPoint("LEFT", 198, 0)
        r.who:SetWidth(100)
        r.who:SetWordWrap(false)
        r.btn = T.FlatButton(r, L["Share"], 64, 20)
        r.btn:SetPoint("RIGHT", -8, 0)
        r.btn:SetScript("OnClick", function(self) if self.quest then S:ShareQuest(self.quest) end end)
        rows[i] = r
    end
    return card
end

function S:Layout(y, snap)
    if not card then return 0 end
    if not (snap.inGroup and ns.db.shareQuests) then card:Hide(); return 0 end
    local list = S:Offers()
    if #list == 0 then card:Hide(); return 0 end
    for i = 1, SHOW do
        local r, o = rows[i], list[i]
        if o then
            r.quest:SetText(ns.QuestName and ns.QuestName(o.quest) or ("#" .. o.quest))
            r.who:SetText(L["for %s"]:format(table.concat(o.who, ", ")))
            r.btn.quest = o.quest
            r:Show()
        else
            r:Hide()
        end
    end
    autoText:SetText(ns.db.autoShare and L["auto"] or "")
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", 12, y)
    card:Show()
    local h = 30 + math.min(SHOW, #list) * ROW_H + 8
    card:SetHeight(h)
    return h
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local pending = false
function S.Soon()
    if pending then return end
    pending = true
    C_Timer.After(2.5, function()
        pending = false
        S:Scan()
        S:Send()
        if ns.db and ns.db.autoShare then S:AutoShare() end
        if ns.Changed then ns.Changed() end
    end)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function() S.Soon() end)
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_ACCEPTED",
                     "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }) do
    ev:RegisterEvent(e)
end
