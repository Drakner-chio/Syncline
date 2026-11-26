-- A small fake of the game's API: enough to load Syncline outside the game.
LOG, SENT, TIMERS = {}, {}, {}
REAL_PRINT = print
function print(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end LOG[#LOG+1] = table.concat(t, " ") end
function GetLocale() return STATE and STATE.locale or "deDE" end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function geterrorhandler() return function(e) error(e) end end
function hooksecurefunc(t, k, fn) local orig = t[k] t[k] = function(...) local r = orig(...) fn(...) return r end end
C_Timer = { After = function(d, fn) TIMERS[#TIMERS+1] = fn end, NewTicker = function() end }
function RunTimers() for _ = 1, 20 do local t = TIMERS TIMERS = {} if #t == 0 then return end for _, fn in ipairs(t) do fn() end end end
C_ChatInfo = { RegisterAddonMessagePrefix = function() end,
               SendAddonMessage = function(p, text, ch) SENT[#SENT+1] = text return 0 end }
STATE = { group = true, leader = "Leader", me = "Me", combat = false, locale = "deDE" }
function IsInGroup() return STATE.group end
function IsInRaid() return false end
function InCombatLockdown() return STATE.combat end
-- STATE.secretNames: names of other units come back as secret values
SECRET = newproxy(true)
getmetatable(SECRET).__index = function() error("attempt to index a secret value") end
getmetatable(SECRET).__tostring = function() return "<secret>" end
function issecretvalue(v) return v == SECRET end
function UnitName(u)
    if u == "player" then return STATE.me, "Beansen" end
    if STATE.secretNames then return SECRET, SECRET end
    if u == "party1" then return STATE.me == "Leader" and "Bob" or "Leader", "Beansen" end
    if u == "party2" then return "Fluffy", "Shocks" end
end
function UnitIsUnit(a, b) return a == b end
function UnitIsGroupLeader(u)
    if u == "player" then return STATE.me == STATE.leader end
    if u == "party1" then return STATE.me ~= STATE.leader end
    if u == "party2" then return false end
    return (u:gsub("%-.*", "")) == STATE.leader   -- a name, with or without realm
end
function GetNumSubgroupMembers() return 2 end
function GetNumGroupMembers() return 2 end
-- same realm as me: without realm, other realms: with it
function UnitIsGroupLeaderName(n) return (n:gsub("%-.*", "")) == STATE.leader end
function Ambiguate(n) if n:find("-Beansen", 1, true) then return (n:gsub("%-.*", "")) end return n end
StaticPopupDialogs = {}
POPUPS = {}
function StaticPopup_Show(w, t, _, data) POPUPS[#POPUPS+1] = { which = w, text = t, data = data } end
function StaticPopup_Hide() end
SlashCmdList = {}
-- Frames, textures and font strings take any method. The ones the tests look
-- at remember what they were given.
local Obj = {}
Obj.__index = function(self, k)
    local v = rawget(Obj, k)
    if v then return v end
    return function() end
end
function Obj:SetScript(k, fn) rawset(self, "scripts", rawget(self, "scripts") or {}); self.scripts[k] = fn end
function Obj:GetScript(k) local sc = rawget(self, "scripts") return sc and sc[k] end
function Obj:SetText(t) rawset(self, "text", t) end
function Obj:GetText() return rawget(self, "text") end
function Obj:Show() rawset(self, "shown", true); local sc = rawget(self, "scripts"); local f = sc and sc.OnShow; if f then f(self) end end
function Obj:Hide() rawset(self, "shown", false) end
function Obj:IsShown() return rawget(self, "shown") and true or false end
function Obj:SetShown(v) if v then self:Show() else self:Hide() end end
function Obj:GetWidth() return 140 end
function Obj:GetStringWidth() return 80 end
function Obj:GetCenter() return 100, 100 end
function Obj:GetEffectiveScale() return 1 end
function Obj:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Obj:CreateTexture() return setmetatable({}, Obj) end
function Obj:CreateFontString() local fs = setmetatable({}, Obj) FONTSTRINGS[#FONTSTRINGS + 1] = fs return fs end
FONTSTRINGS, FRAMES = {}, {}
function CreateFrame(kind, name)
    local f = setmetatable({ kind = kind, name = name }, Obj)
    if not EVENT_FRAME then EVENT_FRAME = f end
    if name then _G[name] = f end
    FRAMES[#FRAMES + 1] = f
    return f
end
function Fire(e, ...) rawget(EVENT_FRAME, "scripts").OnEvent(EVENT_FRAME, e, ...) end
function TextShown(text)
    local all = {}
    for _, x in ipairs(FONTSTRINGS) do all[#all + 1] = x end
    for _, x in ipairs(FRAMES) do all[#all + 1] = x end
    for _, fs in ipairs(all) do
        local t = rawget(fs, "text")
        if type(t) == "string" and t:find(text, 1, true) then return true end
    end
end
UIParent = setmetatable({}, Obj)
Minimap = setmetatable({}, Obj)
GameTooltip = setmetatable({}, Obj)
TOOLTIP = {}
function GameTooltip:AddLine(t) TOOLTIP[#TOOLTIP + 1] = tostring(t) end
function GameTooltip:AddDoubleLine(a, b) TOOLTIP[#TOOLTIP + 1] = tostring(a) .. " " .. tostring(b) end
UISpecialFrames = {}
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
SETTINGS = {}
Settings = { RegisterCanvasLayoutCategory = function(panel, name) return { name = name } end,
             RegisterAddOnCategory = function(c) SETTINGS[#SETTINGS + 1] = c.name end }
C_AddOns = { IsAddOnLoaded = function(n) return n == "RXPGuides" end, GetAddOnMetadata = function() return "0.4.0" end }
function GetCursorPosition() return 150, 100 end
function IsShiftKeyDown() return false end
function UnitClass(u) return "Krieger", "WARRIOR" end

-- fake RestedXP
-- a German client: RestedXP's German Forever guides
DE, EN = "RestedXP Forever Route (H)", "RestedXP Forever Guide (H)"
RXPCData = { currentGuideGroup = DE, currentGuideName = "01-06 Durotar" }
local function G(group, name, extra)
    local g = extra or {}
    g.group, g.name, g.steps, g.guideId = group, name, {}, 1000
    for i = 1, 20 do
        -- like RestedXP: stepId = line in the guide text + guideId; a step every 3 lines
        g.steps[i] = { index = i, stepId = 1000 + i * 3,
                       elements = { { text = "|cRXP_FRIENDLY_Kaltunk::3521|r Schritt " .. i .. " bei |T123:0|tKaltunk" } } }
    end
    return g
end
GUIDES = { [DE .. "||01-06 Durotar"] = G(DE, "01-06 Durotar"),
           [DE .. "||06-10 Durotar"] = G(DE, "06-10 Durotar"),
           ["RestedXP Horde Magier AoE||12-17 Das Brachland AoE"] = G("RestedXP Horde Magier AoE", "12-17 Das Brachland AoE"),
           [DE .. "||Locked"] = G(DE, "Locked", { locked = true }) }
LOADS = 0
RXP = { guides = GUIDES, GetGuideTable = function(g, n) return GUIDES[g .. "||" .. n] end }
RXPCData.currentStep = 1
RXP.currentGuide = GUIDES[DE .. "||01-06 Durotar"]
function RXP:LoadGuide(guide)
    LOADS = LOADS + 1
    if guide.locked then guide = { name = "", group = "", steps = {} } end
    if not guide.steps then guide = RXP:FetchGuide(guide) end
    RXPCData.currentGuideGroup, RXPCData.currentGuideName = guide.group, guide.name
    RXP.currentGuide = guide
    RXPCData.currentStep = 1
end
function RXP.GetGuideProgress() return RXPCData.currentStep end
RELOADS = 0
function RXP:ReloadGuide(keepStep) RELOADS = RELOADS + 1 end
RXP.settings = {
    profile = { enableAutomaticXpRate = false, xprate = 1, enableXpStepSkipping = true,
                enableGroupQuests = true, soloSelfFound = false,
                dungeons = { DM = true, SFK = false, RFC = true } },
    dungeons = {},
}
function RXP.settings.dungeons:GetDungeons() return { DM = "Die Todesminen", SFK = "Burg Shadowfang", RFC = "Ragefireabgrund", WC = "Höhlen des Wehklagens" } end

-- imported (paid) guides: only metadata until RestedXP parses them
local function Quests(ids)
    local steps = {}
    for i, q in ipairs(ids) do
        steps[i] = { elements = { { tag = (i % 2 == 0) and "turnin" or "accept", questId = q, text = "Quest " .. q } } }
    end
    return steps
end
RIVER_IDS = { 9001, 9002, 9003, 9004, 9005, 9006, 9007, 9008, 9009, 9010, 9011 }
GUIDES[DE .. "||43-44 Flusslande II"] = { group = DE, name = "43-44 Flusslande II", key = "fl2", imported = true }
GUIDES[DE .. "||43-44 Sümpfe des Elends"] = { group = DE, name = "43-44 Sümpfe des Elends", key = "se", imported = true }
PARSED = { fl2 = Quests(RIVER_IDS), se = Quests({ 7001, 7002, 7003, 7004, 7005 }) }
FETCHES = 0
function RXP:FetchGuide(guide)
    FETCHES = FETCHES + 1
    if guide.steps then return guide end
    local steps = PARSED[guide.key]
    if not steps then return nil end
    return { group = guide.group, name = guide.name, key = guide.key, steps = steps }
end
function RXP.SetStep(n) RXPCData.currentStep = n end

function UnitExists(u) return u == "player" or u == "party1" or u == "party2" end
