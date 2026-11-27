-- Syncline: a strip docked to the RestedXP guide window. It hangs right
-- under (or over) the window, as wide as it, moves, scales and hides with
-- it, and shows Syncline's info as short lines: the group, quest progress,
-- group steps, quests not accepted, hearthstone and flight paths, quests to
-- share, experience, slack meter, and small buttons. Which lines show is
-- set in the strip's cog menu; each line only shows when it has something.
--
-- Works with RestedXP's classic window (RXPFrame), the new V2 window and
-- EUI-RestedXP's reskin: that one keeps RXPFrame alive but invisible and
-- draws its own window (EUIRestedXPTimeline), with RestedXP's target and
-- item boxes glued under it. The strip then hangs under those boxes (over
-- them when EUI grows upwards) and takes EllesmereUI's look: its font with
-- an outline, the dark step card with the hairline edge, the orange of
-- "STEP 1", buttons in the EUI accent.

local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local C = T.C
local D = {}
ns.Dock = D

local LINE_H, MAX_LINES = 15, 14   -- LINE_H follows the font size, see Refresh
D.LINES = { "group", "groupstep", "progress", "missing", "travel", "share", "xp", "slack", "buttons" }
local LINE_LABEL = {
    group = "Group at a glance", groupstep = "Group step", progress = "Quest progress",
    missing = "Missing and not accepted quests", travel = "Hearthstone and flight paths",
    share = "Share quests", xp = "Experience", slack = "Slack meter", buttons = "Buttons",
}
local LINE_DEFAULT = {
    group = true, groupstep = true, progress = true, missing = true, travel = true,
    share = true, xp = false, slack = false, buttons = true,
}

local dock, header, lines, menu, btns = nil, nil, {}, nil, {}
local anchorFrame

local function Hexed(c, text) return "|cff" .. T.Hex(c) .. text .. "|r" end
local function Short(name) return (tostring(name or ""):gsub("[%- ].*", "")) end
local function Who(m) return "|cff" .. T.ClassHex(m.class) .. Short(m.name) .. "|r" end
local function QName(q) return ns.QuestName and ns.QuestName(q) or ("#" .. q) end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
function D:Enabled() return ns.db and ns.db.dock ~= false end

function D:Shows(key)
    local t = ns.db and ns.db.dockLines
    if type(t) == "table" and t[key] ~= nil then return t[key] and true or false end
    return LINE_DEFAULT[key] and true or false
end

function D:SetLine(key, on)
    if type(ns.db.dockLines) ~= "table" then ns.db.dockLines = {} end
    ns.db.dockLines[key] = on and true or false
    D:Refresh()
end

---------------------------------------------------------------------------
-- Where to dock. RestedXP's own window (classic or V2), unless a skin addon
-- made it invisible and draws its own: then the visible window that hangs
-- on RestedXP's. That covers EUI-RestedXP, FUI-RestedXP, BeautifulRestedXP
-- and LiteTweaks' reskin (one engine family), and skins we don't know yet.
-- Skins that only repaint RestedXP's window (ElvUI-style) need nothing.
---------------------------------------------------------------------------
local function RXP()
    return ns.Missing and ns.Missing.RXP and ns.Missing.RXP()
end

local function EUIDB() return type(_G.EUIRestedxPCache) == "table" and _G.EUIRestedxPCache or nil end
local function Num(v) return type(v) == "number" and v or nil end
local function Visible(f)
    if not (f and f.IsShown and f:IsShown()) then return false end
    local a = f.GetAlpha and Num(f:GetAlpha())
    return not (a and a <= 0)
end

-- skin windows we know by name (checked first, cheap)
D.KNOWN = { "EUIRestedXPTimeline", "FUIRestedXPTimeline", "BeautifulRestedXPTimeline" }

local found, nextScan = nil, 0
local function HangsOn(f, target)
    if not (f and f.GetNumPoints) then return nil end
    local ok, n = pcall(f.GetNumPoints, f)
    if not ok or type(n) ~= "number" then return nil end
    for i = 1, n do
        local ok2, point, rel = pcall(f.GetPoint, f, i)
        if ok2 and rel == target then return point end
    end
end

