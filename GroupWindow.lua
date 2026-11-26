-- Syncline: the group window (/sl, left-click on the minimap button).
-- The group's guide and the leader's step, who is in which guide at which
-- step, and the buttons: leader skips a step for everyone, pulls everyone to
-- his step, sends the guide; members fetch the guide, suggest one, ask for a
-- skip.

local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local C = T.C
local W = {}
ns.GroupWindow = W

local W_WIDTH, PAD, ROW_H, MAX_ROWS = 400, 12, 22, 10
local GUIDE_H = 84
local frame, guideCard, guideText, stepText, membersCard, moreText, emptyText
local rows = {}
local buttons = {}

local DOT = {
    same = C.good, other = C.bad, unknown = C.faint, old = C.warn, newer = C.warn,
}

local function Row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Frame", nil, membersCard)
    r:SetSize(W_WIDTH - 2 * PAD - 2, ROW_H)
    r:SetPoint("TOPLEFT", 1, -32 - (i - 1) * ROW_H)
    if i % 2 == 0 then
        local bg = T.Fill(r, C.cardHi, "BACKGROUND", -7)
        bg:SetAlpha(0.6)
    end
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(6, 6)
    r.dot:SetPoint("LEFT", 14, 0)
    r.name = T.Text(r, "", 13, C.text, true)
    r.name:SetPoint("LEFT", r.dot, "RIGHT", 9, 0)
    r.name:SetWidth(120)
    r.name:SetWordWrap(false)
    r.step = T.Text(r, "", 12, C.text, true)
    r.step:SetPoint("LEFT", 150, 0)
    r.step:SetWidth(95)
    r.step:SetWordWrap(false)
    r.state = T.Text(r, "", 12, C.muted, true)
    r.state:SetPoint("LEFT", 250, 0)
    r.state:SetPoint("RIGHT", -10, 0)
    r.state:SetWordWrap(false)
    rows[i] = r
    return r
end

local function Button(key, text, tip, onClick, primary)
    local b = T.FlatButton(frame, text, 110, 24)
    b:SetPrimary(primary)
    b:SetScript("OnClick", onClick)
    T.Tooltip(b, text, tip)
    buttons[key] = b
    return b
end

local function Build()
    frame = T.Window("SynclineGroupFrame", "Group", W_WIDTH, 300, "groupPos")
    frame:RestorePosition("CENTER", 0, 120)

    -- settings cog next to the close cross
    local cog = CreateFrame("Button", nil, frame.head)
    cog:SetSize(28, 28)
    cog:SetPoint("RIGHT", frame.close, "LEFT", 2, 0)
    local icon = cog:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
    cog:SetScript("OnEnter", function(self)
        icon:SetVertexColor(C.text[1], C.text[2], C.text[3])
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Settings"])
        GameTooltip:Show()
    end)
    cog:SetScript("OnLeave", function()
        icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
        GameTooltip:Hide()
    end)
    cog:SetScript("OnClick", function() ns.Options:Toggle() end)

    local cw = W_WIDTH - 2 * PAD
    guideCard = T.Card(frame, "Group guide", PAD, -40, cw, GUIDE_H)
    guideText = T.Text(guideCard, "", 15, C.accent, true)
    guideText:SetPoint("TOPLEFT", 20, -32)
    guideText:SetPoint("RIGHT", -12, 0)
    guideText:SetWordWrap(false)
    stepText = T.Text(guideCard, "", 12, C.muted, true)
    stepText:SetPoint("TOPLEFT", 20, -56)
    stepText:SetPoint("RIGHT", -12, 0)
    stepText:SetWordWrap(false)

    membersCard = T.Card(frame, "Who is in which guide", PAD, -40 - GUIDE_H - 8, cw, 100)
    emptyText = T.Text(membersCard, "", 12, C.muted, true)
    emptyText:SetPoint("TOPLEFT", 20, -34)
    emptyText:SetPoint("RIGHT", -12, 0)
    emptyText:SetWordWrap(true)
    moreText = T.Text(membersCard, "", 11, C.faint, true)
    moreText:SetPoint("BOTTOMLEFT", 20, 8)

    -- leader
    Button("skip", "Skip step", "Skips the leader's current step for everyone who is at it.",
        function() ns.Actions.SkipForGroup() end, true)
    Button("pull", "Pull to my step", "Everyone in the group guide jumps to your step.",
        function() ns.Actions.PullToMyStep() end, false)
    Button("send", "Send guide", "Sends your guide to the whole group once more, e.g. when someone switched away.",
        function() ns.Actions.Send() end, false)
    -- members
    Button("get", "Get guide", "Loads the guide the group leader has picked.",
        function() ns.Actions.Get() end, true)
    Button("suggest", "Suggest guide", "Suggests the guide you have loaded right now to the group leader. They decide whether the group takes it.",
        function() ns.Actions.Suggest() end, false)
    Button("request", "Request skip", "Asks the leader to skip your current step for the whole group.",
        function() ns.Actions.RequestSkip() end, false)

    local hint = T.Text(frame, "", 11, C.faint, true)
    hint:SetText("/sl  ·  /sl " .. L.CMD_HELP .. "  ·  v" .. tostring(ns.VERSION))
    hint:SetPoint("BOTTOMLEFT", PAD + 2, 12)
    frame.hint = hint

    frame:SetScript("OnShow", function() W:Refresh() end)
    W:ApplySettings()
