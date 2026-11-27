-- Syncline: the look. Same style as GearShare and Gatherline: near-black
-- panels with hairline edges, white text, one light blue accent for what
-- matters, small uppercase section titles. Every widget the windows use is
-- built here.

local ADDON, ns = ...
local L = ns.L
local T = {}
ns.Theme = T

T.NAME = "Syncline"
T.LOGO = "Interface\\AddOns\\" .. tostring(ADDON) .. "\\media\\Logo"
T.FONT = "Fonts\\ARIALN.TTF"   -- in every client, every language's letters
T.ACCENT_HEX = "4fc3f7"
T.CHAT_PREFIX = "|T" .. T.LOGO .. ":0|t |cff" .. T.ACCENT_HEX .. T.NAME .. "|r"

local C = {
    win       = { 0.051, 0.056, 0.067, 0.96 },
    head      = { 0.035, 0.039, 0.047, 1 },
    card      = { 0.078, 0.084, 0.098, 1 },
    cardHi    = { 0.098, 0.106, 0.122, 1 },
    line      = { 0.14, 0.15, 0.17, 1 },
    edge      = { 0.19, 0.20, 0.23, 1 },
    btn       = { 0.12, 0.13, 0.15, 1 },
    btnHi     = { 0.17, 0.18, 0.21, 1 },
    btnEdge   = { 0.24, 0.25, 0.29, 1 },
    accent    = { 0.31, 0.765, 0.969, 1 },
    accentHi  = { 0.50, 0.85, 1.0, 1 },
    accentDim = { 0.12, 0.30, 0.40, 1 },
    good      = { 0.36, 0.85, 0.48 },
    bad       = { 0.86, 0.36, 0.36 },
    warn      = { 0.95, 0.72, 0.30 },
    text      = { 0.93, 0.94, 0.96 },
    muted     = { 0.58, 0.61, 0.67 },
    faint     = { 0.42, 0.45, 0.50 },
    dark      = { 0.04, 0.05, 0.05 },
}
T.C = C

local function Upper(s)
    return (s:upper():gsub("ä", "Ä"):gsub("ö", "Ö"):gsub("ü", "Ü"))
end
T.Upper = Upper

local function Fill(frame, color, layer, sub)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or -8)
    t:SetAllPoints()
    t:SetColorTexture(unpack(color))
    return t
end

-- Hairline edges (1 pixel each side)
local function Border(frame, color)
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(unpack(color))
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(1)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(1)
        end
        edges[#edges + 1] = t
    end
    function frame:SetEdgeColor(c) for _, e in ipairs(edges) do e:SetColorTexture(unpack(c)) end end
    return edges
end

-- Text in our font. text is translated (L) here; pass raw = true for names.
local function Text(parent, text, size, color, raw)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if fs.SetFont then pcall(fs.SetFont, fs, T.FONT, size or 13, "") end
    local c = color or C.text
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH("LEFT")
    fs:SetText(text and (raw and text or L[text]) or "")
    return fs
end

-- Flat button: dark with a hairline edge, lighter on hover; b:SetPrimary(true)
-- paints it light blue.
local function FlatButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 100, height or 22)
    b.bg = Fill(b, C.btn)
    Border(b, C.btnEdge)
    local fs = Text(b, "", 12)
    fs:SetPoint("CENTER")
    fs:SetJustifyH("CENTER")
    b:SetFontString(fs)
    b:SetText(text and L[text] or "")
    function b:Restyle()
        local hi = self.hover
        if self.primary then
            self.bg:SetColorTexture(unpack(hi and C.accentHi or C.accent))
            self:SetEdgeColor(hi and C.accentHi or C.accent)
            fs:SetTextColor(C.dark[1], C.dark[2], C.dark[3])
        else
            self.bg:SetColorTexture(unpack(hi and C.btnHi or C.btn))
            self:SetEdgeColor(hi and C.accentDim or C.btnEdge)
            fs:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end
    function b:SetPrimary(on) self.primary = on and true or false; self:Restyle() end
    function b:SetHover(on) self.hover = on; self:Restyle() end
    b:SetScript("OnEnter", function(self) self:SetHover(true) end)
    b:SetScript("OnLeave", function(self) self:SetHover(false) end)
    b:Restyle()
    return b
