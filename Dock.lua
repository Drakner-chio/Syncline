-- Syncline: a strip docked to the RestedXP guide window. It hangs right
-- under (or over) the window, as wide as it, moves, scales and hides with
-- it, and shows Syncline's info as short lines: the group, quest progress,
-- group steps, quests not accepted, hearthstone and flight paths, quests to
-- share, experience, slack meter, and small buttons. Which lines show is
-- set in the strip's cog menu; each line only shows when it has something.
--
-- Works with RestedXP's classic window (RXPFrame) and the new V2 window.

local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local C = T.C
local D = {}
ns.Dock = D

local LINE_H, MAX_LINES = 15, 14
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
-- Where to dock: the V2 window when it's on, else the classic one
---------------------------------------------------------------------------
local function RXP()
    return ns.Missing and ns.Missing.RXP and ns.Missing.RXP()
end

function D:Anchor()
    local rxp = RXP()
    local v2 = rxp and rxp.v2
    if v2 and v2.IsEnabled and v2.GetGuideWindowAnchorFrame then
        local ok, on = pcall(v2.IsEnabled, v2)
        if ok and on then
            local ok2, f = pcall(v2.GetGuideWindowAnchorFrame, v2)
            if ok2 and f then return f end
        end
    end
    return _G.RXPFrame
end

-- "below" or "above": RestedXP windows that grow upwards get the strip on top
function D:Side()
    local side = ns.db and ns.db.dockSide or "auto"
    if side == "below" or side == "above" then return side end
    local rxp = RXP()
    local p = rxp and rxp.settings and rxp.settings.profile
    return (p and p.anchorOrientation == "bottom") and "above" or "below"
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
    menu:SetSize(240, -y + 60)
    menu:Hide()
end

function D:ToggleMenu()
    if not dock then return end
    if not menu then BuildMenu() end
    if menu:IsShown() then menu:Hide(); return end
    menu:ClearAllPoints()
    if D:Side() == "above" then menu:SetPoint("BOTTOMLEFT", dock, "BOTTOMRIGHT", 4, 0)
    else menu:SetPoint("TOPLEFT", dock, "TOPRIGHT", 4, 0) end
    menu:Show()
    for _, sw in ipairs(menu.switches) do sw:Refresh() end
    menu.side.Refresh()
end

local function Build()
    dock = CreateFrame("Frame", "SynclineDock", UIParent)
    T.Fill(dock, C.win)
    T.Border(dock, C.edge)
    dock:EnableMouse(true)

    header = CreateFrame("Button", nil, dock)
    header:SetHeight(18)
    header:SetPoint("TOPLEFT", 8, -4)
    header:SetPoint("TOPRIGHT", -26, -4)
    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(12, 12)
    logo:SetPoint("LEFT", 0, 0)
    logo:SetTexture(T.LOGO)
    header.title = T.Text(header, "", 10, C.muted, true)
    header.title:SetPoint("LEFT", logo, "RIGHT", 5, 0)
    header.title:SetPoint("RIGHT", 0, 0)
    header.title:SetWordWrap(false)
    header:SetScript("OnClick", function() ns.GroupWindow:Toggle() end)
    T.Tooltip(header, "Syncline", "Opens the group window.")

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

-- dock to the RestedXP window; nil when there is none or it's hidden
local function Dock()
    local a = D:Anchor()
    if not a then return nil end
    if a ~= anchorFrame or dock.side ~= D:Side() then
        anchorFrame = a
        dock.side = D:Side()
        dock:SetParent(a)          -- moves, scales and hides with it
        dock:SetFrameStrata(a.GetFrameStrata and a:GetFrameStrata() or "MEDIUM")
        dock:ClearAllPoints()
        if dock.side == "above" then
            dock:SetPoint("BOTTOMLEFT", a, "TOPLEFT", 0, 2)
            dock:SetPoint("BOTTOMRIGHT", a, "TOPRIGHT", 0, 2)
        else
            dock:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -2)
            dock:SetPoint("TOPRIGHT", a, "BOTTOMRIGHT", 0, -2)
        end
    end
    return a
end

function D:Refresh()
    if not dock then Build() end
    local snap = ns.Snapshot and ns.Snapshot()
    if not (D:Enabled() and snap and snap.inGroup and Dock()) then
        dock:Hide()
        if menu then menu:Hide() end
        return
    end

    local guide = snap.target or L["none yet"]
    local step = snap.leaderStep and ("  ·  " .. snap.leaderStep .. "/" .. (snap.leaderTotal or "?")) or ""
    header.title:SetText(T.Upper(T.NAME) .. "  " .. Hexed(C.faint, guide .. step))

    local list = D:Lines(snap)
    local y = -24
    for i, l in ipairs(list) do
        local r = Line(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 10, y)
        r:SetPoint("TOPRIGHT", -8, y)
        r.text:SetText(l.text)
        r.onClick, r.tip = l.onClick, l.tip
        r:Show()
        y = y - LINE_H
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
