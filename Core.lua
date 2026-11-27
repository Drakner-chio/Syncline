-- Syncline: the group leader picks a RestedXP guide, everyone in the group
-- loads the same one.
--
-- Messages (prefix "Syncline", fields split by ^):
--   G^<protocol>^<id>^<group>^<name>   leader: this is our guide
--   Q^<protocol>                       please tell me: leader sends G, everyone sends S
--   S^<protocol>^<id>^<group>^<name>   this is the guide I have loaded (for /sl)
--   P^<protocol>^<id>^<group>^<name>   member to leader: how about this guide?
--   N^<protocol>^<player>^<what>       leader: no to <player>'s suggestion (P) or skip request (R)
--   T^<protocol>^<step>^<total>        my step in my guide changed
--   K^<protocol>^<step>^<id>^<group>^<name>   leader: everyone at <step> of this guide skips it
--   J^<protocol>^<step>^<id>^<group>^<name>   leader: everyone in this guide jumps to <step>
--   R^<protocol>^<step>^<id>^<group>^<name>   member to leader: please skip <step> for the group
--   W^<protocol>^<route settings>      leader: RestedXP route settings of the group
--   V^<protocol>^<route settings>      member: my RestedXP route settings (for the window)
-- S also carries ^<step>^<total>^<line> at the end, T ^<line>, K/J/R ^<line>
-- after the guide fields. <line> is where the step stands in the guide text:
-- RestedXP leaves out steps for other classes and races, so step numbers
-- differ from player to player, the line doesn't (and not between languages). Steps are counted the same way in
-- every language (each translation has the same steps in the same order).
-- <group>/<name> are RestedXP's guide group and guide name, the same pair it
-- keeps in RXPCData.currentGuideGroup / currentGuideName. They depend on the
-- client language (a German client loads RestedXP's German guides), so <id>
-- names the guide the same way in every language (GuideMap.lua); it is empty
-- for guides GuideMap doesn't know, then group/name have to match.

local ADDON, ns = ...
local L = ns.L

local PREFIX = "Syncline"
local PROTOCOL = 2
local SEP = "^"
local CHAT_PREFIX = (ns.Theme and ns.Theme.CHAT_PREFIX or "|cff4fc3f7Syncline|r") .. ": "

ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"
if ns.VERSION:find("@", 1, true) then ns.VERSION = "dev" end
ns.VERSION = ns.VERSION:gsub("^[vV]", "")   -- release builds say "v0.12.0"

local DEFAULTS = {
    enabled = true,        -- follow the leader's guide
    mode = "auto",         -- "auto": switch right away, "ask": popup first
    offerSuggest = true,   -- picked another guide myself: offer to suggest it
    followSteps = true,    -- the leader may skip steps for me / pull me to his step
    followRoute = true,    -- take the leader's RestedXP route settings (dungeons, ...)
    shareRoute = true,     -- leader: send my route settings to the group
    slackMeter = true,     -- leader: who keeps the group waiting (Slack.lua)
    xpOverview = true,     -- experience of the group (XP.lua)
    missingQuests = true,  -- quests the guide still needs but I don't have (Missing.lua)
    showBlockers = true,   -- why my step can't be done yet (Blockers.lua)
    shareQuests = true,    -- see which of my quests others want (Share.lua)
    autoShare = false,     -- share them by myself
    questProgress = true,  -- everyone's progress on the step's quests (Progress.lua)
    groupQuestCheck = true,-- group steps: who lacks the quest, who is far (Progress.lua)
    travelCheck = true,    -- hearthstone and flight paths (Travel.lua)
    minimapButton = true,
    minimapAngle = 200,
    locked = false,        -- windows can't be dragged
    windowScale = 1,       -- size of the group window
    viewLeader = "full",   -- what the group window shows to the leader: full, quests, compact, custom
    viewMember = "compact",-- ... and to members
    dock = true,           -- a strip with Syncline's info at the RestedXP window (Dock.lua)
    dockSide = "auto",     -- below/above it; auto: above when RestedXP grows upwards
    dockStyle = "auto",    -- the strip's look: auto (EllesmereUI's when it's there) or syncline
}

local db
local leaderGuide          -- { id, group, name, from } last guide the leader sent
local statuses = {}        -- [player] = { id, group, name, step, total }
local lastSeen             -- "group^name" of my loaded guide when last checked
local lastSent             -- "group^name" the leader sent last
local lastAnnounced        -- "group^name" the leader last told himself about in the chat
local applying = false     -- I'm loading the leader's guide right now
local pending              -- leader guide waiting for the end of combat
local wasInGroup = false
local pendingStep          -- step to go to after combat
local pendingRoute         -- route settings to take after combat
local leaderRoute          -- route settings the leader sent last
local lastRouteSent        -- route settings I sent last (leader)
local SendRoute            -- defined with the route settings below
local timers = {}
local debug = false        -- /sl debug: show every message

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function Print(text, ...)
    if select("#", ...) > 0 then text = text:format(...) end
    print(CHAT_PREFIX .. text)
end
ns.Print = Print

-- Runs fn after delay; another call with the same key replaces the waiting one
local function Debounce(key, delay, fn)
    timers[key] = (timers[key] or 0) + 1
    local id = timers[key]
    C_Timer.After(delay, function()
        if timers[key] == id then fn() end
    end)
end

-- Something the windows show has changed
local function Changed()
    Debounce("ui", 0.1, function()
        if ns.GroupWindow then ns.GroupWindow:Refresh() end
        if ns.Dock then ns.Dock:Refresh() end
    end)
end
ns.Changed = Changed

local function Clean(s)
    return (tostring(s or ""):gsub("[%^%c]", ""))
end

local function Split(text)
    local out = {}
    for field in (text .. SEP):gmatch("(.-)%" .. SEP) do out[#out + 1] = field end
    return out
end

local function Key(group, name) return (group or "") .. SEP .. (name or "") end

-- Names without realm. Addon messages come as "Name-Realm" or just "Name"
-- (same realm), unit names with or without realm depending on the client, so
-- everything about players is keyed by the bare name.
-- Midnight/Forever can hand out unit names as secret values: those can't be
-- compared or used as table keys, so they count as unknown.
local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Bare(name)
    name = Plain(name)
    if type(name) ~= "string" then return nil end
    -- "Name-Realm", and on some clients "Name Realm"; names have neither
    return (name:match("^([^%- ]+)") or name)
end

local function IsMe(name)
    return Bare(name) == Bare(UnitName("player"))
end

local function GroupChannel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
        and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function IsLeader() return GroupChannel() ~= nil and UnitIsGroupLeader("player") end

local function GroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    end
    return units
end

-- Is this sender the group leader? UnitIsGroupLeader takes player names, which
-- works even when unit names are secret; try the spellings a sender can have.
local function IsLeaderName(name)
    if type(name) ~= "string" then return false end
    local tries = { name, Bare(name) }
    if Ambiguate then
        tries[#tries + 1] = Ambiguate(name, "none")
        tries[#tries + 1] = Ambiguate(name, "short")
    end
    for _, n in ipairs(tries) do
        local ok, res = pcall(UnitIsGroupLeader, n)
        if ok and Plain(res) then return true end
    end
    -- last resort: by unit, skipping names we aren't allowed to read
    local bare = Bare(name)
    for _, unit in ipairs(GroupUnits()) do
        if Bare(UnitName(unit)) == bare then return Plain(UnitIsGroupLeader(unit)) and true or false end
    end
    return false
end

---------------------------------------------------------------------------
-- RestedXP
---------------------------------------------------------------------------
local function RXP()
    local ace = LibStub and LibStub("AceAddon-3.0", true)
    local rxp = ace and ace:GetAddon("RXPGuides", true) or _G.RXP
    if type(rxp) == "table" and rxp.GetGuideTable and rxp.LoadGuide then return rxp end
end

-- The guide I have loaded: group, name (nil when none)
local function CurrentGuide()
    local data = _G.RXPCData
    if not data then return end
    local group, name = data.currentGuideGroup, data.currentGuideName
    if not group or group == "" or not name or name == "" then return end
    return group, name
end

-- RestedXP keys guides as "01-06 Durotar" but the guide files say "1-6 Durotar"
local function Unaffix(name)
    return (name:gsub("^0(%d)%-0?(%d%d?)", "%1-%2"))
end

local function Lookup(group, name)
    local rxp = RXP()
    if not rxp or not group or not name then return end
    return rxp.GetGuideTable(group, name) or rxp.GetGuideTable(group, Unaffix(name))
end

-- GuideMap: [id] = { enUS = { group, name }, deDE = ... }  ->  [group^name] = id
local idByKey = {}
for id, langs in pairs(ns.GuideMap or {}) do
    for _, gn in pairs(langs) do
        idByKey[Key(gn[1], gn[2])] = id
        idByKey[Key(gn[1], Unaffix(gn[2]))] = id
    end
end

local function GuideID(group, name)
    if not group then return nil end
    return idByKey[Key(group, name)] or idByKey[Key(group, Unaffix(name))]
end

---------------------------------------------------------------------------
-- Fingerprints: guides GuideMap doesn't know, e.g. RestedXP's paid Forever
-- guides, which everyone imports in their own language from the RestedXP
-- website. Their names differ by language ("43-44 Flusslande II" /
-- "43-44 Riverglades II"), but the level range in the name and the quests in
-- the steps don't. Fingerprint: "q:<range>:<first quest ids>".
---------------------------------------------------------------------------
local FP_QUESTS = 10
local fpCache = {}      -- [group^name] = fingerprint or false

-- What a guide's name starts with, the same in every language:
-- "43-44 Flusslande II" -> "43-44", "11. The Drowned Capitals" -> "c11", else "".
local function Range(name)
    name = tostring(name or "")
    local a, b = name:match("^%s*0*(%d+)%s*%-%s*0*(%d+)")
    if a then return a .. "-" .. b end
    local c = name:match("^%s*0*(%d+)[%.%s:)]")
    if c then return "c" .. c end
    return ""
end

local function QuestIDs(guide)
    local ids, seen = {}, {}
    for _, step in ipairs(guide and guide.steps or {}) do
        for _, e in ipairs(type(step) == "table" and (step.elements or step) or {}) do
            local q = type(e) == "table" and tonumber(e.questId)
            if q and not seen[q] and (e.tag == "accept" or e.tag == "turnin" or e.tag == "complete") then
                seen[q] = true
                ids[#ids + 1] = q
                if #ids >= FP_QUESTS then return ids end
            end
        end
    end
    return ids
end

-- The steps of a guide, parsed by RestedXP when needed
local function Parsed(guide)
    if not guide then return nil end
    if guide.steps then return guide end
    local rxp = RXP()
    if not rxp or not rxp.FetchGuide then return nil end
    local ok, parsed = pcall(rxp.FetchGuide, rxp, guide)
    if ok and type(parsed) == "table" and parsed.steps then return parsed end
end

local function Fingerprint(guide, group, name)
    local key = Key(group, name)
    if fpCache[key] ~= nil then return fpCache[key] or nil end
    local range = Range(name)
    local ids = QuestIDs(Parsed(guide))
    local fp = (#ids > 0) and ("q:" .. range .. ":" .. table.concat(ids, ".")) or false
    fpCache[key] = fp
    return fp or nil
end

local function ParseFingerprint(fp)
    local range, list = tostring(fp or ""):match("^q:([%w%-]*):([%d%.]+)$")
    if not range then return nil end
    local ids = {}
    for q in list:gmatch("%d+") do ids[tonumber(q)] = true end
    return range, ids
end

-- How many of the quests in fingerprint a are in b (0..1)
local function Overlap(a, b)
    local ra, ia = ParseFingerprint(a)
    local rb, ib = ParseFingerprint(b)
    if not ra or ra ~= rb then return 0 end
    local n, hit = 0, 0
    for q in pairs(ia) do
        n = n + 1
        if ib[q] then hit = hit + 1 end
    end
    return n > 0 and hit / n or 0
end

-- My guide for a fingerprint: same level range, most quests in common
local function FindByFingerprint(fp)
    local range = ParseFingerprint(fp)
    local rxp = RXP()
    if not range or not rxp or type(rxp.guides) ~= "table" then return end
    local best, bestScore, candidates, only = nil, 0, 0, nil
    for _, guide in pairs(rxp.guides) do
        -- a name without level range or number: compare quests, but only so many guides
        if candidates >= 80 then break end
        if type(guide) == "table" and guide.name and guide.group and Range(guide.name) == range then
            candidates = candidates + 1
            only = guide
            local mine = Fingerprint(guide, guide.group, guide.name)
            local score = mine and Overlap(fp, mine) or 0
            if score > bestScore then best, bestScore = guide, score end
        end
    end
    if best and bestScore >= 0.5 then return best end
    -- one guide for this level range whose quests we can't read: that one
    if range ~= "" and candidates == 1 and not Fingerprint(only, only.group, only.name) then return only end
end

-- The guide the leader means, as it is called on my client: guide table, group, name
local function Resolve(g)
    local langs = g.id and ns.GuideMap and ns.GuideMap[g.id]
    if langs then
        local mine = langs[GetLocale()]
        local order = { mine, langs.enUS }
        for _, gn in pairs(langs) do order[#order + 1] = gn end
        for _, gn in pairs(order) do
            local guide = gn and Lookup(gn[1], gn[2])
            if guide then return guide, guide.group or gn[1], guide.name or gn[2] end
        end
    end
    local guide = Lookup(g.group, g.name)
    if guide then return guide, guide.group or g.group, guide.name or g.name end
    if g.id and g.id:find("^q:") then
        guide = FindByFingerprint(g.id)
        if guide then return guide, guide.group, guide.name end
    end
    -- same guide name in another group (e.g. a renamed group)
    local rxp = RXP()
    if rxp and type(rxp.guides) == "table" and g.name then
        for _, guide in pairs(rxp.guides) do
            if type(guide) == "table" and (guide.name == g.name or guide.name == Unaffix(g.name)) and guide.group then
                return guide, guide.group, guide.name
            end
        end
    end
end

-- a, b: { id, group, name }
local function Same(a, b)
    if not a or not b then return false end
    if a.id and b.id then
        if a.id == b.id then return true end
        -- fingerprints of the same guide from different guide versions
        if a.id:find("^q:") and b.id:find("^q:") then return Overlap(a.id, b.id) >= 0.5 end
        return false
    end
    return Key(a.group, a.name) == Key(b.group, b.name)
end

local function Mine()
    local group, name = CurrentGuide()
    if not group then return nil end
    local id = GuideID(group, name)
    if not id then
        local rxp = RXP()
        local cur = rxp and rxp.currentGuide
        if cur and cur.name == name then id = Fingerprint(cur, group, name) end
    end
    return { id = id, group = group, name = name }
end

local function GuideLabel(g)
    if not g then return "-" end
    local guide = Resolve(g)
    local label = guide and (guide.displayname or guide.title or guide.name) or g.name or "?"
    return (tostring(label):gsub("\n", " "))
end

-- My step in my guide: step, total (nil without a guide)
-- Where step n stands in my guide's text (see the top of the file)
local function StepLine(n)
    local rxp = RXP()
    local guide = rxp and rxp.currentGuide
    local step = guide and guide.steps and guide.steps[n]
    local id, base = step and tonumber(step.stepId), guide and tonumber(guide.guideId)
    if id and base then return id - base end
end

ns.StepLine = StepLine

-- My step for a line: that step, or the next one I have (the one at the line
-- may be for another class). Returns index, exact.
local function IndexForLine(line)
    local rxp = RXP()
    local guide = rxp and rxp.currentGuide
    if not line or not guide or not guide.steps or not tonumber(guide.guideId) then return end
    local last
    for i, step in ipairs(guide.steps) do
        local l = tonumber(step.stepId) and (step.stepId - guide.guideId)
        if l then
            if l == line then return i, true end
            if l > line then return i, false end
            last = i
        end
    end
    return last, false
end

-- My step in my guide: step, total, line (nil without a guide)
local function MyStep()
    local rxp = RXP()
    local guide = rxp and rxp.currentGuide
    if not guide or not guide.steps or not CurrentGuide() then return end
    local ok, step = pcall(rxp.GetGuideProgress)
    step = ok and tonumber(step) or tonumber(_G.RXPCData and RXPCData.currentStep)
    if not step then return end
    return step, #guide.steps, StepLine(step)
end

-- What step n of my guide says, short and without colors and icons
local function StepText(n)
    local rxp = RXP()
    local guide = rxp and rxp.currentGuide
    local step = guide and guide.steps and guide.steps[n]
    if not step then return nil end
    for _, e in ipairs(step.elements or step) do
        local t = type(e) == "table" and (e.text or e.tooltipText)
        if type(t) == "string" and t:find("%S") then
            t = t:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cRXP_[%u_]-_", "")
                 :gsub("|r", ""):gsub("::%d+", ""):gsub("^[%s>]+", ""):gsub("%s+", " ")
            if #t > 70 then t = t:sub(1, 67) .. "..." end
            return t
        end
    end
end
ns.StepText = StepText

---------------------------------------------------------------------------
-- Safe to skip? What hangs on a step, read from the guide itself:
-- the quests the step accepts, completes or turns in, and later steps that
-- need them: ".isQuestTurnedIn X" conditions and quests accepted in the step
-- that turns X in (follow-ups), and theirs in turn.
---------------------------------------------------------------------------
local QUEST_TAGS = { accept = true, complete = true, turnin = true }

local function QuestName(id)
    local rxp = RXP()
    if rxp and rxp.GetQuestName then
        local ok, name = pcall(rxp.GetQuestName, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, name = pcall(C_QuestLog.GetTitleForQuestID, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return "#" .. id
end

ns.QuestName = QuestName

local function Elements(step)
    return type(step) == "table" and (step.elements or step) or {}
end

-- Skipping step n of my guide: { quests = {ids}, followups = {ids}, later = n steps }
-- level: "none" (no quest in it), "safe", "some" (1-2 follow-ups), "chain"
local function SkipRisk(n)
    local rxp = RXP()
    local guide = rxp and rxp.currentGuide
    local steps = guide and guide.steps
    if not steps or not steps[n] then return nil end
    local quests, isQuest = {}, {}
    for _, e in ipairs(Elements(steps[n])) do
        local q = type(e) == "table" and QUEST_TAGS[e.tag] and tonumber(e.questId)
        if q and not isQuest[q] then isQuest[q] = true; quests[#quests + 1] = q end
    end
    if #quests == 0 then return { level = "none", quests = {}, followups = {}, later = 0 } end

    -- follow-ups, a few levels deep
    local lost, followups, queue = {}, {}, {}
    for _, q in ipairs(quests) do lost[q] = true; queue[#queue + 1] = q end
    local depth = 0
    while #queue > 0 and depth < 6 do
        depth = depth + 1
        local nextQueue = {}
        for _, q in ipairs(queue) do
            for i = n + 1, #steps do
                local es = Elements(steps[i])
                local needsQ, turnsInQ = false, false
                for _, e in ipairs(es) do
                    if type(e) == "table" then
                        if e.tag == "isQuestTurnedIn" and type(e.questIds) == "table" then
                            for _, id in ipairs(e.questIds) do if tonumber(id) == q then needsQ = true end end
                        elseif e.tag == "turnin" and tonumber(e.questId) == q then
                            turnsInQ = true
                        end
                    end
                end
                if needsQ or turnsInQ then
                    for _, e in ipairs(es) do
                        local y = type(e) == "table" and e.tag == "accept" and tonumber(e.questId)
                        if y and not lost[y] then
                            lost[y] = true
                            followups[#followups + 1] = y
                            nextQueue[#nextQueue + 1] = y
                        end
                    end
                end
            end
        end
        queue = nextQueue
    end

    -- later steps that belong to a lost quest
    local later = 0
    for i = n + 1, #steps do
        for _, e in ipairs(Elements(steps[i])) do
            local ids = type(e) == "table" and (e.questIds or (e.questId and { e.questId }))
            local hit = false
            for _, id in ipairs(ids or {}) do if lost[tonumber(id)] then hit = true end end
            if hit and e.tag ~= "isQuestAvailable" then later = later + 1; break end
        end
    end
    local level = (#followups == 0) and "safe" or (#followups <= 2 and "some" or "chain")
    return { level = level, quests = quests, followups = followups, later = later }
end
ns.SkipRisk = SkipRisk

local RISK_COLOR = { none = "5cd97a", safe = "5cd97a", some = "f2b84d", chain = "db5c5c" }

-- One line: "safe to skip" / "2 follow-up quests: A, B"
local function RiskText(r)
    if not r then return nil end
    local c = "|cff" .. RISK_COLOR[r.level]
    if r.level == "none" then return c .. L.RISK_NONE .. "|r" end
    if r.level == "safe" then return c .. L.RISK_SAFE .. "|r" end
    local names = {}
    for i = 1, math.min(3, #r.followups) do names[i] = QuestName(r.followups[i]) end
    local more = #r.followups > 3 and (" +" .. (#r.followups - 3)) or ""
    return c .. L.RISK_FOLLOWUPS:format(#r.followups, table.concat(names, ", ") .. more) .. "|r"
end
ns.RiskText = RiskText

-- Lines for a tooltip
function ns.RiskLines(r)
    local out = {}
    if not r then return out end
    out[#out + 1] = RiskText(r)
    if #r.quests > 0 then
        local names = {}
        for i, q in ipairs(r.quests) do names[i] = QuestName(q) end
        out[#out + 1] = "|cff9aa0aa" .. L.RISK_QUESTS:format(table.concat(names, ", ")) .. "|r"
    end
    for _, q in ipairs(r.followups) do out[#out + 1] = "  |cfff2b84d" .. QuestName(q) .. "|r" end
    if r.later > 0 then out[#out + 1] = "|cff9aa0aa" .. L.RISK_LATER:format(r.later) .. "|r" end
    return out
end

---------------------------------------------------------------------------
-- Sending (waits for the end of combat, tries again when the game refuses)
---------------------------------------------------------------------------
local queue = {}
local pumping = false

local function SendNow(text, channel)
    local send = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if not send then return true end
    local ok, res = pcall(send, PREFIX, text, channel)
    if not ok then return false end
    -- older clients return nothing, newer ones true or a result code (0 = sent)
    return res == nil or res == true or res == 0
end

local function Pump()
    if #queue == 0 then pumping = false return end
    pumping = true
    if InCombatLockdown() then pumping = false return end   -- PLAYER_REGEN_ENABLED restarts it
    local channel = GroupChannel()
    if not channel then wipe(queue); pumping = false return end
    local msg = queue[1]
    if SendNow(msg.text, channel) then
        table.remove(queue, 1)
        C_Timer.After(0.2, Pump)
    else
        msg.tries = (msg.tries or 0) + 1
        if msg.tries > 20 then table.remove(queue, 1) end
        C_Timer.After(1.5, Pump)
    end
end

-- A newer message of the same kind replaces one that is still waiting
local function Queue(kind, ...)
    local text = table.concat({ kind, PROTOCOL, ... }, SEP)
    if #text > 255 then return end
    for i = #queue, 1, -1 do
        if queue[i].kind == kind then table.remove(queue, i) end
    end
    queue[#queue + 1] = { kind = kind, text = text }
    if not pumping then Pump() end
end

local function GuideFields(g)
    if not g then return "", "", "" end
    local id, group, name = Clean(g.id), Clean(g.group), Clean(g.name)
    if #id + #group + #name > 230 then group, name = "", name:sub(1, 230 - #id) end
    return id, group, name
end

ns.Send = function(kind, ...) Queue(kind, ...) end

local function SendStatus()
    if not GroupChannel() then return end
    local id, group, name = GuideFields(Mine())
    local step, total, line = MyStep()
    Queue("S", id, group, name, step or "", total or "", line or "")
end

local function SendStep()
    if not GroupChannel() then return end
    local step, total, line = MyStep()
    if step then Queue("T", step, total, line or "") end
end

local function SendGuide(manual)
    if not IsLeader() then
        if manual then Print(L.NOT_LEADER) end
        return
    end
    local mine = Mine()
    if not mine then
        if manual then Print(L.NO_GUIDE) end
        return
    end
    lastSent = Key(mine.group, mine.name)
    mine.from = UnitName("player")
    leaderGuide = mine
    Queue("G", GuideFields(mine))
    if db.shareRoute then SendRoute("W") end
    -- in the chat only when it's news: a new guide, or sent by hand. Answers to
    -- members asking (login, reload, loading screens) go out quietly.
    if manual == true or lastSent ~= lastAnnounced then
        lastAnnounced = lastSent
        Print(L.SENT, GuideLabel(mine))
    elseif debug then
        Print("|cff999999sent again (someone asked)|r")
    end
end

local function AskLeader()
    if GroupChannel() then Queue("Q") end
end

---------------------------------------------------------------------------
-- Following the leader
---------------------------------------------------------------------------
-- "guide doesn't exist here", once per guide and minute
local lastMissing, lastMissingAt = nil, 0
local function PrintMissing(g)
    local key = (g.id or "") .. Key(g.group, g.name)
    local now = GetTime and GetTime() or 0
    if key == lastMissing and now - lastMissingAt < 60 then return end
    lastMissing, lastMissingAt = key, now
    Print(L.MISSING, g.from, g.name or g.id)
end

local function Apply(g)
    local rxp = RXP()
    if not rxp then return end
    if Same(Mine(), g) then return end
    local label = GuideLabel(g)

    if InCombatLockdown() then
        if not pending then Print(g.suggested and L.TAKE_LATER or L.SWITCH_LATER, g.from, label) end
        pending = g
        return
    end
    pending = nil

    local guide, group, name = Resolve(g)
    if not guide then
        PrintMissing(g)
        SendStatus()
        return
    end

    applying = true
    local ok, err = pcall(rxp.LoadGuide, rxp, guide)
    lastSeen = Key(CurrentGuide())
    applying = false
    Changed()
    if not ok then geterrorhandler()(err) end

    if Key(CurrentGuide()) == Key(group, name) or Same(Mine(), g) then
        if g.suggested then
            Print(L.TAKEN, g.from, label)
        else
            Print(L.SWITCHED, g.from, label)
        end
        -- a leader taking a suggestion: send it to everyone
        if IsLeader() then lastSent = nil; Debounce("send", 0.3, SendGuide) end
    else
        Print(L.NOT_LOADED, label)
    end
    SendStatus()
end

StaticPopupDialogs["SYNCLINE_SWITCH"] = {
    text = "%s",
    button1 = L.YES,
    button2 = L.NO,
    OnAccept = function(_, g) if g then Apply(g) end end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Leader: someone suggests a guide
StaticPopupDialogs["SYNCLINE_SUGGEST"] = {
    text = "%s",
    button1 = L.TAKE,
    button2 = L.NO,
    OnAccept = function(_, g) if g then Apply(g) end end,
    OnCancel = function(_, g, reason)
        if g and reason == "clicked" and GroupChannel() then Queue("N", Clean(g.from)) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function OnSuggestion(g)
    if not IsLeader() then
        Print(L.SUGGESTED_INFO, g.from, GuideLabel(g))
        return
    end
    if Same(Mine(), g) then return end
    if not Resolve(g) then
        PrintMissing(g)
        return
    end
    g.suggested = true
    StaticPopup_Hide("SYNCLINE_SUGGEST")
    StaticPopup_Show("SYNCLINE_SUGGEST", L.SUGGEST_ASK:format(g.from, GuideLabel(g)), nil, g)
end

-- Member: suggest my guide to the leader
local function Suggest()
    if not GroupChannel() then return Print(L.NOT_IN_GROUP) end
    if IsLeader() then lastSent = nil; return SendGuide(true) end
    local mine = Mine()
    if not mine then return Print(L.NO_GUIDE) end
    Queue("P", GuideFields(mine))
    Print(L.SUGGEST_SENT, GuideLabel(mine))
end

-- Member: I just picked another guide myself, suggest it?
StaticPopupDialogs["SYNCLINE_OFFER"] = {
    text = "%s",
    button1 = L.SUGGEST,
    button2 = L.NO,
    OnAccept = function() Suggest() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function OnLeaderGuide(g)
    leaderGuide = g
    if not db.enabled then return SendStatus() end
    if Same(Mine(), g) then return SendStatus() end
    if db.mode == "ask" then
        StaticPopup_Hide("SYNCLINE_SWITCH")
        local text = L.ASK:format(g.from, GuideLabel(g))
        StaticPopup_Show("SYNCLINE_SWITCH", text, nil, g)
    else
        Apply(g)
    end
end

-- Did my guide change? Leaders send it to the group, members tell the group
-- what they have now.
local function CheckGuide()
    local key = Key(CurrentGuide())
    if key == lastSeen or applying then return end
    lastSeen = key
    Changed()
    if not GroupChannel() then return end
    if IsLeader() then
        if key ~= lastSent then Debounce("send", 0.5, SendGuide) end
    else
        Debounce("status", 1, SendStatus)
        if db.enabled and leaderGuide and not Same(Mine(), leaderGuide) then
            Print(L.LEFT_GROUP_GUIDE)
            local mine = Mine()
            if mine and db.offerSuggest then
                StaticPopup_Hide("SYNCLINE_OFFER")
                StaticPopup_Show("SYNCLINE_OFFER", L.OFFER_ASK:format(GuideLabel(mine)))
            end
        end
    end
end

---------------------------------------------------------------------------
-- Steps
---------------------------------------------------------------------------
-- Go to step n of my guide (after combat when in combat)
local function GoToStep(n)
    local rxp = RXP()
    local _, total = MyStep()
    if not rxp or not total then return end
    n = math.max(1, math.min(n, total))
    if InCombatLockdown() then
        pendingStep = n
        return
    end
    pendingStep = nil
    local ok, err = pcall(rxp.SetStep, n)
    if not ok then geterrorhandler()(err) end
    Changed()
end

local function StepLabel(n)
    local text = StepText(n)
    return text and L.STEP_WITH_TEXT:format(n, text) or L.STEP_N:format(n)
end

-- Someone else's step (their number n, their line) as my step number
local function LocalStep(n, line)
    if line then
        local i = IndexForLine(line)
        if i then return i end
    end
    return n
end

-- Leader: skip a step for the whole group (me too, when I'm at it).
-- n: my step number; line: the step's line, when it comes from someone else
local function SkipForGroup(n, line)
    if not IsLeader() then return Print(L.NOT_LEADER) end
    local mine = Mine()
    if not mine or not n then return Print(L.NO_GUIDE) end
    line = line or StepLine(n)
    local id, group, name = GuideFields(mine)
    Queue("K", n, id, group, name, line or "")
    Print(L.SKIPPED_SENT, StepLabel(n))
    local cur, _, curLine = MyStep()
    if cur and ((line and curLine == line) or (not line and cur == n)) then GoToStep(cur + 1) end
end

-- Leader: everyone in my guide to my step
local function PullToMyStep()
    if not IsLeader() then return Print(L.NOT_LEADER) end
    local mine = Mine()
    local n, _, line = MyStep()
    if not mine or not n then return Print(L.NO_GUIDE) end
    local id, group, name = GuideFields(mine)
    Queue("J", n, id, group, name, line or "")
    Print(L.PULL_SENT, StepLabel(n))
end

-- Leader pressed "skip": ask first when follow-up quests hang on the step
StaticPopupDialogs["SYNCLINE_SKIPRISK"] = {
    text = "%s",
    button1 = L.SKIP_FOR_GROUP,
    button2 = L.NO,
    OnAccept = function(_, d) if d then SkipForGroup(d.step, d.line) end end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function SkipWithCheck(n, line)
    if not n then return SkipForGroup(n, line) end
    local r = SkipRisk(n)
    if r and (r.level == "some" or r.level == "chain") then
        StaticPopup_Hide("SYNCLINE_SKIPRISK")
        StaticPopup_Show("SYNCLINE_SKIPRISK", L.RISK_CONFIRM:format(StepLabel(n), RiskText(r)), nil,
            { step = n, line = line })
    else
        SkipForGroup(n, line)
    end
end

-- Member: ask the leader to skip my step for the group
local function RequestSkip()
    if not GroupChannel() then return Print(L.NOT_IN_GROUP) end
    if IsLeader() then return SkipWithCheck((MyStep())) end
    local mine = Mine()
    local n, _, line = MyStep()
    if not mine or not n then return Print(L.NO_GUIDE) end
    local id, group, name = GuideFields(mine)
    Queue("R", n, id, group, name, line or "")
    Print(L.SKIP_REQUEST_SENT, StepLabel(n))
end

-- Member: the leader wants me to go to his step n / line (skip: past it)
local function OnLeaderStep(kind, n, from, line)
    if not db.enabled or not db.followSteps then return end
    local cur, _, curLine = MyStep()
    if not cur then return end
    local here = LocalStep(n, line)
    local target, text
    if kind == "K" then
        local atIt
        if line and curLine then atIt = (curLine == line) else atIt = (cur == n) end
        if not atIt then
            Print(L.SKIPPED_ELSEWHERE, from, StepLabel(here), cur)
            return
        end
        target, text = cur + 1, L.SKIPPED_BY_LEADER:format(from, StepLabel(cur))
    else
        if cur == here then return end
        target, text = here, L.PULLED_BY_LEADER:format(from, StepLabel(here))
    end
    if db.mode == "ask" then
        StaticPopup_Hide("SYNCLINE_STEP")
        StaticPopup_Show("SYNCLINE_STEP", text .. "\n\n" .. L.OK_QUESTION, nil, { step = target })
    else
        GoToStep(target)
        Print(text)
    end
end

StaticPopupDialogs["SYNCLINE_STEP"] = {
    text = "%s",
    button1 = L.YES_STEP,
    button2 = L.NO,
    OnAccept = function(_, d) if d then GoToStep(d.step) end end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Leader: someone asks to skip a step
StaticPopupDialogs["SYNCLINE_SKIPREQ"] = {
    text = "%s",
    button1 = L.SKIP_FOR_GROUP,
    button2 = L.NO,
    OnAccept = function(_, d) if d then SkipForGroup(d.step, d.line) end end,
    OnCancel = function(_, d, reason)
        if d and reason == "clicked" and GroupChannel() then Queue("N", Clean(d.from), "R") end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function OnSkipRequest(n, g, from, line)
    if not IsLeader() then
        Print(L.SKIP_REQUEST_INFO, from, L.STEP_N:format(n))
        return
    end
    if not Same(Mine(), g) then return end   -- not my guide: nothing to skip
    local here = LocalStep(n, line)
    local risk = RiskText(SkipRisk(here))
    StaticPopup_Hide("SYNCLINE_SKIPREQ")
    StaticPopup_Show("SYNCLINE_SKIPREQ", L.SKIP_REQUEST_ASK:format(from, StepLabel(here))
        .. (risk and ("\n\n" .. risk) or ""), nil, { step = here, line = line, from = from })
end

---------------------------------------------------------------------------
-- RestedXP route settings (Options → Guide Routing): they decide which steps
-- a guide has. Different settings in one group = different steps, so step
-- numbers, skips and "pull to my step" stop matching.
-- Encoded as "key=value;..." with d=<enabled dungeons, comma separated>.
-- Professions are left alone: those belong to each character.
-- Language independent: setting keys, numbers ("%.2f" always with a dot) and
-- RestedXP's dungeon tags (DM, RFC, ROL, BFD), which are the same in every
-- translation of the guides. Labels are only made on each client, in its language.
---------------------------------------------------------------------------
local ROUTE_KEYS = {   -- short name, RestedXP setting, kind
    { "a", "enableAutomaticXpRate", "bool" },
    { "r", "xprate", "num" },
    { "x", "enableXpStepSkipping", "bool" },
    { "g", "enableGroupQuests", "bool" },
    { "f", "soloSelfFound", "bool" },
    { "l", "loremasterMode", "bool" },
}
local ROUTE_LABEL = {
    a = "EXP rate", r = "EXP rate", x = "Skip overleveled steps", g = "Group quests",
    f = "Solo Self Found", l = "Loremaster", d = "Dungeons",
}

local function RouteProfile()
    local rxp = RXP()
    local settings = rxp and rxp.settings
    return settings and type(settings.profile) == "table" and settings.profile or nil, settings
end

-- My route settings as a string (nil without RestedXP settings)
local function MyRoute()
    local p, settings = RouteProfile()
    if not p then return nil end
    local parts = {}
    for _, k in ipairs(ROUTE_KEYS) do
        local v = p[k[2]]
        if v ~= nil then
            if k[3] == "bool" then v = v and "1" or "0"
            else v = ("%.2f"):format(tonumber(v) or 1) end
            -- an automatic rate is each player's own: don't compare it
            if not (k[1] == "r" and p.enableAutomaticXpRate) then
                parts[#parts + 1] = k[1] .. "=" .. v
            end
        end
    end
    if type(p.dungeons) == "table" then
        local on = {}
        for d, enabled in pairs(p.dungeons) do
            if enabled then on[#on + 1] = Clean(tostring(d)):gsub("[,;=]", "") end
        end
        table.sort(on)
        parts[#parts + 1] = "d=" .. table.concat(on, ",")
    end
    return table.concat(parts, ";")
end
ns.MyRoute = MyRoute

local function ParseRoute(text)
    local t = {}
    for k, v in tostring(text or ""):gmatch("(%a)=([^;]*)") do t[k] = v end
    return t
end

-- Which settings differ: list of labels (empty = same)
local function RouteDiff(a, b)
    local ta, tb, out, seen = ParseRoute(a), ParseRoute(b), {}, {}
    for _, k in ipairs({ "a", "r", "x", "g", "f", "l", "d" }) do
        if ta[k] and tb[k] and ta[k] ~= tb[k] and not seen[ROUTE_LABEL[k]] then
            seen[ROUTE_LABEL[k]] = true
            out[#out + 1] = L[ROUTE_LABEL[k]]
        end
    end
    return out
end
ns.RouteDiff = RouteDiff

function SendRoute(kind)
    if not GroupChannel() then return end
    local route = MyRoute()
    if not route then return end
    if kind == "W" then lastRouteSent = route end
    Queue(kind, route)
end

-- Take the leader's route settings
local function ApplyRoute(text)
    local p, settings = RouteProfile()
    if not p then return end
    if InCombatLockdown() then
        pendingRoute = text
        return
    end
    pendingRoute = nil
    local t = ParseRoute(text)
    for _, k in ipairs(ROUTE_KEYS) do
        local v = t[k[1]]
        if v ~= nil and p[k[2]] ~= nil then
            if k[3] == "bool" then p[k[2]] = (v == "1") else p[k[2]] = tonumber(v) or p[k[2]] end
        end
    end
    if t.d and type(p.dungeons) == "table" then
        local want = {}
        for d in t.d:gmatch("[^,]+") do want[d] = true end
        -- only dungeons this client knows; the rest stay as they are
        local known = {}
        local ok, list = pcall(function() return settings.dungeons:GetDungeons() end)
        if ok and type(list) == "table" then for d in pairs(list) do known[d] = true end end
        for d in pairs(p.dungeons) do known[d] = true end
        for d in pairs(want) do known[d] = true end
        for d in pairs(known) do p.dungeons[d] = want[d] or false end
    end
    local rxp = RXP()
    if rxp and rxp.ReloadGuide then
        applying = true
        local ok2, err = pcall(rxp.ReloadGuide, rxp, true)
        applying = false
        if not ok2 then geterrorhandler()(err) end
    end
    Changed()
end

StaticPopupDialogs["SYNCLINE_ROUTE"] = {
    text = "%s",
    button1 = L.TAKE,
    button2 = L.NO,
    OnAccept = function(_, d)
        if d then
            ApplyRoute(d.route)
            Print(L.ROUTE_TAKEN, d.from, table.concat(d.diff, ", "))
            SendRoute("V")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Member: the leader's route settings came in
local function OnLeaderRoute(text, from)
    leaderRoute = text
    Changed()
    local mine = MyRoute()
    if not mine then return end
    local diff = RouteDiff(text, mine)
    if #diff == 0 or not db.enabled or not db.followRoute then
        Debounce("route", 1, function() SendRoute("V") end)
        return
    end
    if db.mode == "ask" then
        StaticPopup_Hide("SYNCLINE_ROUTE")
        StaticPopup_Show("SYNCLINE_ROUTE", L.ROUTE_ASK:format(from, table.concat(diff, ", ")), nil,
            { route = text, from = from, diff = diff })
    else
        ApplyRoute(text)
        Print(L.ROUTE_TAKEN, from, table.concat(diff, ", "))
        Debounce("route", 1, function() SendRoute("V") end)
    end
end

-- Leader: did my route settings change? Then the group gets them.
local function CheckRoute()
    if not db.shareRoute or not IsLeader() then return end
    local route = MyRoute()
    if route and route ~= lastRouteSent then Debounce("routeSend", 1, function() SendRoute("W") end) end
end
ns.CheckRoute = CheckRoute

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local function HandleMessage(text, sender)
    if debug then Print("|cff999999<- %s: %s|r", tostring(sender), tostring(text)) end
    if IsMe(sender) then return end
    local f = Split(text)
    local who = Bare(sender)
    if tonumber(f[2]) ~= PROTOCOL then
        -- someone with another Syncline version: show it in /sl
        statuses[who] = { protocol = tonumber(f[2]) or 0 }
        Changed()
        return
    end
    local kind = f[1]

    -- guide fields start at field i (3 for G/S/P, 4 for K/J/R)
    local function Guide(i)
        i = i or 3
        local g = { id = f[i] ~= "" and f[i] or nil, group = f[i + 1] ~= "" and f[i + 1] or nil,
                    name = f[i + 2] ~= "" and f[i + 2] or nil }
        if g.id or g.name then return g end
    end

    if kind == "G" then
        if not IsLeaderName(sender) then return end   -- only the leader decides
        local g = Guide()
        if not g then return end
        local old = statuses[who]
        statuses[who] = { id = g.id, group = g.group, name = g.name,
                          step = old and old.step, total = old and old.total, line = old and old.line,
                          route = old and old.route }
        g.from = who
        OnLeaderGuide(g)
        Changed()
    elseif kind == "Q" then
        if IsLeader() then
            -- several asking at once (e.g. after a loading screen): one answer
            lastSent = nil
            Debounce("send", 2, SendGuide)
        end
        Debounce("status", 1, SendStatus)
        Debounce("route", 1.2, function() SendRoute(IsLeader() and "W" or "V") end)
        Debounce("xp", 1.5, function() if ns.XP then ns.XP:Send() end end)
        Debounce("missing", 1.8, function() if ns.Missing then ns.Missing:Send(true) end end)
        Debounce("blockers", 2.1, function() if ns.Blockers then ns.Blockers:Send(true) end end)
        Debounce("share", 2.4, function() if ns.Share then ns.Share:Send(true) end end)
        Debounce("progress", 2.7, function() if ns.Progress then ns.Progress:Send(true) end end)
        Debounce("travel", 3.0, function() if ns.Travel then ns.Travel:Send(true) end end)
    elseif kind == "S" then
        local st = Guide() or {}
        st.step, st.total, st.line = tonumber(f[6]), tonumber(f[7]), tonumber(f[8])
        st.route = statuses[who] and statuses[who].route
        statuses[who] = st
        Changed()
    elseif kind == "O" then
        if ns.Progress then ns.Progress:OnMessage(who, f) end
    elseif kind == "Z" then
        if ns.Travel then ns.Travel:OnMessage(who, f) end
    elseif kind == "Y" then
        if ns.Blockers then ns.Blockers:OnMessage(who, f) end
    elseif kind == "H" then
        if ns.Share then ns.Share:OnMessage(who, f) end
    elseif kind == "M" then
        if ns.Missing then ns.Missing:OnMessage(who, f) end
    elseif kind == "X" then
        if ns.XP then ns.XP:OnMessage(who, f) end
    elseif kind == "T" then
        local st = statuses[who] or {}
        if st.protocol then return end
        st.step, st.total, st.line = tonumber(f[3]), tonumber(f[4]), tonumber(f[5])
        statuses[who] = st
        Changed()
    elseif kind == "K" or kind == "J" then
        if not IsLeaderName(sender) then return end
        local n, g = tonumber(f[3]), Guide(4)
        if not n or not g or not Same(Mine(), g) then return end
        OnLeaderStep(kind, n, who, tonumber(f[7]))
    elseif kind == "W" then
        if not IsLeaderName(sender) or not f[3] then return end
        local st = statuses[who] or {}
        if not st.protocol then st.route = f[3]; statuses[who] = st end
        OnLeaderRoute(f[3], who)
    elseif kind == "V" then
        local st = statuses[who] or {}
        if st.protocol then return end
        st.route = f[3]
        statuses[who] = st
        Changed()
    elseif kind == "R" then
        local n, g = tonumber(f[3]), Guide(4)
        if not n or not g then return end
        OnSkipRequest(n, g, who, tonumber(f[7]))
    elseif kind == "P" then
        local g = Guide()
        if not g then return end
        g.from = who
        OnSuggestion(g)
    elseif kind == "N" then
        if IsLeaderName(sender) and Bare(f[3]) == Bare(UnitName("player")) then
            Print(f[4] == "R" and L.SKIP_DECLINED or L.DECLINED, who)
        end
    end
end

local function OnMessage(text, sender)
    local ok, err = pcall(HandleMessage, text, sender)
    if not ok then
        if debug then Print("|cffff6060%s|r", tostring(err)) end
        geterrorhandler()(err)
    end
end

---------------------------------------------------------------------------
-- /sl
---------------------------------------------------------------------------
local function GroupMembers()
    local out = {}
    for _, unit in ipairs(GroupUnits()) do
        local name, realm = UnitName(unit)
        name, realm = Plain(name), Plain(realm)
        if not name and UnitExists(unit) then name = "?" .. unit end   -- secret name
        if name then
            out[#out + 1] = { unit = unit, name = (realm and realm ~= "") and (name .. "-" .. realm) or name }
        end
    end
    return out
end

-- Everything the overview shows:
-- { inGroup, isLeader, target = label or nil,
--   members = { { name, class, lead, me, state = "same"|"other"|"unknown"|"old"|"newer", guide } } }
function ns.Snapshot()
    local snap = { inGroup = GroupChannel() ~= nil, isLeader = IsLeader(), members = {} }
    if not snap.inGroup then
        local mine = Mine()
        snap.mine = mine and GuideLabel(mine)
        return snap
    end
    local target = IsLeader() and Mine() or leaderGuide
    snap.target = target and GuideLabel(target)
    snap.myStep, snap.myTotal = MyStep()
    snap.inTarget = target and Same(Mine(), target) or false
    for _, m in ipairs(GroupMembers()) do
        local me = UnitIsUnit(m.unit, "player")
        local s = me and (Mine() or {}) or statuses[Bare(m.name)]
        local state, guide
        if not s then
            state = "unknown"
        elseif s.protocol then
            state = s.protocol < PROTOCOL and "old" or "newer"
        elseif target and Same(s, target) then
            state, guide = "same", GuideLabel(s)
        else
            state, guide = "other", (s.id or s.name) and GuideLabel(s) or nil
        end
        local _, class = UnitClass(m.unit)
        local step, total, line
        if me then step, total, line = snap.myStep, snap.myTotal, snap.myStep and StepLine(snap.myStep)
        elseif s and not s.protocol then step, total, line = s.step, s.total, s.line end
        local member = {
            name = m.name, class = Plain(class), me = me,
            lead = Plain(UnitIsGroupLeader(m.unit)) and true or false,
            state = state, guide = guide, step = step, total = total, line = line,
            unit = m.unit, connected = Plain(UnitIsConnected and UnitIsConnected(m.unit)) ~= false,
            blocker = ns.Blockers and db.showBlockers and ns.Blockers:Get(m.name, me) or nil,
        }
        if member.lead then snap.leaderStep, snap.leaderTotal, snap.leaderLine = step, total, line end
        snap.members[#snap.members + 1] = member
    end
    -- route settings: same as the leader's?
    local leadRoute = IsLeader() and MyRoute() or leaderRoute
    snap.leaderRoute = leadRoute
    for _, m in ipairs(snap.members) do
        local r
        if m.me then r = MyRoute()
        else local st = statuses[Bare(m.name)]; r = st and not st.protocol and st.route end
        if r and leadRoute then
            m.routeDiff = RouteDiff(leadRoute, r)
        end
    end
    -- how far each one is from the leader (only in the group guide). Counted
    -- in my guide via the lines; without lines only when the step counts agree.
    local function Pos(m)
        if snap.inTarget and m.line then
            local i = IndexForLine(m.line)
            if i then return i end
        end
        if m.total and snap.leaderTotal and m.total == snap.leaderTotal then return m.step end
    end
    local leader
    for _, m in ipairs(snap.members) do if m.lead then leader = m end end
    local leaderPos = leader and leader.step and Pos(leader)
    for _, m in ipairs(snap.members) do
        if m.state == "same" and m.step and leaderPos then
            local p = Pos(m)
            if p then m.diff = p - leaderPos end
        end
    end
    if leaderPos and snap.inTarget then
        snap.leaderStepText = StepText(leaderPos)
        snap.leaderRisk = SkipRisk(leaderPos)
    end
    return snap
end

local STATE_TEXT = {
    same = function() return "|cff40ff40" .. L.STATUS_SAME .. "|r" end,
    other = function(m) return "|cffff6060" .. L.STATUS_OTHER:format(m.guide or "-") .. "|r" end,
    unknown = function() return "|cff999999" .. L.STATUS_UNKNOWN .. "|r" end,
    old = function() return "|cffff9900" .. L.STATUS_OLD .. "|r" end,
    newer = function() return "|cffff9900" .. L.STATUS_NEWER .. "|r" end,
}
ns.STATE_TEXT = STATE_TEXT

local function ShowStatus()
    local snap = ns.Snapshot()
    if not snap.inGroup then return Print(L.NOT_IN_GROUP) end
    if snap.target then Print(L.STATUS_HEAD, snap.target) else Print(L.STATUS_NONE) end
    for _, m in ipairs(snap.members) do
        local lead = m.lead and (" (" .. L.STATUS_LEADER .. ")") or ""
        local step = m.step and ("  " .. L.STEP_OF:format(m.step, m.total or 0)) or ""
        local route = (m.routeDiff and #m.routeDiff > 0)
            and ("  |cffff9900" .. L.ROUTE_DIFFERS:format(table.concat(m.routeDiff, ", ")) .. "|r") or ""
        print(("   %s%s: %s%s%s"):format(m.name, lead, STATE_TEXT[m.state](m), step, route))
    end
end

-- What the buttons in the windows do
ns.Actions = {
    Send = function() lastSent = nil; SendGuide(true) end,
    Suggest = function() Suggest() end,
    Get = function()
        if not GroupChannel() then return Print(L.NOT_IN_GROUP) end
        if leaderGuide and not IsLeader() then Apply(leaderGuide) end
        AskLeader()
    end,
    SetEnabled = function(on)
        db.enabled = on and true or false
        Print(db.enabled and L.ON or L.OFF)
        if db.enabled then AskLeader() end
        Changed()
    end,
    SkipForGroup = function() SkipWithCheck((MyStep())) end,
    SendRoute = function()
        if not IsLeader() then return Print(L.NOT_LEADER) end
        SendRoute("W")
        Print(L.ROUTE_SENT)
    end,
    PullToMyStep = function() PullToMyStep() end,
    RequestSkip = function() RequestSkip() end,
    SetMode = function(mode)
        db.mode = mode
        Print(mode == "ask" and L.MODE_ASK or L.MODE_AUTO)
    end,
}

SLASH_SYNCLINE1 = "/sl"
SLASH_SYNCLINE2 = "/syncline"
SlashCmdList.SYNCLINE = function(msg)
    local cmd, rest = strtrim(msg or ""):lower():match("^(%S*)%s*(.-)$")
    if cmd == "" then
        if ns.GroupWindow then ns.GroupWindow:Toggle() else ShowStatus() end
    elseif cmd == "status" then
        ShowStatus()
    elseif cmd == L.CMD_OPTIONS or cmd == "options" or cmd == "config" then
        if ns.Options then ns.Options:Toggle() end
    elseif cmd == "minimap" then
        if rest == L.CMD_ON or rest == "on" then db.minimapButton = true
        elseif rest == L.CMD_OFF or rest == "off" then db.minimapButton = false
        else db.minimapButton = not db.minimapButton end
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    elseif cmd == L.CMD_SEND or cmd == "send" then
        ns.Actions.Send()
    elseif cmd == L.CMD_SUGGEST or cmd == "suggest" then
        ns.Actions.Suggest()
    elseif cmd == L.CMD_SKIP or cmd == "skip" then
        ns.Actions.RequestSkip()   -- leader: skips for the group, member: asks the leader
    elseif cmd == L.CMD_AUTOSHARE or cmd == "autoshare" then
        if ns.Share then
            if rest == L.CMD_ON or rest == "on" then ns.Share:SetAuto(true)
            elseif rest == L.CMD_OFF or rest == "off" then ns.Share:SetAuto(false)
            else ns.Share:SetAuto(not ns.db.autoShare) end
        end
    elseif cmd == L.CMD_SHARE or cmd == "share" then
        if ns.Share then
            local n = ns.Share:ShareAll()
            if n == 0 then Print(L.SHARE_NOTHING) end
        end
    elseif cmd == L.CMD_WHY or cmd == "why" then
        if ns.Blockers then
            local list = ns.Blockers:Check()
            if #list == 0 then Print(L.BLOCK_NONE) end
            for _, r in ipairs(list) do Print(ns.Blockers:Text(r)) end
        end
    elseif cmd == L.CMD_MISSING or cmd == "missing" then
        if ns.Missing then ns.Missing:PrintList() end
    elseif cmd == L.CMD_ROUTE or cmd == "route" then
        ns.Actions.SendRoute()
    elseif cmd == L.CMD_PULL or cmd == "pull" then
        ns.Actions.PullToMyStep()
    elseif cmd == L.CMD_GET or cmd == "get" then
        ns.Actions.Get()
    elseif cmd == L.CMD_AUTO or cmd == "auto" then
        ns.Actions.SetMode("auto")
    elseif cmd == L.CMD_ASK or cmd == "ask" then
        ns.Actions.SetMode("ask")
    elseif cmd == L.CMD_ON or cmd == "on" then
        ns.Actions.SetEnabled(true)
    elseif cmd == L.CMD_OFF or cmd == "off" then
        ns.Actions.SetEnabled(false)
    elseif cmd == "debug" then
        debug = not debug; Print("debug " .. (debug and "on" or "off"))
    elseif cmd == "version" then
        Print("%s (protocol %d)", ns.VERSION, PROTOCOL)
    else
        for _, line in ipairs(L.HELP) do print(line) end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns.frame = frame

local function OnGroupChanged()
    local inGroup = GroupChannel() ~= nil
    if inGroup and not wasInGroup then
        -- just joined: ask for the guide, the leader answers. After a short
        -- flicker (loading screen) we still know the leader's guide: no need.
        Debounce("join", 2, function()
            if not leaderGuide then AskLeader() end
            SendStatus()
        end)
    elseif not inGroup then
        -- really out of the group? Loading screens can report "no group" for a moment.
        Debounce("left", 5, function()
            if GroupChannel() then return end
            leaderGuide, lastSent, lastAnnounced, pending = nil, nil, nil, nil
            leaderRoute, lastRouteSent = nil, nil
            if ns.XP then ns.XP:Forget() end
            if ns.Missing then ns.Missing:Forget() end
            if ns.Blockers then ns.Blockers:Forget() end
            if ns.Share then ns.Share:Forget() end
            if ns.Progress then ns.Progress:Forget() end
            if ns.Travel then ns.Travel:Forget() end
            wipe(statuses)
            Changed()
        end)
    end
    wasInGroup = inGroup
    Changed()
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        SynclineDB = SynclineDB or {}
        db = SynclineDB
        ns.db = db
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        frame:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        local rxp = RXP()
        if not rxp then return Print(L.NO_RXP) end
        hooksecurefunc(rxp, "LoadGuide", function() Debounce("check", 0.3, CheckGuide) end)
        if rxp.SetStep then
            hooksecurefunc(rxp, "SetStep", function()
                Debounce("step", 1.5, SendStep)
                if ns.Missing then ns.Missing.Soon() end
                if ns.Blockers then ns.Blockers.Soon() end
                if ns.Share then ns.Share.Soon() end
                if ns.Progress then ns.Progress.Soon() end
                if ns.Travel then ns.Travel.Soon() end
                Changed()
            end)
        end
        C_Timer.NewTicker(2, function() CheckGuide(); CheckRoute() end)   -- also catches changes made elsewhere
        if ns.OnLoaded then ns.OnLoaded() end
        Print(L.LOADED)
    elseif event == "PLAYER_ENTERING_WORLD" then
        local login, reload = ...
        if login or reload then
            lastSeen = Key(CurrentGuide())
            wasInGroup = false
            OnGroupChanged()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnGroupChanged()
    elseif event == "PARTY_LEADER_CHANGED" then
        Changed()
        if IsLeader() then
            lastSent = nil
            Debounce("send", 1, SendGuide)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then Apply(pending) end
        if pendingStep then GoToStep(pendingStep) end
        if pendingRoute then ApplyRoute(pendingRoute) end
        if #queue > 0 and not pumping then Pump() end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, _, sender = ...
        if prefix == PREFIX and db then OnMessage(text, sender) end
    end
end)

for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE",
                     "PARTY_LEADER_CHANGED", "PLAYER_REGEN_ENABLED", "CHAT_MSG_ADDON" }) do
    frame:RegisterEvent(e)
end

-- for the tests
ns.test = {
    OnMessage = OnMessage, CheckGuide = CheckGuide, CurrentGuide = CurrentGuide, GuideID = GuideID,
    queue = queue, statuses = statuses, MyStep = MyStep, Mine = Mine, Overlap = Overlap,
    IndexForLine = IndexForLine, StepLine = StepLine, SkipRisk = SkipRisk,
    CheckRoute = CheckRoute,
    leaderGuide = function() return leaderGuide end,
}