end

T.Fill, T.Border, T.Text, T.FlatButton = Fill, Border, Text, FlatButton

-- Hover tooltip with a light blue title and a wrapped white line (both translated)
function T.Tooltip(widget, title, body)
    widget:SetScript("OnEnter", function(self)
        if self.SetHover then self:SetHover(true) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title then GameTooltip:AddLine(L[title], C.accent[1], C.accent[2], C.accent[3]) end
        if body then GameTooltip:AddLine(L[body], 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function(self)
        if self.SetHover then self:SetHover(false) end
        GameTooltip:Hide()
    end)
end

-- A small spaced-out uppercase label
function T.Caption(parent, text)
    local fs = Text(parent, "", 10, C.muted)
    fs:SetText(Upper(L[text]))
    return fs
end

-- A window: dark panel, a header strip with the name and a close cross,
-- dragged by the header, its place kept in SynclineDB[posKey].
function T.Window(name, title, width, height, posKey)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(width, height)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    Fill(f, C.win)
    Border(f, C.edge)

    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(28)
    Fill(head, C.head)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() if not (ns.db and ns.db.locked) then f:StartMoving() end end)
    head:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, rel, x, y = f:GetPoint()
        if posKey and ns.db then ns.db[posKey] = { point, rel, x, y } end
    end)
    local line = head:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    line:SetColorTexture(unpack(C.line))

    local logo = head:CreateTexture(nil, "ARTWORK")
    logo:SetSize(16, 16)
    logo:SetPoint("LEFT", 9, 0)
    logo:SetTexture(T.LOGO)
    local t = Text(head, "", 13)
    t:SetText("|cff" .. T.ACCENT_HEX .. T.NAME .. "|r  |cff9aa0aa" .. L[title] .. "|r")
    t:SetPoint("LEFT", logo, "RIGHT", 7, 0)
    f.title = t

    local close = CreateFrame("Button", nil, head)
    close:SetSize(28, 28)
    close:SetPoint("RIGHT", 0, 0)
    local x = Text(close, "", 15, C.muted, true)
    x:SetText("×")
    x:SetPoint("CENTER")
    close:SetScript("OnEnter", function() x:SetTextColor(C.text[1], C.text[2], C.text[3]) end)
    close:SetScript("OnLeave", function() x:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    close:SetScript("OnClick", function() f:Hide() end)
    f.head, f.close = head, close

    function f:RestorePosition(defaultPoint, dx, dy)
        self:ClearAllPoints()
        local p = posKey and ns.db and ns.db[posKey]
        if p and p[1] then
            self:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
        else
            self:SetPoint(defaultPoint or "CENTER", UIParent, defaultPoint or "CENTER", dx or 0, dy or 0)
        end
    end

    -- Size from the settings (scaleKey in SynclineDB, 1 = 100 %)
    function f:ApplyScale(scaleKey)
        local s = scaleKey and ns.db and ns.db[scaleKey] or 1
        self:SetScale(math.max(0.5, math.min(2, s)))
    end

    -- Escape closes it
    if name and UISpecialFrames then table.insert(UISpecialFrames, name) end
    f:Hide()
    return f
end

-- Class color as a hex string ("ffffff" when unknown)
function T.ClassHex(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not c then return "ffffff" end
    return ("%02x%02x%02x"):format(math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end

function T.Hex(color)
    return ("%02x%02x%02x"):format(math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

---------------------------------------------------------------------------
-- Settings widgets
---------------------------------------------------------------------------
-- On/off switch: b:SetOn(bool) paints it, b:IsOn() reads it; clicks call onChange(on)
function T.Switch(parent, text, x, y, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(32, 16)
    b:SetPoint("TOPLEFT", x, y)
    local track = b:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    local knob = b:CreateTexture(nil, "ARTWORK")
    knob:SetSize(12, 12)
    function b:SetOn(on)
        self.on = on and true or false
        track:SetColorTexture(unpack(self.on and C.accentDim or { 0.19, 0.20, 0.23, 1 }))
        knob:SetColorTexture(unpack(self.on and C.accent or { 0.55, 0.57, 0.62, 1 }))
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", self, "LEFT", self.on and 18 or 2, 0)
    end
    function b:IsOn() return self.on end
    local label = Text(parent, text, 13)
    label:SetPoint("LEFT", b, "RIGHT", 10, 0)
    local w = label.GetStringWidth and label:GetStringWidth()
    b:SetHitRectInsets(0, -(10 + math.ceil(type(w) == "number" and w or 0)), -4, -4)
    b:SetScript("OnClick", function(self)
        set(not self:IsOn())
        self:SetOn(get())
    end)
    function b.Refresh() b:SetOn(get()) end
    b.label = label
    b:Refresh()
    return b
end

-- Slider with its title on the left and the value (light blue) on the right
function T.Slider(parent, text, x, y, width, get, set, min, max, step, fmt)
    step, fmt = step or 1, fmt or "%d"
    local function show(v) return type(fmt) == "function" and fmt(v) or fmt:format(v) end
    local title = Text(parent, text, 13)
    title:SetPoint("TOPLEFT", x, y)
    local value = Text(parent, "", 13, C.accent, true)
    value:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y)
    value:SetJustifyH("RIGHT")

    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(width, 14)
    s:SetPoint("TOPLEFT", x, y - 20)
    s:SetHitRectInsets(0, 0, -6, -6)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetHeight(2)
    track:SetPoint("LEFT"); track:SetPoint("RIGHT")
    track:SetColorTexture(0.19, 0.20, 0.23, 1)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 10)
    thumb:SetColorTexture(unpack(C.text))
    s:SetThumbTexture(thumb)
    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(2)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")
    fill:SetColorTexture(unpack(C.accent))
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    if s.SetObeyStepsOnDrag then s:SetObeyStepsOnDrag(true) end
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        value:SetText(show(v))
        if get() ~= v then set(v) end
    end)
    function s.Refresh()
        s:SetValue(get())
        value:SetText(show(get()))
    end
    s:Refresh()
    return s
end

-- A card: panel with a small uppercase title and a short light blue mark
function T.Card(parent, title, x, y, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", x, y)
    f:SetSize(w, h)
    Fill(f, C.card)
    Border(f, C.line)
    local mark = f:CreateTexture(nil, "ARTWORK")
    mark:SetSize(2, 10)
    mark:SetPoint("TOPLEFT", 12, -11)
    mark:SetColorTexture(unpack(C.accent))
    local t = T.Caption(f, title)
    t:SetPoint("TOPLEFT", 20, -10)
    f.caption, f.mark = t, mark
    return f
end

-- A row of buttons, one of them chosen (light blue): choices = { {key, label}, ... }
function T.Choice(parent, text, x, y, choices, get, set, width)
    local title = Text(parent, text, 13)
    title:SetPoint("TOPLEFT", x, y)
    local row = {}
    local w = width or 90
    for i, c in ipairs(choices) do
        local b = FlatButton(parent, c[2], w, 22)
        b:SetPoint("TOPLEFT", x + (i - 1) * (w + 6), y - 20)
        b.key = c[1]
        b:SetScript("OnClick", function()
            set(c[1])
            row.Refresh()
        end)
        row[#row + 1] = b
    end
    function row.Refresh()
        local cur = get()
        for _, b in ipairs(row) do b:SetPrimary(b.key == cur) end
    end
    row.Refresh()
    return row
end