-- the skin's window, when RestedXP's own is there but invisible
function D:SkinWindow()
    local rxpf = _G.RXPFrame
    if not (rxpf and rxpf.IsShown and rxpf:IsShown()) then return nil end
    local a = rxpf.GetAlpha and Num(rxpf:GetAlpha())
    if not (a and a <= 0) then return nil end
    local db = EUIDB()
    if db and (db.rxpEnabled == false or db.rxpLayout == "DEFAULT") then return nil end
    for _, name in ipairs(D.KNOWN) do
        if Visible(_G[name]) then return _G[name] end
    end
    if found and Visible(found) and HangsOn(found, rxpf) then return found end
    found = nil
    -- look for it now and then: a shown frame anchored to RestedXP's window
    local now = GetTime and GetTime() or 0
    if now < nextScan then return nil end
    nextScan = now + 10
    local ok, kids = pcall(function() return { UIParent:GetChildren() } end)
    if not ok then return nil end
    for _, f in ipairs(kids) do
        -- forbidden and protected frames can refuse to be asked: skip them
        local ok2, hit = pcall(function()
            if f == D.frame or (f.IsForbidden and f:IsForbidden()) then return false end
            if not (Visible(f) and HangsOn(f, rxpf)) then return false end
            local w = f.GetWidth and Num(f:GetWidth())
            return w and w > 80
        end)
        if ok2 and hit then found = f; return f end
    end
end
D.EUIWindow = D.SkinWindow   -- older name

-- does the skin's window grow upwards (pinned by its bottom edge)?
local FLIP = { FRAMELESS = true, TIMELINE = true, RAIL = true, COMPACT = true }
local function SkinFlip(w)
    local db = EUIDB()
    if db and w == _G.EUIRestedXPTimeline then
        return db.rxpFlip == true and FLIP[db.rxpLayout or "FRAMELESS"] and true or false
    end
    local point = HangsOn(w, _G.RXPFrame)
    return type(point) == "string" and point:find("^BOTTOM") ~= nil
end

function D:Anchor()
    local skin = D:SkinWindow()
    if skin then return skin end
    local rxp = RXP()
    local v2 = rxp and rxp.v2
    if v2 and v2.IsEnabled and v2.GetGuideWindowAnchorFrame then
        local ok, on = pcall(v2.IsEnabled, v2)
        if ok and on then
            local ok2, f = pcall(v2.GetGuideWindowAnchorFrame, v2)
            if ok2 and f then return f end
        end
    end
    local f = _G.RXPFrame
    if f and Visible(f) then return f end
    return nil
end

-- "dock": hangs on the guide window; "free": a window of its own. Docked
-- without a guide window to hang on, it is free too.
function D:Mode()
    return (ns.db and ns.db.dockMode == "free") and "free" or "dock"
end

-- "below" or "above": RestedXP windows that grow upwards get the strip on top
function D:Side()
    local side = ns.db and ns.db.dockSide or "auto"
    if side == "below" or side == "above" then return side end
    local skin = D:SkinWindow()
    if skin then return SkinFlip(skin) and "above" or "below" end
    local rxp = RXP()
    local p = rxp and rxp.settings and rxp.settings.profile
    return (p and p.anchorOrientation == "bottom") and "above" or "below"
end

---------------------------------------------------------------------------
-- The look. Auto takes, in this order: EllesmereUI (with EUI-RestedXP's
-- card settings), ElvUI, RestedXP's active theme (which skin addons can
-- register too), else ours.
---------------------------------------------------------------------------
local function RGBA(c, a)
    if type(c) ~= "table" then return nil end
    local r, g, b = c.r or c[1], c.g or c[2], c.b or c[3]
    if type(r) ~= "number" then return nil end
    return { r, g, b, a or c.a or c[4] or 1 }
end

local function OwnStyle()
    return { kind = "syncline", font = T.FONT, flags = "", size = 11, label = C.muted, bg = C.win, edge = C.edge }
end

local function EUIStyle(E)
    local font
    if type(E.GetFontPath) == "function" then
        local ok, p = pcall(E.GetFontPath, nil)
        if ok and type(p) == "string" then font = p end
    end
    font = font or "Interface\\AddOns\\EUI-RestedXP\\Fonts\\Expressway.ttf"
    local db = EUIDB() or {}
    return {
        kind = "eui", eui = true, font = font, flags = "OUTLINE", size = db.rxpFlTextSize or 12,
        label = { db.rxpFlStepColR or 0.91, db.rxpFlStepColG or 0.64, db.rxpFlStepColB or 0.24 },
        bg = { 0, 0, 0, (db.rxpFlCardA or 65) / 100 },
        edge = { db.rxpFlBorderR or 1, db.rxpFlBorderG or 1, db.rxpFlBorderB or 1, db.rxpFlBorderA or 0.07 },
        accent = RGBA(E.ELLESMERE_GREEN) or { 0.05, 0.82, 0.62, 1 },
    }
