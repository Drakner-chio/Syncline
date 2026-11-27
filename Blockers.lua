-- Syncline: why can't I do this step yet? Checks the step I'm at:
--   prereq    a quest that must be turned in first (from the guide: a
--             ".isQuestTurnedIn" condition, or the quest is accepted in the
--             step that turns the other one in)
--   level     ".xp 12": not before level 12
--   over      ".xp <12": only below level 12, RestedXP skips it (grey)
--   grey      a quest in my log that is grey for me (little experience)
--   already   the quest to accept is already turned in
--   logfull   no room in the quest log
--   notinlog  a quest to complete or turn in isn't in my log
--   notdone   a quest to turn in still has objectives open
-- The group gets the first reason, as Y^<protocol>^<line>^<code>^<quest>^<arg>.

local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local C = T.C
local B = {}
ns.Blockers = B

local mine = {}            -- my reasons for the step I'm at
local others = {}          -- [bare name] = { code, quest, arg }
local lastSent

local function H() return ns.Missing end
local function Num(v) return tonumber(v) or 0 end

local function QuestCount()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local ok, entries, quests = pcall(C_QuestLog.GetNumQuestLogEntries)
        if ok and quests then return Num(quests) end
    end
    if GetNumQuestLogEntries then
        local entries, quests = GetNumQuestLogEntries()
        return Num(quests or entries)
    end
    return 0
end

local function QuestMax()
    if C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept then
        local ok, n = pcall(C_QuestLog.GetMaxNumQuestsCanAccept)
        if ok and tonumber(n) then return tonumber(n) end
    end
    return tonumber(MAX_QUESTS) or 25
end

-- level of a quest in my log
local function LogLevel(q)
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo then
        local ok, i = pcall(C_QuestLog.GetLogIndexForQuestID, q)
        local info = ok and i and C_QuestLog.GetInfo(i)
        if type(info) == "table" and tonumber(info.level) then return tonumber(info.level) end
    end
    if GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, Num(GetNumQuestLogEntries()) do
            local _, level, _, _, _, _, _, id = GetQuestLogTitle(i)
            if id == q then return tonumber(level) end
        end
    end
end

local function IsGrey(q)
    local level = LogLevel(q)
    if not level or level <= 0 then return false end
    local range = GetQuestGreenRange and Num(GetQuestGreenRange()) or 8
    return level < Num(UnitLevel("player")) - range
end

local function IsComplete(q)
    local rxp = H().RXP()
    if rxp and rxp.IsQuestComplete then
        local ok, v = pcall(rxp.IsQuestComplete, q)
        if ok then return v and true or false end
    end
    return C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(q) and true or false
end

-- "3/8 Kolkar Pack Runner slain": the first objective still open
local function OpenObjective(q)
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return nil end
    local ok, list = pcall(C_QuestLog.GetQuestObjectives, q)
    if not ok or type(list) ~= "table" then return nil end
    for _, o in ipairs(list) do
        if type(o) == "table" and not o.finished then return o.text end
    end
end