end

function W:Refresh()
    if not frame or not frame:IsShown() then return end
    local snap = ns.Snapshot()

    if snap.inGroup then
        guideText:SetText(snap.target or ("|cff9aa0aa" .. L["none yet"] .. "|r"))
        if snap.leaderStep then
            local total = 0
            for _, m in ipairs(snap.members) do if m.lead then total = m.total or 0 end end
            local line = L["Leader's step"] .. ": |cffffffff" .. snap.leaderStep .. "/" .. total .. "|r"
            if snap.leaderStepText then line = line .. "  ·  " .. snap.leaderStepText end
            stepText:SetText(line)
        else
            stepText:SetText("")
        end
    else
        guideText:SetText(snap.mine or ("|cff9aa0aa" .. L["no guide loaded"] .. "|r"))
        stepText:SetText(snap.myStep and (L.STEP_OF:format(snap.myStep, snap.myTotal or 0)
            .. (ns.StepText(snap.myStep) and ("  ·  " .. ns.StepText(snap.myStep)) or "")) or "")
    end

    local shown = math.min(#snap.members, MAX_ROWS)
    for i = 1, shown do
        local m, r = snap.members[i], Row(i)
        local c = DOT[m.state] or C.faint
        r.dot:SetColorTexture(c[1], c[2], c[3], 1)
        local name = m.name:gsub("%-.*", "")
        local lead = m.lead and ("  |cff" .. T.Hex(C.faint) .. L.STATUS_LEADER .. "|r") or ""
        r.name:SetText("|cff" .. T.ClassHex(m.class) .. name .. "|r" .. lead)
        r.state:SetText(ns.STATE_TEXT[m.state](m))
        local step = ""
        if m.step then
            step = m.step .. "/" .. (m.total or "?")
            if m.diff == 0 then
                step = step .. "  |cff" .. T.Hex(C.good) .. "=|r"
            elseif m.diff and m.diff < 0 then
                step = step .. "  |cff" .. T.Hex(C.warn) .. m.diff .. "|r"
            elseif m.diff then
                step = step .. "  |cff" .. T.Hex(C.accent) .. "+" .. m.diff .. "|r"
            end
        end
        r.step:SetText(step)
        r:Show()
    end
    for i = shown + 1, #rows do rows[i]:Hide() end
    local more = #snap.members - shown
    moreText:SetText(more > 0 and L["and %d more, /sl status lists everyone"]:format(more) or "")

    if not snap.inGroup then
        emptyText:SetText(L["You're not in a group. As soon as you are, the leader's guide is synced here."])
        emptyText:Show()
    else
        emptyText:Hide()
    end
    local listH = snap.inGroup and (32 + shown * ROW_H + (more > 0 and 26 or 10)) or 74
    membersCard:SetHeight(listH)

    -- buttons: the leader skips, pulls and sends, members fetch, suggest, ask for a skip
    local top = 40 + GUIDE_H + 8
    local y = -top - listH - 10
    for _, b in pairs(buttons) do b:Hide() end
    local row
    if snap.inGroup and snap.isLeader then
        row = { buttons.skip, buttons.pull, buttons.send }
    elseif snap.inGroup then
        row = { buttons.get, buttons.suggest, buttons.request }
    end
    if row then
        local w = (W_WIDTH - 2 * PAD - 12) / 3
        for i, b in ipairs(row) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", PAD + (i - 1) * (w + 6), y)
            b:SetWidth(w)
            b:Show()
        end
    end
    local buttonsH = row and 34 or 0
    frame:SetHeight(top + listH + 10 + buttonsH + 30)
end

function W:ApplySettings(resetPosition)
    if not frame then return end
    frame:ApplyScale("windowScale")
    if resetPosition then frame:RestorePosition("CENTER", 0, 120) end
end

function W:Toggle()
    if not frame then Build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function W:IsShown() return frame and frame:IsShown() end
