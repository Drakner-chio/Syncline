-- Syncline: missing quests. Quests that my RestedXP guide still wants me to
-- complete or turn in later, but that are no longer in my quest log (and not
-- turned in, and not picked up again in the guide before then). It warns
-- before I abandon a quest the guide still needs, and the group sees who is
-- missing what:
--   M^<protocol>^<count>^<quest id,quest id,...>   (at most 12 ids)
-- An id with "!" was to be accepted only a few steps ago: not lost, but
-- forgotten when passing its quest giver (the accept check).

local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local C = T.C
local M = {}
ns.Missing = M

local MAX_SENT = 12
local FRESH = 15           -- an accept this many steps back counts as "not accepted"
local mine = {}            -- { { id, step, tag } } my missing quests, in guide order
local others = {}          -- [bare name] = { count, ids = {}, fresh = { [id] = true } }
local told = {}            -- quest ids I already told the player about
local toldOthers = {}      -- ["name:id"] the leader was already told about
local lastSent

local function RXP()
    local ace = LibStub and LibStub("AceAddon-3.0", true)
    return ace and ace:GetAddon("RXPGuides", true) or _G.RXP
end

local function Elements(step)
    return type(step) == "table" and (step.elements or step) or {}
end

local function OnQuest(id)
    local rxp = RXP()
    if rxp and rxp.IsOnQuest then
        local ok, v = pcall(rxp.IsOnQuest, id)
        if ok then return v and true or false end
    end
    if C_QuestLog and C_QuestLog.IsOnQuest then return C_QuestLog.IsOnQuest(id) and true or false end
    return false
end

local function TurnedIn(id)
    local rxp = RXP()
    if rxp and rxp.IsQuestTurnedIn then
        local ok, v = pcall(rxp.IsQuestTurnedIn, id)
        if ok then return v and true or false end
    end
    local f = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or _G.IsQuestFlaggedCompleted
    return f and f(id) and true or false
end

local function CurrentStep()
    local rxp = RXP()
    local guide = rxp and rxp.currentGuide
    if not guide or not guide.steps then return end
    local ok, n = pcall(rxp.GetGuideProgress)
    n = ok and tonumber(n) or tonumber(_G.RXPCData and RXPCData.currentStep)
    return guide, n
end

