-- Syncline: quest progress of the group, and group quests.
--
-- Progress: every Syncline sends how far it is with the quests of the step
-- it's at (objectives done of objectives needed, "!" when the quest is done):
--   O^<protocol>^<quest>=<done>/<needed>[!],...
-- The window shows each quest with everyone's progress, and once everyone is
-- done Syncline says so: off to turn it in.
--
-- Group quests: for a step that RestedXP marks as a group step (".group"),
-- Syncline shows who doesn't have its quests (from what each one's guide still
-- wants, see Share.lua) and who isn't in range.

local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local C = T.C
local P = {}
ns.Progress = P

local MAX_QUESTS = 4
local mine = {}            -- [quest] = { done, need, complete }
local mineOrder = {}       -- my quests in step order
local others = {}          -- [bare name] = { [quest] = { done, need, complete } }
local announced = {}       -- [quest] = true once "everyone is done" was said
local lastSent

local function H() return ns.Missing end
local function Bare(name) return (tostring(name or ""):gsub("[%- ].*", "")) end

---------------------------------------------------------------------------
-- My progress
---------------------------------------------------------------------------
local function Objectives(q)
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return 0, 0 end
    local ok, list = pcall(C_QuestLog.GetQuestObjectives, q)
    if not ok or type(list) ~= "table" then return 0, 0 end
    local done, need = 0, 0
    for _, o in ipairs(list) do
        if type(o) == "table" then
            local r = tonumber(o.numRequired) or 1
            local f = tonumber(o.numFulfilled) or (o.finished and r or 0)
            need = need + r
            done = done + math.min(f, r)
        end
    end
    return done, need
end

local function IsComplete(q)
    local rxp = H().RXP()
    if rxp and rxp.IsQuestComplete then
        local ok, v = pcall(rxp.IsQuestComplete, q)
        if ok then return v and true or false end
    end
    return C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(q) and true or false
end

