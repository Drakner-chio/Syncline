-- Syncline: settings window (/sl options), the minimap button, the button
-- in the addon list in the minimap corner, and an entry in the game's own
-- AddOns settings that opens the window.

local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local C = T.C
local O = {}
ns.Options = O

local frame
local controls = {}

local function Percent(v) return ("%d %%"):format(math.floor(v * 100 + 0.5)) end

local function Build()
    local W, PAD = 420, 12
    frame = T.Window("SynclineOptionsFrame", "Settings", W, 480, "optionsPos")
    frame:RestorePosition("CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    local cw = W - 2 * PAD

    -- Sync
    local y = -40
    local sync = T.Card(frame, "Sync", PAD, y, cw, 230)
    controls[#controls + 1] = T.Switch(sync, "Follow the group leader's guide", 16, -34,
        function() return ns.db.enabled end, function(v) ns.Actions.SetEnabled(v) end)
    controls[#controls + 1] = T.Choice(sync, "When the leader picks a guide", 16, -62, {
        { "auto", "Switch right away" }, { "ask", "Ask me first" },
    }, function() return ns.db.mode end, function(v) ns.Actions.SetMode(v) end, 150)
    controls[#controls + 1] = T.Switch(sync, "Offer to suggest a guide I pick myself", 16, -122,
        function() return ns.db.offerSuggest end, function(v) ns.db.offerSuggest = v end)
    T.Tooltip(controls[#controls], "Suggest",
        "When you load another guide yourself while in a group, a popup asks whether to suggest it to the leader.")
    controls[#controls + 1] = T.Switch(sync, "Let the leader skip steps and pull me to his step", 16, -148,
        function() return ns.db.followSteps end, function(v) ns.db.followSteps = v end)
    T.Tooltip(controls[#controls], "Skip step",
        "When the leader skips a step or pulls the group to his step, you go along (or get asked, see above).")
    controls[#controls + 1] = T.Switch(sync, "Take the leader's RestedXP route settings", 16, -174,
        function() return ns.db.followRoute end, function(v) ns.db.followRoute = v end)
    T.Tooltip(controls[#controls], "RestedXP route settings",
        "Dungeons, skip overleveled steps, group quests, Solo Self Found and EXP rate decide which steps a guide has. With the leader's settings everyone has the same steps.")
    controls[#controls + 1] = T.Switch(sync, "As leader: send my route settings to the group", 16, -200,
        function() return ns.db.shareRoute end, function(v) ns.db.shareRoute = v; if v then ns.CheckRoute() end end)

    -- Window
    y = y - 240
    local win = T.Card(frame, "Group window", PAD, y, cw, 128)
    controls[#controls + 1] = T.Slider(win, "Size", 16, -30, cw - 32,
        function() return ns.db.windowScale end,
        function(v) ns.db.windowScale = v; ns.GroupWindow:ApplySettings() end,
        0.7, 1.5, 0.05, Percent)
    controls[#controls + 1] = T.Switch(win, "Lock windows (no dragging)", 16, -72,
        function() return ns.db.locked end, function(v) ns.db.locked = v end)
    local reset = T.FlatButton(win, "Reset window positions", 170, 22)
    reset:SetPoint("TOPLEFT", 16, -96)
    reset:SetScript("OnClick", function()
        ns.db.groupPos, ns.db.optionsPos = nil, nil
        ns.GroupWindow:ApplySettings(true)
        frame:RestorePosition("CENTER", 0, 0)
    end)

    -- General
    y = y - 138
    local gen = T.Card(frame, "General", PAD, y, cw, 144)
    controls[#controls + 1] = T.Switch(gen, "Minimap button", 16, -34,
        function() return ns.db.minimapButton end,
        function(v) ns.db.minimapButton = v; ns.UpdateMinimapButton() end)
    controls[#controls + 1] = T.Switch(gen, "Slack meter (only you see it, as leader)", 16, -60,
        function() return ns.db.slackMeter end,
        function(v) ns.db.slackMeter = v; ns.GroupWindow:Refresh() end)
    T.Tooltip(controls[#controls], "Slack meter",
        "In the group window: how long the group waited for whom – time someone was behind your step. Doesn't count while you're in combat or away, or while they're offline.")
    controls[#controls + 1] = T.Switch(gen, "Experience overview of the group", 16, -86,
        function() return ns.db.xpOverview end,
        function(v) ns.db.xpOverview = v; ns.GroupWindow:Refresh() end)
    local found = T.Text(gen, "", 11, C.faint, true)
    found:SetPoint("TOPLEFT", 16, -116)
    controls[#controls + 1] = { Refresh = function()
        local rxp = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("RXPGuides")
        found:SetText(L["RestedXP Guides: %s"]:format(rxp and ("|cff5cd97a" .. L["found"] .. "|r")
            or ("|cffdb5c5c" .. L["not found"] .. "|r")))
    end }

    local hint = T.Text(frame, "", 11, C.faint, true)
    hint:SetText("/sl " .. L.CMD_OPTIONS .. "  ·  /sl " .. L.CMD_HELP .. "  ·  v" .. tostring(ns.VERSION))
    hint:SetPoint("BOTTOMLEFT", PAD + 2, 12)

    frame:SetHeight(-y + 144 + 40)
    frame:SetScript("OnShow", function() O:Refresh() end)
end

function O:Refresh()
    for _, c in ipairs(controls) do if c.Refresh then c.Refresh() end end
end

function O:Toggle()
    if not frame then Build() end
    if frame:IsShown() then frame:Hide() else frame:Show(); O:Refresh() end
end

---------------------------------------------------------------------------
-- Clicks on the minimap button and the addon list button
---------------------------------------------------------------------------
function ns.HandleClick(which)
    if which == "RightButton" or which == "MiddleButton" or (IsShiftKeyDown and IsShiftKeyDown()) then
        O:Toggle()
    else
        ns.GroupWindow:Toggle()
    end
end

function Syncline_OnCompartmentClick(_, which) ns.HandleClick(which) end

-- Key bindings (Esc → Options → Keybindings → AddOns → Syncline)
BINDING_HEADER_SYNCLINE = "Syncline"
BINDING_NAME_SYNCLINE_SKIP = L["Skip step (leader) / request skip"]
BINDING_NAME_SYNCLINE_WINDOW = L["Group window"]
function Syncline_Skip() ns.Actions.RequestSkip() end
function Syncline_ToggleWindow() ns.GroupWindow:Toggle() end

local function ButtonTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine(T.CHAT_PREFIX)
    local snap = ns.Snapshot()
    if snap.inGroup then
        GameTooltip:AddDoubleLine(L["Group guide"], snap.target or L["none yet"], C.muted[1], C.muted[2], C.muted[3],
            C.accent[1], C.accent[2], C.accent[3])
        local same, total = 0, #snap.members
        for _, m in ipairs(snap.members) do if m.state == "same" then same = same + 1 end end
        GameTooltip:AddDoubleLine(L["In it"], ("%d / %d"):format(same, total), C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
    end
    if not ns.db.enabled then GameTooltip:AddLine(L.OFF, C.warn[1], C.warn[2], C.warn[3], true) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Left-click: group window"], 1, 1, 1)
    GameTooltip:AddLine(L["Right-click: settings"], 1, 1, 1)
    GameTooltip:AddLine(L["Drag: move this button"], C.muted[1], C.muted[2], C.muted[3])
    GameTooltip:Show()
end

function Syncline_OnCompartmentEnter(_, owner) ButtonTooltip(owner) end
function Syncline_OnCompartmentLeave() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Minimap button: drag it round the minimap
---------------------------------------------------------------------------
local button

local function Position()
    local angle = math.rad(ns.db.minimapAngle or 200)
    local radius = (Minimap:GetWidth() / 2) + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function BuildButton()
    if button or not Minimap then return end
    local b = CreateFrame("Button", "SynclineMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture(T.LOGO)
    icon:SetPoint("TOPLEFT", 6, -5)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    b:SetScript("OnClick", function(_, which) ns.HandleClick(which) end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.db.minimapAngle = math.deg(math.atan2(py / scale - my, px / scale - mx))
            Position()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", ButtonTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button = b
    Position()
end

function ns.UpdateMinimapButton()
    if not ns.db then return end
    if ns.db.minimapButton and not button then BuildButton() end
    if button then button:SetShown(ns.db.minimapButton) end
end

---------------------------------------------------------------------------
-- The game's settings (Esc → Options → AddOns → Syncline)
---------------------------------------------------------------------------
local function RegisterSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(40, 40)
    logo:SetPoint("TOPLEFT", 16, -12)
    logo:SetTexture(T.LOGO)
    local title = T.Text(panel, "", 20, C.text, true)
    title:SetText("|cff" .. T.ACCENT_HEX .. "Syncline|r")
    title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    local note = T.Text(panel, "The group leader picks a RestedXP guide, everyone in the group follows. All settings are in Syncline's own window.", 13, C.muted)
    note:SetPoint("TOPLEFT", 16, -64)
    note:SetWidth(520)
    note:SetWordWrap(true)
    local open = T.FlatButton(panel, "Open settings", 140, 24)
    open:SetPrimary(true)
    open:SetPoint("TOPLEFT", 16, -104)
    open:SetScript("OnClick", function()
        if SettingsPanel and HideUIPanel then HideUIPanel(SettingsPanel) end
        O:Toggle()
    end)
    local group = T.FlatButton(panel, "Group window", 140, 24)
    group:SetPoint("LEFT", open, "RIGHT", 8, 0)
    group:SetScript("OnClick", function()
        if SettingsPanel and HideUIPanel then HideUIPanel(SettingsPanel) end
        ns.GroupWindow:Toggle()
    end)
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Syncline")
    if ok and category then pcall(Settings.RegisterAddOnCategory, category) end
end

ns.OnLoaded = function()
    ns.UpdateMinimapButton()
    if ns.Slack then ns.Slack:Start() end
    RegisterSettings()
end
