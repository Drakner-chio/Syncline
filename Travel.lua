-- Syncline: hearthstone and flight paths. Every Syncline checks the steps
-- ahead in its own guide and sends:
--   Z^<protocol>^<hearth cooldown s>^<steps to the next ".hs">^<bind ok: 1/0/->^<bind location>^<missing flight path ids>
-- * the hearthstone's cooldown (0 = ready)
-- * how many steps until the guide says "hearth"
-- * whether the hearthstone is set where that ".hs" step expects it
--   (RestedXP's ".bindlocation", compared on each client in its own language)
-- * flight paths that ".fly" steps ahead need but the player hasn't got
--   (RestedXP's flight path ids, the same in every language)
-- The bind location is the player's own text, only for showing.

local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local C = T.C
local V = {}
ns.Travel = V

local HEARTHSTONE = 6948
local LOOK_HS = 12          -- steps ahead to look for ".hs"
local LOOK_FLY = 25         -- steps ahead to look for ".fly"
local mine = {}
local others = {}          -- [bare name] = { cd, hsIn, bindOk, bind, fps = {} }
local lastSent

local function H() return ns.Missing end
local function Bare(name) return (tostring(name or ""):gsub("[%- ].*", "")) end
local function Now() return GetTime and GetTime() or 0 end

local function HearthCooldown()
    local f = (C_Container and C_Container.GetItemCooldown) or _G.GetItemCooldown
    if not f then return nil end
    local ok, start, duration = pcall(f, HEARTHSTONE)
    if not ok or not start then return nil end
    if start == 0 or not duration or duration == 0 then return 0 end
    return math.max(0, math.floor(start + duration - Now()))
end

local function Bind()
    local ok, b = pcall(GetBindLocation)
    return ok and b or nil
end

-- the flight path id RestedXP uses for a ".fly" destination
local function FlightPathId(location)
    local rxp = H().RXP()
    if not location or not rxp or not rxp.FPDB then return nil end
    local faction = rxp.player and rxp.player.faction or (UnitFactionGroup and UnitFactionGroup("player"))
    local db = faction and rxp.FPDB[faction]
    if type(db) ~= "table" then return nil end
    local pattern = location:gsub("%-", "%%-")
    for id, fp in pairs(db) do
        if type(fp) == "table" and fp.name and string.upper(fp.name):find(pattern) then return id end
    end
end

local function KnowsFlightPath(id)
    local known = _G.RXPCData and RXPCData.flightPaths
    return type(known) == "table" and known[id] ~= nil
end

function V:FlightPathName(id)
    local rxp = H().RXP()
    local faction = rxp and rxp.player and rxp.player.faction
    local db = rxp and rxp.FPDB and faction and rxp.FPDB[faction]
    local entry = type(db) == "table" and db[id]
    if type(entry) == "table" and entry.name then return entry.name end
    local known = _G.RXPCData and RXPCData.flightPaths
    if type(known) == "table" and known[id] then return known[id] end
    return "#" .. tostring(id)
end

function V:Scan()
    local guide, cur = H().CurrentStep()
    local m = { cd = HearthCooldown(), bind = Bind(), fps = {} }
    if guide and cur then
        local seenFp = {}
        for i = cur, math.min(#guide.steps, cur + LOOK_FLY) do
            local step = guide.steps[i]
            for _, e in ipairs(H().Elements(step)) do
                if type(e) == "table" then
                    -- the next ".hs": how far, and is the hearthstone set where it expects?
                    if not m.hsIn and i <= cur + LOOK_HS and e.tag == "hs" then
                        m.hsIn = i - cur
                        for _, e2 in ipairs(H().Elements(step)) do
                            if type(e2) == "table" and (e2.tag == "bindlocation" or e2.tag == "home") and e2.location then
                                local reverse = (tonumber(e2.flags) or 0) % 2 == 1
                                if not reverse then m.bindOk = (m.bind == e2.location) end
                            end
                        end
                    end
                    if e.tag == "fly" and e.location then
                        local id = FlightPathId(e.location)
                        if id and not seenFp[id] and not KnowsFlightPath(id) then
                            seenFp[id] = true
                            m.fps[#m.fps + 1] = id
                        end
                    end
                end
            end
        end
    end
    mine = m
    return m
end

function V:Mine() return mine end

function V:Send(force)
    if not ns.Send or not (IsInGroup and IsInGroup()) then return end
    local m = mine
    local bindOk = m.bindOk == nil and "-" or (m.bindOk and "1" or "0")
    local bind = tostring(m.bind or ""):gsub("[%^,]", "")
    local fps = table.concat(m.fps or {}, ",")
    -- the cooldown counts down by itself: send it rounded to the minute
    local cd = m.cd and math.floor((m.cd + 59) / 60) * 60 or ""
    local text = table.concat({ cd, m.hsIn or "", bindOk, bind, fps }, "^")
    if text == lastSent and not force then return end
    lastSent = text
    ns.Send("Z", cd, m.hsIn or "", bindOk, bind, fps)
end

function V:OnMessage(who, f)
    local fps = {}
    for id in tostring(f[7] or ""):gmatch("%d+") do fps[#fps + 1] = tonumber(id) end
    others[who] = {
        cd = tonumber(f[3]), cdAt = Now(), hsIn = tonumber(f[4]),
        bindOk = (f[5] == "1" and true) or (f[5] == "0" and false) or nil,
        bind = f[6] ~= "" and f[6] or nil, fps = fps,
    }
    if ns.Changed then ns.Changed() end
end

function V:Forget() wipe(others); lastSent = nil end

-- a member's data (name as in the window), with the cooldown counted down
function V:Get(name, me)
    if me then return mine end
    local o = others[Bare(name)]
    if not o then return nil end
    local copy = {}
    for k, v in pairs(o) do copy[k] = v end
    if o.cd then copy.cd = math.max(0, o.cd - (Now() - o.cdAt)) end
    return copy
end

local function Minutes(sec)
    if not sec then return "?" end
    if sec <= 0 then return L["ready"] end
    return L["%d min"]:format(math.ceil(sec / 60))
end

---------------------------------------------------------------------------
-- In the group window: when a ".hs" comes soon or a flight path is missing
---------------------------------------------------------------------------
local card, rows
local ROW_H, SHOW = 22, 6

function V:Attach(parent, x, width)
    card = T.Card(parent, "Hearthstone and flight paths", x, 0, width, 100)
    rows = {}
    for i = 1, SHOW do
        local r = CreateFrame("Frame", nil, card)
        r:SetSize(width - 2, ROW_H)
        r:SetPoint("TOPLEFT", 1, -30 - (i - 1) * ROW_H)
        r.name = T.Text(r, "", 13, C.text, true)
        r.name:SetPoint("LEFT", 14, 0)
        r.name:SetWidth(90)
        r.name:SetWordWrap(false)
        r.info = T.Text(r, "", 12, C.muted, true)
        r.info:SetPoint("LEFT", 108, 0)
        r.info:SetPoint("RIGHT", -10, 0)
        r.info:SetWordWrap(false)
        rows[i] = r
    end
    return card
end

function V:Layout(y, snap)
    if not card then return 0 end
    if not (snap.inGroup and ns.db.travelCheck) then card:Hide(); return 0 end
    -- only when it matters: a ".hs" soon (for anyone), or someone lacks a flight path
    local soon = false
    for _, m in ipairs(snap.members) do
        local d = V:Get(m.name, m.me)
        if d and ((d.hsIn and d.hsIn <= 5) or (d.fps and #d.fps > 0)) then soon = true end
    end
    if not soon then card:Hide(); return 0 end
    local n = 0
    for _, m in ipairs(snap.members) do
        local d = V:Get(m.name, m.me)
        if d and n < SHOW then
            n = n + 1
            local r = rows[n]
            local parts = {}
            if d.hsIn and d.hsIn <= 5 then
                local cd = Minutes(d.cd)
                parts[#parts + 1] = L["Hearth"] .. ": " .. ((d.cd and d.cd > 0) and ("|cff" .. T.Hex(C.warn) .. cd .. "|r") or ("|cff5cd97a" .. cd .. "|r"))
                if d.bindOk == false then
                    parts[#parts + 1] = "|cff" .. T.Hex(C.bad) .. L["set to %s"]:format(d.bind or "?") .. "|r"
                end
            end
            if d.fps and #d.fps > 0 then
                local names = {}
                for i, id in ipairs(d.fps) do names[i] = V:FlightPathName(id) end
                parts[#parts + 1] = "|cff" .. T.Hex(C.warn) .. L["lacks flight path %s"]:format(table.concat(names, ", ")) .. "|r"
            end
            if #parts == 0 then parts[1] = "|cff5cd97a" .. L["all set"] .. "|r" end
            r.name:SetText("|cff" .. T.ClassHex(m.class) .. Bare(m.name) .. "|r")
            r.info:SetText(table.concat(parts, "  ·  "))
            r:Show()
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
function V.Soon()
    if pending then return end
    pending = true
    C_Timer.After(2, function()
        pending = false
        V:Scan()
        V:Send()
        if ns.Changed then ns.Changed() end
    end)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function() V.Soon() end)
for _, e in ipairs({ "PLAYER_LOGIN", "HEARTHSTONE_BOUND", "BAG_UPDATE_COOLDOWN", "TAXIMAP_CLOSED",
                     "UI_INFO_MESSAGE", "GROUP_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA" }) do
    ev:RegisterEvent(e)
end
-- the cooldown runs down: look again every minute
C_Timer.NewTicker(60, function() V.Soon() end)