-- the quests of the step I'm at that have something to do
function P:Scan()
    local guide, cur = H().CurrentStep()
    local step = guide and cur and guide.steps[cur]
    local list, order, seen = {}, {}, {}
    for _, e in ipairs(H().Elements(step)) do
        local q = type(e) == "table" and tonumber(e.questId)
        if q and not seen[q] and (e.tag == "complete" or e.tag == "turnin") and H().OnQuest(q) then
            seen[q] = true
            local done, need = Objectives(q)
            local complete = IsComplete(q)
            if need > 0 or complete then
                list[q] = { done = done, need = need, complete = complete }
                order[#order + 1] = q
                if #order >= MAX_QUESTS then break end
            end
        end
    end
    mine, mineOrder = list, order
    return list
end

function P:Send(force)
    if not ns.Send or not (IsInGroup and IsInGroup()) then return end
    local parts = {}
    for _, q in ipairs(mineOrder) do
        local p = mine[q]
        parts[#parts + 1] = ("%d=%d/%d%s"):format(q, p.done, p.need, p.complete and "!" or "")
    end
    local text = table.concat(parts, ",")
    if text == lastSent and not force then return end
    lastSent = text
    ns.Send("O", text)
end

function P:OnMessage(who, f)
    local t = {}
    for q, done, need, bang in tostring(f[3] or ""):gmatch("(%d+)=(%d+)/(%d+)(!?)") do
        t[tonumber(q)] = { done = tonumber(done), need = tonumber(need), complete = bang == "!" }
    end
    others[who] = t
    P:CheckAllDone()
    if ns.Changed then ns.Changed() end
end

function P:Forget() wipe(others); wipe(announced); lastSent = nil end

-- a member's progress on quest q (name as in the window)
function P:Get(name, me, q)
    if me then return mine[q] end
    local t = others[Bare(name)]
    return t and t[q]
end

---------------------------------------------------------------------------
-- The quests to show, and "everyone is done"
---------------------------------------------------------------------------
-- quests in order: mine first, then the others'
function P:Quests()
    local out, seen = {}, {}
    for _, q in ipairs(mineOrder) do seen[q] = true; out[#out + 1] = q end
    local extra = {}
    for _, t in pairs(others) do
        for q in pairs(t) do if not seen[q] then seen[q] = true; extra[#extra + 1] = q end end
    end
    table.sort(extra)
    for _, q in ipairs(extra) do out[#out + 1] = q end
    return out
end

-- everyone with Syncline who is on quest q: is everyone done?
function P:AllDone(q)
    local n, done = 0, 0
    local function count(p)
        if p then n = n + 1; if p.complete then done = done + 1 end end
    end
    count(mine[q])
    for _, t in pairs(others) do count(t[q]) end
    return n >= 2 and done == n, n
end

function P:CheckAllDone()
    if not ns.db or not ns.db.questProgress then return end
    for _, q in ipairs(P:Quests()) do
        local all = P:AllDone(q)
        if all and not announced[q] then
            announced[q] = true
            if ns.Print then ns.Print("|cff5cd97a" .. L.ALL_DONE:format(ns.QuestName and ns.QuestName(q) or ("#" .. q)) .. "|r") end
            if PlaySound and SOUNDKIT and SOUNDKIT.READY_CHECK then pcall(PlaySound, SOUNDKIT.READY_CHECK) end
        elseif not all then
            announced[q] = nil
        end
    end
end

---------------------------------------------------------------------------
-- Group quests: the step I'm at is a group step
---------------------------------------------------------------------------
-- { quests = {ids}, size = n } or nil
function P:GroupStep()
    local guide, cur = H().CurrentStep()
    local step = guide and cur and guide.steps[cur]
    if not step or not step.group then return nil end
    local quests, seen = {}, {}
    for _, e in ipairs(H().Elements(step)) do
        local q = type(e) == "table" and tonumber(e.questId)
        if q and not seen[q] and (e.tag == "accept" or e.tag == "complete" or e.tag == "turnin") then
            seen[q] = true
            quests[#quests + 1] = q
        end
    end
    return { quests = quests }
end

-- who lacks which quest of the group step, who is out of range: { { name, class, lacks = {ids}, far } }
function P:GroupCheck(snap)
    local gs = P:GroupStep()
    if not gs then return nil end
    local out = {}
    for _, m in ipairs(snap.members) do
        if not m.me then
            local lacks = {}
            for _, q in ipairs(gs.quests) do
                if ns.Share and ns.Share:Wants(m.name, q) then lacks[#lacks + 1] = q end
            end
            local far = false
            if m.unit and UnitInRange then
                local ok, inRange, checked = pcall(UnitInRange, m.unit)
                if ok and checked and not inRange then far = true end
            end
            if m.connected == false then far = true end
            if #lacks > 0 or far then
                out[#out + 1] = { name = Bare(m.name), class = m.class, lacks = lacks, far = far }
            end
        end
    end
    return out, gs
end

---------------------------------------------------------------------------
-- In the group window
---------------------------------------------------------------------------
local card, rows
local ROW_H, SHOW = 22, 6

function P:Attach(parent, x, width)
    card = T.Card(parent, "Quest progress", x, 0, width, 100)
    rows = {}
    for i = 1, SHOW do
        local r = CreateFrame("Frame", nil, card)
        r:SetSize(width - 2, ROW_H)
        r:SetPoint("TOPLEFT", 1, -30 - (i - 1) * ROW_H)
        r.left = T.Text(r, "", 12, C.text, true)
        r.left:SetPoint("LEFT", 14, 0)
        r.left:SetWidth(150)
        r.left:SetWordWrap(false)
        r.right = T.Text(r, "", 12, C.muted, true)
        r.right:SetPoint("LEFT", 168, 0)
        r.right:SetPoint("RIGHT", -10, 0)
        r.right:SetWordWrap(false)
        rows[i] = r
    end
    return card
end

local function Line(r, left, right)
    r.left:SetText(left)
    r.right:SetText(right)
    r:Show()
end

function P:Layout(y, snap)
    if not card then return 0 end
    if not snap.inGroup then card:Hide(); return 0 end
    local n = 0
    local function row(left, right)
        if n >= SHOW then return end
        n = n + 1
        Line(rows[n], left, right)
    end

    -- group step first: it's what stops the group
    if ns.db.groupQuestCheck then
        local check = P:GroupCheck(snap)
        if check then
            if #check == 0 then
                row("|cff" .. T.Hex(C.accent) .. L["Group step"] .. "|r", "|cff5cd97a" .. L["everyone has the quest and is close"] .. "|r")
            else
                for _, c in ipairs(check) do
                    local why = {}
                    if #c.lacks > 0 then
                        local names = {}
                        for i, q in ipairs(c.lacks) do names[i] = ns.QuestName and ns.QuestName(q) or ("#" .. q) end
                        why[#why + 1] = L["lacks %s"]:format(table.concat(names, ", "))
                    end
                    if c.far then why[#why + 1] = L["not in range"] end
                    row("|cff" .. T.Hex(C.accent) .. L["Group step"] .. "|r  |cff" .. T.ClassHex(c.class) .. c.name .. "|r",
                        "|cff" .. T.Hex(C.warn) .. table.concat(why, " · ") .. "|r")
                end
            end
        end
    end

    if ns.db.questProgress then
        for _, q in ipairs(P:Quests()) do
            local all = P:AllDone(q)
            local name = ns.QuestName and ns.QuestName(q) or ("#" .. q)
            local parts = {}
            for _, m in ipairs(snap.members) do
                local p = P:Get(m.name, m.me, q)
                if p then
                    local who = "|cff" .. T.ClassHex(m.class) .. Bare(m.name) .. "|r "
                    if p.complete then
                        parts[#parts + 1] = who .. "|cff5cd97a" .. (p.need > 0 and (p.need .. "/" .. p.need) or L["done"]) .. "|r"
                    else
                        parts[#parts + 1] = who .. "|cffffffff" .. p.done .. "/" .. p.need .. "|r"
                    end
                end
            end
            if #parts > 0 then
                row((all and "|cff5cd97a" or "|cffffffff") .. name .. "|r", table.concat(parts, "  "))
            end
        end
    end

    for i = n + 1, SHOW do rows[i]:Hide() end
    if n == 0 then card:Hide(); return 0 end
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", 12, y)
    card:Show()
    local h = 30 + n * ROW_H + 8
    card:SetHeight(h)
    return h
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local pending = false
function P.Soon()
    if pending then return end
    pending = true
    C_Timer.After(1, function()
        pending = false
        P:Scan()
        P:Send()
        P:CheckAllDone()
        if ns.Changed then ns.Changed() end
    end)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function() P.Soon() end)
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "GROUP_ROSTER_UPDATE" }) do
    ev:RegisterEvent(e)
end