-- Later steps of my guide that need quest id: { { step, tag } }
function M:NeededLater(id)
    local guide, cur = CurrentStep()
    local out = {}
    if not guide or not cur then return out end
    for i = cur, #guide.steps do
        for _, e in ipairs(Elements(guide.steps[i])) do
            if type(e) == "table" and tonumber(e.questId) == id then
                if e.tag == "accept" and i > cur then return out end   -- picked up again first
                if e.tag == "complete" or e.tag == "turnin" then out[#out + 1] = { step = i, tag = e.tag } end
            end
        end
    end
    return out
end

-- Does the step I'm at tell me to abandon this quest?
local function GuideSaysAbandon(id)
    local guide, cur = CurrentStep()
    local step = guide and cur and guide.steps[cur]
    for _, e in ipairs(Elements(step)) do
        if type(e) == "table" and type(e.ids) == "table" and not e.tag then
            for _, q in ipairs(e.ids) do if tonumber(q) == id then return true end end
        end
    end
end

-- Go through my guide from the step I'm at
function M:Scan()
    local guide, cur = CurrentStep()
    local list, seen, again = {}, {}, {}
    if guide and cur then
        for i = cur, #guide.steps do
            for _, e in ipairs(Elements(guide.steps[i])) do
                local q = type(e) == "table" and tonumber(e.questId)
                if q and not seen[q] then
                    if e.tag == "accept" then
                        again[q] = true
                    elseif (e.tag == "complete" or e.tag == "turnin") and not again[q] then
                        seen[q] = true
                        if not OnQuest(q) and not TurnedIn(q) then
                            -- where the guide had me accept it, if that was just now
                            local acceptStep
                            for j = cur - 1, math.max(1, cur - FRESH), -1 do
                                for _, e2 in ipairs(Elements(guide.steps[j])) do
                                    if type(e2) == "table" and e2.tag == "accept" and tonumber(e2.questId) == q then acceptStep = j end
                                end
                                if acceptStep then break end
                            end
                            list[#list + 1] = { id = q, step = i, tag = e.tag, acceptStep = acceptStep }
                        end
                    end
                end
            end
        end
    end
    mine = list
    return list
end

function M:Mine() return mine end

-- "Ärger am Fluss (turn-in at step 74)"
function M:Describe(entry)
    local name = ns.QuestName and ns.QuestName(entry.id) or ("#" .. entry.id)
    if entry.acceptStep then return L.ACCEPT_FORGOT_SHORT:format(name, entry.acceptStep) end
    local what = entry.tag == "turnin" and L.MISSING_TURNIN or L.MISSING_COMPLETE
    return L.MISSING_ENTRY:format(name, what, entry.step)
end

---------------------------------------------------------------------------
-- Updating, telling me, telling the group
---------------------------------------------------------------------------
function M:Update()
    if not ns.db or not ns.db.missingQuests then mine = {}; return end
    M:Scan()
    -- new ones: once in the chat; one just passed by gets a louder word
    for _, entry in ipairs(mine) do
        if not told[entry.id] then
            told[entry.id] = true
            if entry.acceptStep and ns.Print then
                local name = ns.QuestName and ns.QuestName(entry.id) or ("#" .. entry.id)
                ns.Print("|cffff6060" .. L.ACCEPT_FORGOT:format(name, entry.acceptStep) .. "|r")
                if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
            elseif ns.Print then
                ns.Print(L.MISSING_NEW, M:Describe(entry))
            end
        end
    end
    M:Send()
    if ns.Changed then ns.Changed() end
end

function M:Send(force)
    if not ns.Send or not (IsInGroup and IsInGroup()) then return end
    local ids = {}
    for i = 1, math.min(MAX_SENT, #mine) do ids[i] = mine[i].id .. (mine[i].acceptStep and "!" or "") end
    local text = #mine .. "^" .. table.concat(ids, ",")
    if text == lastSent and not force then return end
    lastSent = text
    ns.Send("M", #mine, table.concat(ids, ","))
end

function M:OnMessage(who, f)
    local ids, fresh = {}, {}
    for q, bang in tostring(f[4] or ""):gmatch("(%d+)(!?)") do
        q = tonumber(q)
        ids[#ids + 1] = q
        if bang == "!" then fresh[q] = true end
    end
    others[who] = { count = tonumber(f[3]) or #ids, ids = ids, fresh = fresh }
    -- the leader hears once about a quest someone didn't accept
    if ns.db and ns.db.missingQuests and UnitIsGroupLeader and UnitIsGroupLeader("player") then
        for q in pairs(fresh) do
            local key = who .. ":" .. q
            if not toldOthers[key] then
                toldOthers[key] = true
                if ns.Print then
                    ns.Print("|cffff9900" .. L.ACCEPT_FORGOT_OTHER:format(who, ns.QuestName and ns.QuestName(q) or ("#" .. q)) .. "|r")
                end
            end
        end
    end
    if ns.Changed then ns.Changed() end
end

-- a member's missing quests (name as in the window): count, ids
function M:Get(name, me)
    if me then
        local ids, fresh = {}, {}
        for i, e in ipairs(mine) do ids[i] = e.id; if e.acceptStep then fresh[e.id] = true end end
        return #mine, ids, fresh
    end
    local o = others[(name or ""):gsub("[%- ].*", "")]
    if o then return o.count, o.ids, o.fresh or {} end
end

function M:Forget() wipe(others); wipe(toldOthers); lastSent = nil end

function M:PrintList()
    M:Scan()
    if #mine == 0 then return ns.Print(L.MISSING_NONE) end
    ns.Print(L.MISSING_HEAD, #mine)
    for _, e in ipairs(mine) do print("   " .. M:Describe(e)) end
end

---------------------------------------------------------------------------
-- Warning before abandoning
---------------------------------------------------------------------------
StaticPopupDialogs["SYNCLINE_ABANDON"] = {
    text = "%s",
    button1 = OKAY or "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
    preferredIndex = 3,
}

function M:OnAbandon(id)
    if not ns.db or not ns.db.missingQuests or not id then return end
    if GuideSaysAbandon(id) then return end
    local later = M:NeededLater(id)
    if #later == 0 then return end
    local name = ns.QuestName and ns.QuestName(id) or ("#" .. id)
    local where = {}
    for i = 1, math.min(3, #later) do
        local what = later[i].tag == "turnin" and L.MISSING_TURNIN or L.MISSING_COMPLETE
        where[i] = L.MISSING_AT:format(what, later[i].step)
    end
    local text = L.ABANDON_WARN:format(name, table.concat(where, ", "))
    if ns.Print then ns.Print("|cffff6060" .. text:gsub("\n", " ") .. "|r") end
    StaticPopup_Hide("SYNCLINE_ABANDON")
    StaticPopup_Show("SYNCLINE_ABANDON", text)
end

local function AbandonID()
    if C_QuestLog and C_QuestLog.GetAbandonQuest then
        local ok, id = pcall(C_QuestLog.GetAbandonQuest)
        if ok and tonumber(id) and tonumber(id) > 0 then return tonumber(id) end
    end
    if C_QuestLog and C_QuestLog.GetSelectedQuest then
        local ok, id = pcall(C_QuestLog.GetSelectedQuest)
        if ok and tonumber(id) and tonumber(id) > 0 then return tonumber(id) end
    end
    if GetQuestLogSelection and GetQuestLogTitle then
        local i = GetQuestLogSelection()
        local id = i and select(8, GetQuestLogTitle(i))
        if tonumber(id) then return tonumber(id) end
    end
end

-- The game marks a quest for abandoning right before it asks "Abandon?"
local function HookAbandon()
    if M.hooked then return end
    M.hooked = true
    local function onSet() M:OnAbandon(AbandonID()) end
    if C_QuestLog and C_QuestLog.SetAbandonQuest then hooksecurefunc(C_QuestLog, "SetAbandonQuest", onSet) end
    if _G.SetAbandonQuest then hooksecurefunc("SetAbandonQuest", onSet) end
end

M.HookAbandon = HookAbandon
-- shared with Blockers.lua and Share.lua
M.OnQuest, M.TurnedIn, M.CurrentStep, M.Elements, M.RXP = OnQuest, TurnedIn, CurrentStep, Elements, RXP

---------------------------------------------------------------------------
-- In the group window: who is missing what (only when someone is)
---------------------------------------------------------------------------
local card, rows
local ROW_H, SHOW = 22, 6

function M:Attach(parent, x, width)
    card = T.Card(parent, "Missing quests", x, 0, width, 100)
    rows = {}
    for i = 1, SHOW do
        local r = CreateFrame("Frame", nil, card)
        r:SetSize(width - 2, ROW_H)
        r:SetPoint("TOPLEFT", 1, -30 - (i - 1) * ROW_H)
        r.name = T.Text(r, "", 13, C.text, true)
        r.name:SetPoint("LEFT", 14, 0)
        r.name:SetWidth(110)
        r.name:SetWordWrap(false)
        r.list = T.Text(r, "", 12, C.warn, true)
        r.list:SetPoint("LEFT", 128, 0)
        r.list:SetPoint("RIGHT", -10, 0)
        r.list:SetWordWrap(false)
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self)
            if not self.ids then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L.MISSING_TIP_HEAD:format(self.who))
            if self.me then
                for _, e in ipairs(mine) do GameTooltip:AddLine(M:Describe(e), 1, 1, 1, true) end
            else
                for _, q in ipairs(self.ids) do
                    GameTooltip:AddLine(ns.QuestName and ns.QuestName(q) or ("#" .. q), 1, 1, 1)
                end
                if self.count > #self.ids then GameTooltip:AddLine("+" .. (self.count - #self.ids), C.muted[1], C.muted[2], C.muted[3]) end
            end
            GameTooltip:AddLine(L.MISSING_TIP_HINT, C.muted[1], C.muted[2], C.muted[3], true)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = r
    end
    return card
end

function M:Layout(y, snap)
    if not card then return 0 end
    if not (snap.inGroup and ns.db.missingQuests) then card:Hide(); return 0 end
    local shown = 0
    for _, m in ipairs(snap.members) do
        local count, ids, fresh = M:Get(m.name, m.me)
        if count and count > 0 and shown < SHOW then
            shown = shown + 1
            local r = rows[shown]
            r.who, r.me, r.count, r.ids = m.name:gsub("[%- ].*", ""), m.me, count, ids
            r.name:SetText("|cff" .. T.ClassHex(m.class) .. r.who .. "|r")
            -- not accepted just now first, in red
            local sorted = {}
            for _, q in ipairs(ids) do if fresh[q] then sorted[#sorted + 1] = q end end
            for _, q in ipairs(ids) do if not fresh[q] then sorted[#sorted + 1] = q end end
            local names = {}
            for i = 1, math.min(2, #sorted) do
                local q = sorted[i]
                local name = ns.QuestName and ns.QuestName(q) or ("#" .. q)
                names[i] = fresh[q] and ("|cffff6060" .. L["not accepted"] .. ": " .. name .. "|cfff2b84d") or name
            end
            local more = count > #names and (" +" .. (count - #names)) or ""
            r.list:SetText(count .. ": " .. table.concat(names, ", ") .. more)
            r:Show()
        end
    end
    for i = shown + 1, SHOW do rows[i]:Hide() end
    if shown == 0 then card:Hide(); return 0 end
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", 12, y)
    card:Show()
    local h = 30 + shown * ROW_H + 8
    card:SetHeight(h)
    return h
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local pending = false
local function Soon()
    if pending then return end
    pending = true
    C_Timer.After(2, function() pending = false; M:Update() end)
end
M.Soon = Soon

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then HookAbandon() end
    Soon()
end)
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_REMOVED", "GROUP_ROSTER_UPDATE" }) do
    ev:RegisterEvent(e)
end