-- quests that must be turned in before q can be accepted, from the guide
local function Prerequisites(steps, q, upTo)
    local pre = {}
    for i = 1, math.min(upTo, #steps) do
        local es = H().Elements(steps[i])
        local accepts, turnins, needs = false, {}, {}
        for _, e in ipairs(es) do
            if type(e) == "table" then
                if e.tag == "accept" and tonumber(e.questId) == q then accepts = true end
                if e.tag == "turnin" and tonumber(e.questId) then turnins[#turnins + 1] = tonumber(e.questId) end
                if e.tag == "isQuestTurnedIn" and type(e.questIds) == "table" then
                    for _, id in ipairs(e.questIds) do needs[#needs + 1] = tonumber(id) end
                end
            end
        end
        if accepts then
            -- a turn-in in the step itself is that step's own job, not a prerequisite
            for _, p in ipairs(turnins) do if p ~= q and i ~= upTo then pre[#pre + 1] = { quest = p, step = i } end end
            for _, p in ipairs(needs) do if p and p ~= q then pre[#pre + 1] = { quest = p, step = i } end end
        end
    end
    return pre
end

-- where the guide turns quest p in (for "turned in at step 52")
local function TurnInStep(steps, p)
    for i, step in ipairs(steps) do
        for _, e in ipairs(H().Elements(step)) do
            if type(e) == "table" and e.tag == "turnin" and tonumber(e.questId) == p then return i end
        end
    end
end

-- My reasons for step n (default: the step I'm at)
function B:Check(n)
    local guide, cur = H().CurrentStep()
    n = n or cur
    local steps = guide and guide.steps
    local step = steps and n and steps[n]
    local out = {}
    if not step then return out end
    local level = Num(UnitLevel("player"))
    local seen = {}
    local function add(r)
        local key = r.code .. (r.quest or "")
        if not seen[key] then seen[key] = true; out[#out + 1] = r end
    end
    for _, e in ipairs(H().Elements(step)) do
        if type(e) == "table" then
            local q = tonumber(e.questId)
            if e.tag == "xp" and tonumber(e.level) then
                if e.reverseLogic and level >= e.level then add({ code = "over", arg = e.level })
                elseif not e.reverseLogic and level < e.level then add({ code = "level", arg = e.level }) end
            elseif e.tag == "isQuestTurnedIn" and type(e.questIds) == "table" then
                for _, p in ipairs(e.questIds) do
                    p = tonumber(p)
                    if p and not H().TurnedIn(p) then add({ code = "prereq", quest = p, step = TurnInStep(steps, p) }) end
                end
            elseif e.tag == "accept" and q then
                if H().TurnedIn(q) then
                    add({ code = "already", quest = q })
                elseif not H().OnQuest(q) then
                    for _, p in ipairs(Prerequisites(steps, q, n)) do
                        if not H().TurnedIn(p.quest) then
                            add({ code = "prereq", quest = p.quest, step = TurnInStep(steps, p.quest) or p.step })
                        end
                    end
                    if QuestCount() >= QuestMax() then add({ code = "logfull", arg = QuestMax() }) end
                end
            elseif (e.tag == "complete" or e.tag == "turnin") and q then
                if not H().OnQuest(q) then
                    if not H().TurnedIn(q) then add({ code = "notinlog", quest = q }) end
                else
                    if e.tag == "turnin" and not IsComplete(q) then
                        add({ code = "notdone", quest = q, arg = OpenObjective(q) })
                    end
                    if IsGrey(q) then add({ code = "grey", quest = q, arg = LogLevel(q) }) end
                end
            end
        end
    end
    return out
end

-- one reason as text
function B:Text(r)
    if not r then return nil end
    local name = r.quest and (ns.QuestName and ns.QuestName(r.quest) or ("#" .. r.quest))
    if r.code == "prereq" then
        return r.step and L.BLOCK_PREREQ_AT:format(name, r.step) or L.BLOCK_PREREQ:format(name)
    elseif r.code == "level" then return L.BLOCK_LEVEL:format(r.arg, UnitLevel("player"))
    elseif r.code == "over" then return L.BLOCK_OVER:format(r.arg)
    elseif r.code == "grey" then return L.BLOCK_GREY:format(name)
    elseif r.code == "already" then return L.BLOCK_ALREADY:format(name)
    elseif r.code == "logfull" then return L.BLOCK_LOGFULL:format(r.arg or 25)
    elseif r.code == "notinlog" then return L.BLOCK_NOTINLOG:format(name)
    elseif r.code == "notdone" then
        return r.arg and r.arg ~= "" and L.BLOCK_NOTDONE_AT:format(name, r.arg) or L.BLOCK_NOTDONE:format(name)
    end
    return r.code
end

-- a reason from someone else (no level of theirs here)
function B:TextFor(r)
    if r and r.code == "level" then return L.BLOCK_LEVEL_OTHER:format(r.arg) end
    return B:Text(r)
end

---------------------------------------------------------------------------
-- Updating and telling the group
---------------------------------------------------------------------------
function B:Update()
    mine = B:Check()
    B:Send()
    if ns.Changed then ns.Changed() end
end

function B:Mine() return mine end

function B:Send(force)
    if not ns.Send or not (IsInGroup and IsInGroup()) then return end
    local r = mine[1]
    local guide, cur = H().CurrentStep()
    local line = ns.StepLine and cur and ns.StepLine(cur) or ""
    local fields = r and { line or "", r.code, r.quest or "", r.code == "notdone" and "" or (r.arg or "") } or { line or "" }
    local text = table.concat(fields, "^")
    if text == lastSent and not force then return end
    lastSent = text
    ns.Send("Y", unpack(fields))
end

function B:OnMessage(who, f)
    if f[4] and f[4] ~= "" then
        others[who] = { code = f[4], quest = tonumber(f[5]), arg = tonumber(f[6]) or f[6] }
    else
        others[who] = nil
    end
    if ns.Changed then ns.Changed() end
end

-- a member's first reason (name as in the window)
function B:Get(name, me)
    if me then return mine[1] end
    return others[(name or ""):gsub("[%- ].*", "")]
end

function B:Forget() wipe(others); lastSent = nil end

local pending = false
function B.Soon()
    if pending then return end
    pending = true
    C_Timer.After(1.5, function() pending = false; B:Update() end)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function() B.Soon() end)
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_ACCEPTED",
                     "PLAYER_LEVEL_UP", "GROUP_ROSTER_UPDATE" }) do
    ev:RegisterEvent(e)
end