end

local function ElvStyle()
    local ok, E = pcall(function() return unpack(_G.ElvUI) end)
    local m = ok and type(E) == "table" and E.media
    if type(m) ~= "table" then return nil end
    local accent = RGBA(m.rgbvaluecolor)
    return {
        kind = "elvui", font = type(m.normFont) == "string" and m.normFont or T.FONT, flags = "", size = 12,
        label = accent or C.muted,
        bg = RGBA(m.backdropfadecolor) or RGBA(m.backdropcolor, 0.85) or C.win,
        edge = RGBA(m.bordercolor) or C.edge,
        accent = accent,
    }
end

local function RXPStyle()
    local rxp = RXP()
    local th = rxp and (rxp.activeTheme or rxp.colors)
    if type(th) ~= "table" or type(th.background) ~= "table" then return nil end
    local accent = RGBA(th.mapPins, 1) or RGBA(th.bottomFrameHighlight, 1)
    local bg = RGBA(th.background, 0.92)
    return {
        kind = "rxp", font = (type(th.font) == "string" and th.font) or (type(rxp.font) == "string" and rxp.font) or T.FONT,
        flags = "", size = 12,
        label = accent or C.muted,
        bg = bg or C.win,
        edge = accent and { accent[1], accent[2], accent[3], 0.35 } or C.edge,
        accent = accent,
    }
end

function D:Style()
    local mode = ns.db and ns.db.dockStyle or "auto"
    if mode == "syncline" then return OwnStyle() end
    if _G.EllesmereUI then return EUIStyle(_G.EllesmereUI) end
    if type(_G.ElvUI) == "table" then
        local st = ElvStyle()
        if st then return st end
    end
    return RXPStyle() or OwnStyle()
end

local function SetFont(fs, st, size)
    if not (fs and fs.SetFont) then return end
    local ok = pcall(fs.SetFont, fs, st.font, size or st.size, st.flags)
    if not ok then pcall(fs.SetFont, fs, T.FONT, size or st.size, "") end
    if st.eui then
        if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
        if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 0.8) end
    end
end

---------------------------------------------------------------------------
-- What the lines say
---------------------------------------------------------------------------
-- { { text, onClick?, tip? } } for the shown lines (not the buttons)
function D:Lines(snap)
    local out = {}
    local function add(text, onClick, tip) out[#out + 1] = { text = text, onClick = onClick, tip = tip } end
    if not snap.inGroup then return out end
    local leader = snap.isLeader

    if D:Shows("group") then
        local chips, together = {}, 0
        for _, m in ipairs(snap.members) do
            local c = m.state == "same" and C.good or (m.state == "other" and C.bad or (m.state == "unknown" and C.faint or C.warn))
            if m.connected == false then c = C.faint end
            if m.state == "same" then together = together + 1 end
            chips[#chips + 1] = Hexed(c, "•") .. Who(m)
        end
        add(table.concat(chips, " ") .. "  " .. Hexed(C.faint, together .. "/" .. #snap.members),
            function() ns.GroupWindow:Toggle() end, "Opens the group window.")
        local issues = ns.GroupWindow and ns.GroupWindow.Issues and ns.GroupWindow:Issues(snap) or {}
        for i = 1, math.min(3, #issues) do add("  " .. issues[i].text) end
    end

    local P = ns.Progress
    if P and D:Shows("groupstep") and ns.db.groupQuestCheck then
        local check = P:GroupCheck(snap)
        if check then
            if #check == 0 then
                add(Hexed(C.accent, L["Group step"]) .. ": " .. Hexed(C.good, L["all set"]))
            else
                for _, c in ipairs(check) do
                    local why = {}
                    if #c.lacks > 0 then
                        local names = {}
                        for i, q in ipairs(c.lacks) do names[i] = QName(q) end
                        why[#why + 1] = L["lacks %s"]:format(table.concat(names, ", "))
                    end
                    if c.far then why[#why + 1] = L["not in range"] end
                    add(Hexed(C.accent, L["Group step"]) .. ": |cff" .. T.ClassHex(c.class) .. c.name .. "|r " .. Hexed(C.warn, table.concat(why, " · ")))
                end
            end
        end
    end

    if P and D:Shows("progress") and ns.db.questProgress then
        local n = 0
        for _, q in ipairs(P:Quests()) do
            if n >= 3 then break end
            local parts = {}
            for _, m in ipairs(snap.members) do
                local p = P:Get(m.name, m.me, q)
                if p then
                    local val = p.complete and Hexed(C.good, p.need > 0 and (p.need .. "/" .. p.need) or L["done"])
                        or ("|cffffffff" .. p.done .. "/" .. p.need .. "|r")
                    parts[#parts + 1] = Who(m) .. " " .. val
                end
            end
            if #parts > 0 then
                n = n + 1
                local all = P:AllDone(q)
                add((all and Hexed(C.good, QName(q)) or Hexed(C.text, QName(q))) .. "  " .. table.concat(parts, " "))
            end
        end
    end

    local M = ns.Missing
    if M and D:Shows("missing") and ns.db.missingQuests then
        local mineN, ids, fresh = M:Get(nil, true)
        for _, id in ipairs(ids or {}) do
            if fresh and fresh[id] then add(Hexed(C.bad, L["not accepted"] .. ": " .. QName(id))) end
        end
        local later = 0
        for _, id in ipairs(ids or {}) do if not (fresh and fresh[id]) then later = later + 1 end end
        if later > 0 then add(Hexed(C.warn, L["Missing quests"] .. ": " .. later), function() M:PrintList() end, "Lists them in the chat.") end
        if leader then
            for _, m in ipairs(snap.members) do
                if not m.me then
                    local _, oids, ofresh = M:Get(m.name)
                    for _, id in ipairs(oids or {}) do
                        if ofresh and ofresh[id] then add(Who(m) .. ": " .. Hexed(C.bad, L["not accepted"] .. ": " .. QName(id))) end
                    end
                end
            end
        end
    end

    local V = ns.Travel
    if V and D:Shows("travel") and ns.db.travelCheck then
        local hs, fps = {}, {}
        for _, m in ipairs(snap.members) do
            local d = V:Get(m.name, m.me)
            if d and d.hsIn and d.hsIn <= 5 then
                local txt = (d.cd and d.cd > 0) and Hexed(C.warn, L["%d min"]:format(math.ceil(d.cd / 60))) or Hexed(C.good, L["ready"])
                if d.bindOk == false then txt = txt .. " " .. Hexed(C.bad, L["set to %s"]:format(d.bind or "?")) end
                hs[#hs + 1] = Who(m) .. " " .. txt
            end
            if d and d.fps and #d.fps > 0 then
                local names = {}
                for i, id in ipairs(d.fps) do names[i] = V:FlightPathName(id) end
                fps[#fps + 1] = Who(m) .. " " .. Hexed(C.warn, L["lacks flight path %s"]:format(table.concat(names, ", ")))
            end
        end
        if #hs > 0 then add(Hexed(C.accent, L["Hearth"]) .. ": " .. table.concat(hs, "  ")) end
        for i = 1, math.min(2, #fps) do add(fps[i]) end
    end

    local S = ns.Share
    if S and D:Shows("share") and ns.db.shareQuests then
        for i, o in ipairs(S:Offers()) do
            if i > 2 then break end
            add(Hexed(C.accent, L["Share"]) .. ": " .. QName(o.quest) .. " " .. Hexed(C.faint, L["for %s"]:format(table.concat(o.who, ", "))),
                function() S:ShareQuest(o.quest) end, "Click to share it with the group.")
        end
    end

    local X = ns.XP
    if X and D:Shows("xp") and ns.db.xpOverview then
        local parts = {}
        for _, m in ipairs(snap.members) do
            local d = X:Get(m.name, m.me)
            if d and d.max and d.max > 0 then
                parts[#parts + 1] = Who(m) .. " " .. X.Short(math.max(0, d.max - d.xp))
            end
        end
        if #parts > 0 then add(Hexed(C.accent, L["XP to level"]) .. ": " .. table.concat(parts, "  ")) end
    end

    local SL = ns.Slack
    if SL and leader and D:Shows("slack") and ns.db.slackMeter then
        local r = SL:Ranking()[1]
        if r and r.waited > 0 then
            add(Hexed(C.accent, L["Slack meter"]) .. ": |cff" .. T.ClassHex(r.class) .. r.name .. "|r " .. Hexed(C.warn, SL.Clock(r.waited)))
        end
    end

    while #out > MAX_LINES do table.remove(out) end
    return out
end

---------------------------------------------------------------------------
-- The strip
---------------------------------------------------------------------------
local function Line(i)
    if lines[i] then return lines[i] end
    local b = CreateFrame("Button", nil, dock)
    b:SetHeight(LINE_H)
    b.text = T.Text(b, "", 11, C.text, true)
    b.text:SetPoint("LEFT", 0, 0)
    b.text:SetPoint("RIGHT", 0, 0)
    b.text:SetWordWrap(false)
    b:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    b:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L[self.tip], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lines[i] = b
    return b
end

local BUTTON = {
    skip = { "Skip", function() ns.Actions.SkipForGroup() end, true },
    pull = { "To me", function() ns.Actions.PullToMyStep() end },
    send = { "Send", function() ns.Actions.Send() end },
    get = { "Get guide", function() ns.Actions.Get() end, true },
    suggest = { "Suggest", function() ns.Actions.Suggest() end },
    request = { "Request skip", function() ns.Actions.RequestSkip() end },
}

local function BuildMenu()
    menu = CreateFrame("Frame", nil, dock)
    menu:SetFrameStrata("DIALOG")
    T.Fill(menu, C.head)
    T.Border(menu, C.edge)
    menu:EnableMouse(true)
    local cap = T.Caption(menu, "Lines")
    cap:SetPoint("TOPLEFT", 14, -12)
    menu.switches = {}
    local y = -32
    for _, key in ipairs(D.LINES) do
        local sw = T.Switch(menu, LINE_LABEL[key], 14, y,
            function() return D:Shows(key) end, function(v) D:SetLine(key, v) end)
        menu.switches[#menu.switches + 1] = sw
        y = y - 24
    end
    local side = T.Choice(menu, "Position", 14, y - 4,
        { { "auto", "Auto" }, { "below", "Below" }, { "above", "Above" } },
        function() return ns.db.dockSide or "auto" end,
        function(v) ns.db.dockSide = v; D:Refresh() end, 66)
    menu.side = side
    local mode = T.Choice(menu, "Mode", 14, y - 104,
        { { "dock", "Docked" }, { "free", "Own window" } },
        function() return D:Mode() end,
        function(v) ns.db.dockMode = v; D:Refresh(); D:ToggleMenu(); D:ToggleMenu() end, 100)
    menu.mode = mode
    menu.width = T.Slider(menu, "Width (own window)", 14, y - 154, 212,
        function() return ns.db.dockWidth or 260 end,
        function(v) ns.db.dockWidth = v; D:Refresh() end, 200, 420, 10)
    local look = T.Choice(menu, "Look", 14, y - 54,
        { { "auto", "Auto" }, { "syncline", "Syncline" } },
        function() return ns.db.dockStyle or "auto" end,
        function(v) ns.db.dockStyle = v; D:Refresh() end, 100)
    menu.look = look
    menu:SetSize(240, -y + 200)
    menu:Hide()
end

function D:ToggleMenu()
    if not dock then return end
    if not menu then BuildMenu() end
    if menu:IsShown() then menu:Hide(); return end
    menu:ClearAllPoints()
    if not D.free and D:Side() == "above" then menu:SetPoint("BOTTOMLEFT", dock, "BOTTOMRIGHT", 4, 0)
    else menu:SetPoint("TOPLEFT", dock, "TOPRIGHT", 4, 0) end
    menu:Show()
    for _, sw in ipairs(menu.switches) do sw:Refresh() end
    menu.side.Refresh()
    menu.look.Refresh()
    menu.mode.Refresh()
    menu.width.Refresh()
end

local function Build()
    dock = CreateFrame("Frame", "SynclineDock", UIParent)
    dock.bg = T.Fill(dock, C.win)
    T.Border(dock, C.edge)
    dock:EnableMouse(true)

    header = CreateFrame("Button", nil, dock)
    header:SetHeight(18)
    header:SetPoint("TOPLEFT", 8, -4)
    header:SetPoint("TOPRIGHT", -26, -4)
    local logo = header:CreateTexture(nil, "ARTWORK")
    header.logo = logo
    logo:SetSize(12, 12)
    logo:SetPoint("LEFT", 0, 0)
    logo:SetTexture(T.LOGO)
    header.label = T.Text(header, "", 10, C.muted, true)
    header.label:SetPoint("LEFT", logo, "RIGHT", 5, 0)
    header.title = T.Text(header, "", 10, C.faint, true)
    header.title:SetPoint("LEFT", header.label, "RIGHT", 6, 0)
    header.title:SetPoint("RIGHT", 0, 0)
    header.title:SetWordWrap(false)
    header:SetScript("OnClick", function() ns.GroupWindow:Toggle() end)
    T.Tooltip(header, "Syncline", "Opens the group window. As a window of its own: drag it here.")
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if not D.free or (ns.db and ns.db.locked) then return end
        dock:SetMovable(true)
        dock:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        if not D.free then return end
        dock:StopMovingOrSizing()
        local point, _, rel, x, y = dock:GetPoint()
        ns.db.dockPos = { point, rel, x, y }
    end)

    local cog = CreateFrame("Button", nil, dock)
    cog:SetSize(18, 18)
    cog:SetPoint("TOPRIGHT", -5, -4)
    local icon = cog:CreateTexture(nil, "ARTWORK")
    icon:SetSize(12, 12)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
    cog:SetScript("OnClick", function() D:ToggleMenu() end)
    T.Tooltip(cog, "Lines", "Which lines the strip shows, and where it sits.")

    for key, def in pairs(BUTTON) do
        local b = T.FlatButton(dock, def[1], 60, 18)
        b:SetPrimary(def[3])
        b:SetScript("OnClick", def[2])
        btns[key] = b
    end
    D.frame, D.buttons = dock, btns
    dock:Hide()
end

-- what the strip hangs from: the window itself, or with EUI the lowest
-- (highest when it grows upwards) of RestedXP's boxes it glued to the window
local function Holder(a, side)
    if a ~= D:SkinWindow() then return a end
    local db = EUIDB()
    if db and db.rxpBoxLock == false then return a end   -- boxes placed freely
    local best = a
    for _, f in ipairs({ _G.RXPTargetFrame, _G.RXPItemFrame }) do
        local alpha = f and f.GetAlpha and f:GetAlpha()
        if f and f.IsShown and f:IsShown() and not (type(alpha) == "number" and alpha <= 0) then
            if side == "below" then
                local b, bb = f.GetBottom and f:GetBottom(), best.GetBottom and best:GetBottom()
                if type(b) == "number" and type(bb) == "number" and b < bb then best = f end
            else
                local t, bt = f.GetTop and f:GetTop(), best.GetTop and best:GetTop()
                if type(t) == "number" and type(bt) == "number" and t > bt then best = f end
            end
        end
    end
    return best
end

-- dock to the RestedXP window; nil when there is none or it's hidden
local function Dock()
    local a = D:Anchor()
    if not a then return nil end
    local side = D:Side()
    local holder = Holder(a, side)
    if a ~= anchorFrame or holder ~= dock.holder or dock.side ~= side then
        if InCombatLockdown and InCombatLockdown() and holder ~= a then holder = dock.holder or a end
        anchorFrame, dock.holder, dock.side = a, holder, side
        dock:SetParent(a)          -- moves, scales, fades and hides with it
        dock:SetScale(1)
        if dock.SetClampedToScreen then dock:SetClampedToScreen(false) end
        dock:SetFrameStrata(a.GetFrameStrata and a:GetFrameStrata() or "MEDIUM")
        dock:ClearAllPoints()
        if holder == a then
            if side == "above" then
                dock:SetPoint("BOTTOMLEFT", a, "TOPLEFT", 0, 2)
                dock:SetPoint("BOTTOMRIGHT", a, "TOPRIGHT", 0, 2)
            else
                dock:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -2)
                dock:SetPoint("TOPRIGHT", a, "BOTTOMRIGHT", 0, -2)
            end
        else
            -- under (over) a box: its edge for the height, the window's left
            -- edge and width for the rest (EUI lines the boxes up with it)
            local dx = 0
            local hl, al = holder.GetLeft and holder:GetLeft(), a.GetLeft and a:GetLeft()
            if type(hl) == "number" and type(al) == "number" then
                local hs, as = holder:GetEffectiveScale() or 1, a:GetEffectiveScale() or 1
                dx = (al * as - hl * hs) / hs
            end
            if side == "above" then dock:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", dx, 8)
            else dock:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", dx, -8) end
        end
    end
    if holder ~= a then
        local w = a.GetWidth and a:GetWidth()
        if type(w) == "number" and w > 0 then dock:SetWidth(w) end
    end
    return a
end

-- a window of its own: where it was dragged to, as wide as set
local function Free()
    if anchorFrame ~= "free" then
        anchorFrame, dock.holder, dock.side = "free", nil, nil
        dock:SetParent(UIParent)
        dock:SetFrameStrata("MEDIUM")
        if dock.SetClampedToScreen then dock:SetClampedToScreen(true) end
        dock:ClearAllPoints()
        local p = ns.db.dockPos
        if type(p) == "table" and p[1] then
            dock:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
        else
            dock:SetPoint("LEFT", UIParent, "LEFT", 24, 140)
        end
    end
    dock:SetWidth(ns.db.dockWidth or 260)
    dock:SetScale(math.max(0.5, math.min(2, ns.db.windowScale or 1)))
    return true
end

-- docked, or free: by choice, or because there's no RestedXP window at all
local function Place()
    if D:Mode() == "free" then D.free = Free(); return true end
    if Dock() then D.free = false; return true end
    if not _G.RXPFrame then D.free = Free(); return true end
    return false   -- RestedXP's window is hidden right now: so are we
end

function D:Refresh()
    if not dock then Build() end
    local snap = ns.Snapshot and ns.Snapshot()
    if not (D:Enabled() and snap and snap.inGroup and Place()) then
        dock:Hide()
        if menu then menu:Hide() end
        return
    end

    local st = D:Style()
    D.style = st
    dock.bg:SetColorTexture(st.bg[1], st.bg[2], st.bg[3], st.bg[4] or 1)
    if dock.SetEdgeColor then dock:SetEdgeColor(st.edge) end
    header.logo:SetShown(not st.eui)
    header.label:ClearAllPoints()
    if st.eui then header.label:SetPoint("LEFT", 0, 0) else header.label:SetPoint("LEFT", header.logo, "RIGHT", 5, 0) end
    SetFont(header.label, st, st.eui and (st.size - 1) or 10)
    SetFont(header.title, st, st.eui and (st.size - 1) or 10)
    header.label:SetTextColor(st.label[1], st.label[2], st.label[3])
    local lineH = st.size + 4

    local guide = snap.target or L["none yet"]
    local step = snap.leaderStep and ("  ·  " .. snap.leaderStep .. "/" .. (snap.leaderTotal or "?")) or ""
    header.label:SetText(T.Upper(T.NAME))
    header.title:SetText(Hexed(C.faint, guide .. step))

    local list = D:Lines(snap)
    local y = -24
    for i, l in ipairs(list) do
        local r = Line(i)
        SetFont(r.text, st)
        r:SetHeight(lineH)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 10, y)
        r:SetPoint("TOPRIGHT", -8, y)
        r.text:SetText(l.text)
        r.onClick, r.tip = l.onClick, l.tip
        r:Show()
        y = y - lineH
    end
    for i = #list + 1, #lines do lines[i]:Hide() end

    for _, b in pairs(btns) do b:Hide() end
    if D:Shows("buttons") and ns.GroupWindow and ns.GroupWindow.Buttons then
        local row = ns.GroupWindow:Buttons(snap)
        local n = #row
        if n > 0 then
            local w = dock.GetWidth and dock:GetWidth() or 230
            if type(w) ~= "number" or w < 60 then w = 230 end
            local bw = (w - 16 - 4 * (n - 1)) / n
            for i, key in ipairs(row) do
                local b = btns[key]
                b:SetAccent(st.accent)
                if b.GetFontString and b:GetFontString() then SetFont(b:GetFontString(), st, st.eui and (st.size - 1) or 12) end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 8 + (i - 1) * (bw + 4), y - 3)
                b:SetWidth(bw)
                b:Show()
            end
            y = y - 23
        end
    end
    D.shown = list
    dock:SetHeight(-y + 6)
    dock:Show()
end

-- RestedXP builds its V2 window late and can switch windows: look again now and then
local ticker
function D:Start()
    if ticker or not C_Timer.NewTicker then return end
    ticker = C_Timer.NewTicker(2, function() if D:Enabled() then D:Refresh() end end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() C_Timer.After(2, function() D:Refresh(); D:Start() end) end)
