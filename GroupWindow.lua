-- Syncline: the group window (/sl, left-click on the minimap button).
-- On top the group's guide with a progress bar that shows where everyone
-- is, below it the group (a short overview or the full list) and the helper
-- cards, at the bottom the buttons.
--
-- What the window shows is a view, chosen separately for the leader and for
-- members: Full, Quests, Compact or Custom (any mix of sections). The view
-- menu sits in the window's header; a click on a card's title folds it.

local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local C = T.C
local W = {}
ns.GroupWindow = W

local W_WIDTH, PAD, ROW_H, MAX_ROWS = 400, 12, 22, 10
local CW = W_WIDTH - 2 * PAD
local BAR_W = CW - 40 - 44
local MARKS = 10
local frame, guideCard, guideText, roleText, bar, barFill, pctText, stepText, riskText, blockText
local summaryCard, chipsText, issueTexts
local membersCard, moreText, emptyText, viewBtn, menu
local rows, marks = {}, {}
local buttons = {}

---------------------------------------------------------------------------
-- Views
---------------------------------------------------------------------------
-- the sections in window order (the guide card and the buttons always show)
W.SECTIONS = { "summary", "members", "progress", "travel", "missing", "share", "xp", "slack" }
local MODULE = { progress = "Progress", travel = "Travel", missing = "Missing", share = "Share", xp = "XP", slack = "Slack" }
local SECTION_LABEL = {
    summary = "Group at a glance", members = "Member list", progress = "Quest progress",
    travel = "Hearthstone and flight paths", missing = "Missing quests", share = "Share quests",
    xp = "Experience", slack = "Slack meter",
}
local PRESETS = {
    full    = { members = true, progress = true, travel = true, missing = true, share = true, xp = true, slack = true },
    quests  = { summary = true, progress = true, travel = true, missing = true, share = true },
    compact = { summary = true, progress = true, travel = true, missing = true },
}
W.VIEWS = { { "full", "Full" }, { "quests", "Quests" }, { "compact", "Compact" }, { "custom", "Custom" } }
local VIEW_LABEL = { full = "Full", quests = "Quests", compact = "Compact", custom = "Custom" }
local ROLE_DEFAULT = { Leader = "full", Member = "compact" }

local function Role(snap)
    return (snap and snap.inGroup and snap.isLeader) and "Leader" or "Member"
end

function W:Role() return W.role or Role(ns.Snapshot()) end

function W:View(role)
    local v = ns.db and ns.db["view" .. role]
    if v == "custom" or PRESETS[v] then return v end
    return ROLE_DEFAULT[role]
end

function W:Shows(key, role)
    role = role or W:Role()
    local v = W:View(role)
    if v == "custom" then
        local c = ns.db["custom" .. role]
        if type(c) == "table" then return c[key] and true or false end
        v = ROLE_DEFAULT[role]
    end
    return PRESETS[v][key] and true or false
end

function W:SetView(role, v)
    ns.db["view" .. role] = v
    if v == "custom" and type(ns.db["custom" .. role]) ~= "table" then
        local c = {}
        for _, k in ipairs(W.SECTIONS) do c[k] = PRESETS[ROLE_DEFAULT[role]][k] and true or false end
        ns.db["custom" .. role] = c
    end
    W:Refresh()
end

-- switching one section on or off makes the view custom, starting from what it showed
function W:SetSection(role, key, on)
    if W:View(role) ~= "custom" then
        local c = {}
        for _, k in ipairs(W.SECTIONS) do c[k] = W:Shows(k, role) end
        ns.db["custom" .. role] = c
        ns.db["view" .. role] = "custom"
    end
    ns.db["custom" .. role][key] = on and true or false
    W:Refresh()
end

local function Folded()
    if type(ns.db.folded) ~= "table" then ns.db.folded = {} end
    return ns.db.folded
end

function W:IsFolded(key) return Folded()[key] and true or false end
function W:Fold(key, on)
    Folded()[key] = on and true or nil
    W:Refresh()
end

-- a click on the card's title folds it to the title bar
local function Foldable(card, key)
    if card.SetClipsChildren then card:SetClipsChildren(true) end
    local hit = CreateFrame("Button", nil, card)
    hit:SetPoint("TOPLEFT", 0, 0)
    hit:SetPoint("TOPRIGHT", -160, 0)   -- leave the header buttons of some cards free
    hit:SetHeight(28)
    local sign = T.Text(card, "", 12, C.faint, true)
    if card.caption then sign:SetPoint("LEFT", card.caption, "RIGHT", 6, 0) else sign:SetPoint("TOPLEFT", 120, -9) end
    card.sign = sign
    hit:SetScript("OnClick", function() W:Fold(key, not W:IsFolded(key)) end)
    hit:SetScript("OnEnter", function(self)
        sign:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L[W:IsFolded(key) and "Click to unfold" or "Click to fold"])
        GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function()
        sign:SetTextColor(C.faint[1], C.faint[2], C.faint[3])
        GameTooltip:Hide()
    end)
    card.foldKey = key
end

-- height of a shown card, folded or not
local function Folding(card, h)
    if not card or h <= 0 then return h end
    if card.foldKey and W:IsFolded(card.foldKey) then
        card:SetHeight(28)
        if card.sign then card.sign:SetText("+") end
        return 28
    end
    if card.sign then card.sign:SetText("–") end
    return h
end

---------------------------------------------------------------------------
-- Member list
---------------------------------------------------------------------------
local DOT = {
    same = C.good, other = C.bad, unknown = C.faint, old = C.warn, newer = C.warn,
}

local function Row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Frame", nil, membersCard)
    r:SetSize(CW - 2, ROW_H)
    r:SetPoint("TOPLEFT", 1, -46 - (i - 1) * ROW_H)
    r.bg = T.Fill(r, C.cardHi, "BACKGROUND", -7)
    r.stripe = r:CreateTexture(nil, "ARTWORK")
    r.stripe:SetSize(2, ROW_H - 6)
    r.stripe:SetPoint("LEFT", 0, 0)
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(6, 6)
    r.dot:SetPoint("LEFT", 14, 0)
    r.name = T.Text(r, "", 13, C.text, true)
    r.name:SetPoint("LEFT", r.dot, "RIGHT", 9, 0)
    r.name:SetWidth(108)
    r.name:SetWordWrap(false)
    r.crown = r:CreateTexture(nil, "OVERLAY")
    r.crown:SetSize(12, 12)
    r.crown:SetPoint("LEFT", 134, 0)
    r.crown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    r.step = T.Text(r, "", 12, C.text, true)
    r.step:SetPoint("LEFT", 150, 0)
    r.step:SetWidth(95)
    r.step:SetWordWrap(false)
    r.state = T.Text(r, "", 12, C.muted, true)
    r.state:SetPoint("LEFT", 250, 0)
    r.state:SetPoint("RIGHT", -10, 0)
    r.state:SetWordWrap(false)
    -- hover: why the step hangs, which route settings differ
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        local hasDiff = self.diff and #self.diff > 0
        if not hasDiff and not self.block then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.block then
            GameTooltip:AddLine(L["Why the step can't be done yet"])
            GameTooltip:AddLine(self.block, C.warn[1], C.warn[2], C.warn[3], true)
        end
        if hasDiff then
            if self.block then GameTooltip:AddLine(" ") end
            GameTooltip:AddLine(L["RestedXP route settings"])
            GameTooltip:AddLine(L["Different from the leader:"], C.muted[1], C.muted[2], C.muted[3])
            for _, d in ipairs(self.diff) do GameTooltip:AddLine("  " .. d, C.warn[1], C.warn[2], C.warn[3]) end
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
    return r
end

local function Hexed(c, text) return "|cff" .. T.Hex(c) .. text .. "|r" end
local function Short(name) return (tostring(name or ""):gsub("%-.*", "")) end

local function BlockText(m)
    if not (m.blocker and ns.Blockers) then return nil end
    return m.me and ns.Blockers:Text(m.blocker) or ns.Blockers:TextFor(m.blocker)
end

local function LayoutMembers(y, snap)
    local shown = math.min(#snap.members, MAX_ROWS)
    for i = 1, shown do
        local m, r = snap.members[i], Row(i)
        local c = DOT[m.state] or C.faint
        r.dot:SetColorTexture(c[1], c[2], c[3], 1)
        local cc = RAID_CLASS_COLORS and m.class and RAID_CLASS_COLORS[m.class]
        if cc then r.stripe:SetColorTexture(cc.r, cc.g, cc.b, 0.9) else r.stripe:SetColorTexture(C.faint[1], C.faint[2], C.faint[3], 0.6) end
        if m.me then
            r.bg:SetColorTexture(C.accentDim[1], C.accentDim[2], C.accentDim[3], 0.35)
        else
            r.bg:SetColorTexture(C.cardHi[1], C.cardHi[2], C.cardHi[3], i % 2 == 0 and 0.6 or 0)
        end
        local nameText = "|cff" .. T.ClassHex(m.class) .. Short(m.name) .. "|r"
        if m.connected == false then nameText = Hexed(C.faint, Short(m.name) .. " (" .. L["offline"] .. ")") end
        r.name:SetText(nameText)
        r.crown:SetShown(m.lead)
        r.block = BlockText(m) or false
        r.diff = m.routeDiff or false
        -- another guide matters more than a stuck step, that more than other settings
        if m.state == "same" and r.block then
            r.state:SetText(Hexed(C.warn, L["stuck"] .. ": " .. r.block))
        elseif m.state == "same" and m.routeDiff and #m.routeDiff > 0 then
            r.state:SetText(Hexed(C.warn, L["settings differ"]))
        else
            r.state:SetText(ns.STATE_TEXT[m.state](m))
        end
        local step = ""
        if m.step then
            step = m.step .. "/" .. (m.total or "?")
            if m.diff == 0 then
                step = step .. "  " .. Hexed(C.good, "=")
            elseif m.diff and m.diff < 0 then
                step = step .. "  " .. Hexed(C.warn, tostring(m.diff))
            elseif m.diff then
                step = step .. "  " .. Hexed(C.accent, "+" .. m.diff)
            end
        end
        r.step:SetText(step)
        r:Show()
    end
    for i = shown + 1, #rows do rows[i]:Hide() end
    local more = #snap.members - shown
    moreText:SetText(more > 0 and L["and %d more, /sl status lists everyone"]:format(more) or "")
    membersCard:ClearAllPoints()
    membersCard:SetPoint("TOPLEFT", PAD, y)
    membersCard:Show()
    local h = 46 + shown * ROW_H + (more > 0 and 26 or 10)
    membersCard:SetHeight(h)
    return h
end

---------------------------------------------------------------------------
-- Group at a glance: a dot per member, and only what needs attention.
-- The leader sees everyone's problems, a member only their own.
---------------------------------------------------------------------------
local MAX_ISSUES = 4

local function Issue(m, mine)
    local who = mine and "" or ("|cff" .. T.ClassHex(m.class) .. Short(m.name) .. "|r: ")
    if m.connected == false then return nil end
    if m.state == "other" then
        return who .. Hexed(C.bad, mine and L["You're in another guide – Get guide brings you back"]
            or L.STATUS_OTHER:format(m.guide or "-")), 1
    elseif m.state == "unknown" then
        return who .. Hexed(C.faint, L.STATUS_UNKNOWN), 4
    elseif m.state == "old" or m.state == "newer" then
        return who .. Hexed(C.warn, L["STATUS_" .. m.state:upper()]), 3
    end
    local block = BlockText(m)
    if block then return who .. Hexed(C.warn, L["stuck"] .. ": " .. block), 2 end
    if m.diff and m.diff < 0 and not m.lead then
        local n = -m.diff
        return who .. Hexed(C.warn, (mine and L["you're %d step(s) behind the leader"] or L["%d step(s) behind"]):format(n)), 2
    end
    if m.routeDiff and #m.routeDiff > 0 then return who .. Hexed(C.warn, L["settings differ"]), 3 end
end

function W:Issues(snap)
    local list, leader = {}, Role(snap) == "Leader"
    for _, m in ipairs(snap.members) do
        if leader and not m.me or not leader and m.me then
            local text, rank = Issue(m, not leader)
            if text then list[#list + 1] = { text = text, rank = rank } end
        end
    end
    table.sort(list, function(a, b) return a.rank < b.rank end)
    return list
end

local function LayoutSummary(y, snap)
    local chips = {}
    local together = 0
    for _, m in ipairs(snap.members) do
        local c = DOT[m.state] or C.faint
        if m.connected == false then c = C.faint end
        if m.state == "same" then together = together + 1 end
        chips[#chips + 1] = Hexed(c, "•") .. " |cff" .. T.ClassHex(m.class) .. Short(m.name) .. "|r"
            .. (m.lead and " |TInterface\\GroupFrame\\UI-Group-LeaderIcon:11|t" or "")
    end
    chipsText:SetText(table.concat(chips, "   ") .. "   " .. Hexed(C.faint, together .. "/" .. #snap.members .. " " .. L["in the guide"]))
    local issues = W:Issues(snap)
    local n = 0
    if #issues == 0 then
        n = 1
        local ok = Role(snap) == "Leader" and L["Everyone is in the guide and with you"] or L["You're with the group"]
        issueTexts[1]:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " .. Hexed(C.good, ok))
        issueTexts[1]:Show()
    else
        for i = 1, math.min(#issues, MAX_ISSUES) do
            n = i
            issueTexts[i]:SetText(issues[i].text)
            issueTexts[i]:Show()
        end
        if #issues > MAX_ISSUES then
            n = n + 1
            issueTexts[n]:SetText(Hexed(C.faint, L["and %d more"]:format(#issues - MAX_ISSUES)))
            issueTexts[n]:Show()
        end
    end
    for i = n + 1, #issueTexts do issueTexts[i]:Hide() end
    local chipLines = math.max(1, math.ceil(#snap.members / 5))
    local top = 30 + chipLines * 16 + 6
    for i = 1, n do
        issueTexts[i]:ClearAllPoints()
        issueTexts[i]:SetPoint("TOPLEFT", 20, -top - (i - 1) * 18)
        issueTexts[i]:SetPoint("RIGHT", -12, 0)
    end
    summaryCard:ClearAllPoints()
    summaryCard:SetPoint("TOPLEFT", PAD, y)
    summaryCard:Show()
    local h = top + n * 18 + 8
    summaryCard:SetHeight(h)
    return h
end

---------------------------------------------------------------------------
-- The guide card: name, a progress bar with everyone's place on it, the step
---------------------------------------------------------------------------
local function Pos(m, snap)
    if m.lead then return snap.leaderStep end
    if m.diff and snap.leaderStep then return snap.leaderStep + m.diff end
    if m.total and snap.leaderTotal and m.total == snap.leaderTotal then return m.step end
end

local function LayoutGuide(snap)
    local step, total
    if snap.inGroup then
        guideText:SetText(snap.target or Hexed(C.muted, L["none yet"]))
        step, total = snap.leaderStep, snap.leaderTotal
        roleText:SetText(T.Upper(L[snap.isLeader and "You lead" or "Member"]))
    else
        guideText:SetText(snap.mine or Hexed(C.muted, L["no guide loaded"]))
        step, total = snap.myStep, snap.myTotal
        roleText:SetText(T.Upper(L["Solo"]))
    end

    -- the bar, and a mark for everyone in the group guide
    local y = -54
    W.barMembers = {}
    if step and total and total > 0 then
        bar:Show()
        local f = math.max(0, math.min(1, step / total))
        barFill:SetWidth(math.max(1, BAR_W * f))
        pctText:SetText(("%d %%"):format(math.floor(f * 100 + 0.5)))
        local n = 0
        for _, m in ipairs(snap.inGroup and snap.members or {}) do
            local p = m.state == "same" and Pos(m, snap)
            if p and n < MARKS then
                n = n + 1
                local mk = marks[n]
                local cc = RAID_CLASS_COLORS and m.class and RAID_CLASS_COLORS[m.class]
                if m.lead then mk:SetColorTexture(1, 1, 1, 1)
                elseif cc then mk:SetColorTexture(cc.r, cc.g, cc.b, 1)
                else mk:SetColorTexture(C.text[1], C.text[2], C.text[3], 1) end
                mk:SetSize(m.lead and 3 or 2, m.lead and 14 or 10)
                mk:ClearAllPoints()
                mk:SetPoint("CENTER", bar, "LEFT", BAR_W * math.max(0, math.min(1, p / total)), 0)
                mk:Show()
                W.barMembers[#W.barMembers + 1] = { name = Short(m.name), class = m.class, step = p, total = total, lead = m.lead }
            end
        end
        for i = n + 1, MARKS do marks[i]:Hide() end
        y = -70
    else
        bar:Hide()
        pctText:SetText("")
    end

    -- the text lines, only the ones with something in them
    local lines = {}
    if snap.inGroup then
        if snap.leaderStep then
            local line = L["Leader's step"] .. ": |cffffffff" .. snap.leaderStep .. "/" .. (snap.leaderTotal or 0) .. "|r"
            if snap.leaderStepText then line = line .. "  ·  " .. snap.leaderStepText end
            lines[#lines + 1] = { stepText, line }
            local risk = ns.RiskText(snap.leaderRisk)
            if risk and risk ~= "" then lines[#lines + 1] = { riskText, risk } end
        end
    elseif snap.myStep then
        lines[#lines + 1] = { stepText, L.STEP_OF:format(snap.myStep, snap.myTotal or 0)
            .. (ns.StepText(snap.myStep) and ("  ·  " .. ns.StepText(snap.myStep)) or "") }
        local risk = ns.RiskText(ns.SkipRisk(snap.myStep))
        if risk and risk ~= "" then lines[#lines + 1] = { riskText, risk } end
    end
    -- why my own step hangs
    local myBlock = ns.Blockers and ns.db.showBlockers and ns.Blockers:Mine()[1]
    if myBlock then lines[#lines + 1] = { blockText, L["You"] .. ": " .. ns.Blockers:Text(myBlock) } end

    for _, fs in ipairs({ stepText, riskText, blockText }) do fs:SetText(""); fs:Hide() end
    for i, l in ipairs(lines) do
        l[1]:ClearAllPoints()
        l[1]:SetPoint("TOPLEFT", 20, y - 4 - (i - 1) * 18)
        l[1]:SetPoint("RIGHT", -12, 0)
        l[1]:SetText(l[2])
        l[1]:Show()
    end
    local h = -y + 4 + #lines * 18 + 10
    guideCard:SetHeight(h)
    return h
end

---------------------------------------------------------------------------
-- View menu (the button in the header)
---------------------------------------------------------------------------
local function BuildMenu()
    menu = CreateFrame("Frame", nil, frame)
    menu:SetFrameStrata("DIALOG")
    menu:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -32)
    T.Fill(menu, C.head)
    T.Border(menu, C.edge)
    menu:EnableMouse(true)
    local MW = 236
    menu.title = T.Caption(menu, "View")
    menu.title:SetPoint("TOPLEFT", 14, -12)
    menu.views = {}
    for i, v in ipairs(W.VIEWS) do
        local b = T.FlatButton(menu, v[2], (MW - 34) / 2, 22)
        b:SetPoint("TOPLEFT", 14 + ((i - 1) % 2) * ((MW - 34) / 2 + 6), -30 - math.floor((i - 1) / 2) * 28)
        b.key = v[1]
        b:SetScript("OnClick", function() W:SetView(W:Role(), v[1]) end)
        menu.views[i] = b
    end
    local sec = T.Caption(menu, "Sections")
    sec:SetPoint("TOPLEFT", 14, -94)
    menu.switches = {}
    local y = -114
    for _, key in ipairs(W.SECTIONS) do
        local sw = T.Switch(menu, SECTION_LABEL[key], 14, y,
            function() return W:Shows(key) end,
            function(v) W:SetSection(W:Role(), key, v) end)
        sw.key = key
        menu.switches[#menu.switches + 1] = sw
        y = y - 24
    end
    local note = T.Text(menu, "Click a card's title to fold it.", 11, C.faint)
    note:SetPoint("TOPLEFT", 14, y - 6)
    note:SetPoint("RIGHT", -12, 0)
    menu:SetSize(MW, -y + 32)
    menu:Hide()
end

function W:RefreshMenu()
    if not menu then return end
    local role = W:Role()
    menu.title:SetText(T.Upper(L[role == "Leader" and "View as leader" or "View as member"]))
    local cur = W:View(role)
    for _, b in ipairs(menu.views) do b:SetPrimary(b.key == cur) end
    for _, sw in ipairs(menu.switches) do sw:Refresh() end
end

function W:ToggleMenu()
    if not frame then return end
    if not menu then BuildMenu() end
    if menu:IsShown() then menu:Hide() else menu:Show(); W:RefreshMenu() end
end

---------------------------------------------------------------------------
-- Building the window
---------------------------------------------------------------------------
local function Button(key, text, tip, onClick, primary)
    local b = T.FlatButton(frame, text, 110, 24)
    b:SetPrimary(primary)
    b:SetScript("OnClick", onClick)
    T.Tooltip(b, text, tip)
    buttons[key] = b
    return b
end

local function HeadIcon(anchor, texture, tip, onClick)
    local b = CreateFrame("Button", nil, frame.head)
    b:SetSize(28, 28)
    b:SetPoint("RIGHT", anchor, "LEFT", 2, 0)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("CENTER")
    icon:SetTexture(texture)
    icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
    b:SetScript("OnEnter", function(self)
        icon:SetVertexColor(C.text[1], C.text[2], C.text[3])
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L[tip])
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", onClick)
    return b
end

local function Build()
    frame = T.Window("SynclineGroupFrame", "Group", W_WIDTH, 300, "groupPos")
    frame:RestorePosition("CENTER", 0, 120)

    local cog = HeadIcon(frame.close, "Interface\\Buttons\\UI-OptionsButton", "Settings", function() ns.Options:Toggle() end)
    -- the view menu: "View: Full"
    viewBtn = T.FlatButton(frame.head, "", 124, 20)
    viewBtn:SetPoint("RIGHT", cog, "LEFT", -2, 0)
    viewBtn:SetScript("OnClick", function() W:ToggleMenu() end)
    T.Tooltip(viewBtn, "View", "What the window shows: Full, Quests, Compact, or your own mix. Set separately for leading and for being a member.")

    -- guide card
    guideCard = T.Card(frame, "Group guide", PAD, -40, CW, 120)
    roleText = T.Text(guideCard, "", 10, C.faint, true)
    roleText:SetPoint("TOPRIGHT", -12, -10)
    roleText:SetJustifyH("RIGHT")
    guideText = T.Text(guideCard, "", 16, C.accent, true)
    guideText:SetPoint("TOPLEFT", 20, -30)
    guideText:SetPoint("RIGHT", -12, 0)
    guideText:SetWordWrap(false)
    bar = CreateFrame("Frame", nil, guideCard)
    bar:SetSize(BAR_W, 6)
    bar:SetPoint("TOPLEFT", 20, -58)
    T.Fill(bar, C.line)
    barFill = bar:CreateTexture(nil, "ARTWORK")
    barFill:SetPoint("TOPLEFT"); barFill:SetPoint("BOTTOMLEFT")
    barFill:SetWidth(1)
    barFill:SetColorTexture(C.accentDim[1], C.accentDim[2], C.accentDim[3], 1)
    for i = 1, MARKS do
        marks[i] = bar:CreateTexture(nil, "OVERLAY")
        marks[i]:Hide()
    end
    pctText = T.Text(guideCard, "", 11, C.muted, true)
    pctText:SetPoint("LEFT", bar, "RIGHT", 8, 0)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self)
        if not W.barMembers or #W.barMembers == 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["Where everyone is"])
        local list = {}
        for _, e in ipairs(W.barMembers) do list[#list + 1] = e end
        table.sort(list, function(a, b) return a.step > b.step end)
        for _, e in ipairs(list) do
            GameTooltip:AddDoubleLine("|cff" .. T.ClassHex(e.class) .. e.name .. "|r" .. (e.lead and (" (" .. L.STATUS_LEADER .. ")") or ""),
                L.STEP_OF:format(e.step, e.total), 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    stepText = T.Text(guideCard, "", 12, C.muted, true)
    stepText:SetWordWrap(false)
    riskText = T.Text(guideCard, "", 12, C.muted, true)
    riskText:SetWordWrap(false)
    blockText = T.Text(guideCard, "", 12, C.warn, true)
    blockText:SetWordWrap(false)

    -- group at a glance
    summaryCard = T.Card(frame, "Group at a glance", PAD, 0, CW, 60)
    chipsText = T.Text(summaryCard, "", 12, C.text, true)
    chipsText:SetPoint("TOPLEFT", 20, -30)
    chipsText:SetPoint("RIGHT", -12, 0)
    chipsText:SetWordWrap(true)
    issueTexts = {}
    for i = 1, MAX_ISSUES + 1 do
        issueTexts[i] = T.Text(summaryCard, "", 12, C.text, true)
        issueTexts[i]:SetWordWrap(false)
    end
    Foldable(summaryCard, "summary")

    -- full member list
    membersCard = T.Card(frame, "Who is in which guide", PAD, 0, CW, 100)
    for _, col in ipairs({ { "Name", 14 }, { "Step", 150 }, { "Status", 250 } }) do
        local h = T.Caption(membersCard, col[1])
        h:SetTextColor(C.faint[1], C.faint[2], C.faint[3])
        h:SetPoint("TOPLEFT", col[2] + 1, -30)
    end
    moreText = T.Text(membersCard, "", 11, C.faint, true)
    moreText:SetPoint("BOTTOMLEFT", 20, 8)
    Foldable(membersCard, "members")

    emptyText = T.Text(guideCard, "", 12, C.muted, true)
    emptyText:SetWordWrap(true)

    -- leader
    Button("skip", "Skip step", "Skips the leader's current step for everyone who is at it.",
        function() ns.Actions.SkipForGroup() end, true)
    -- skip check in the tooltip
    buttons.skip:HookScript("OnEnter", function(self)
        local snap = ns.Snapshot()
        if not snap.leaderRisk then return end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Skip check"], C.muted[1], C.muted[2], C.muted[3])
        for _, line in ipairs(ns.RiskLines(snap.leaderRisk)) do GameTooltip:AddLine(line, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
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

    -- the helper cards; each hides itself when it has nothing
    W.cards = {}
    for _, key in ipairs(W.SECTIONS) do
        local mod = MODULE[key] and ns[MODULE[key]]
        if mod then
            local card = mod:Attach(frame, PAD, CW)
            if card then Foldable(card, key) end
            W.cards[#W.cards + 1] = { key = key, mod = mod, card = card }
        end
    end

    local hint = T.Text(frame, "", 11, C.faint, true)
    hint:SetText("/sl  ·  /sl " .. L.CMD_HELP .. "  ·  v" .. tostring(ns.VERSION))
    hint:SetPoint("BOTTOMLEFT", PAD + 2, 12)
    frame.hint = hint

    W.frames = { guide = guideCard, summary = summaryCard, members = membersCard }
    W.buttons = buttons
    frame:SetScript("OnShow", function() W:Refresh() end)
    frame:SetScript("OnHide", function() if menu then menu:Hide() end end)
    W:ApplySettings()
end

-- which buttons fit the role and the view: the full view shows all three,
-- the others only what makes sense right now
function W:Buttons(snap)
    if not snap.inGroup then return {} end
    local full = W:View(Role(snap)) == "full"
    if snap.isLeader then
        local row = { "skip", "pull" }
        local strays = false
        for _, m in ipairs(snap.members) do if m.state == "other" then strays = true end end
        if full or strays then row[#row + 1] = "send" end
        return row
    end
    if full then return { "get", "suggest", "request" } end
    if snap.target and not snap.inTarget then return { "get", "suggest" } end
    return { "request" }
end

function W:Refresh()
    if not frame or not frame:IsShown() then return end
    local snap = ns.Snapshot()
    local role = Role(snap)
    W.role = role
    local view = W:View(role)
    viewBtn:SetText(L["View: %s"]:format(L[VIEW_LABEL[view]]))

    local y = -40
    local gh = LayoutGuide(snap)
    if not snap.inGroup then
        emptyText:ClearAllPoints()
        emptyText:SetPoint("TOPLEFT", 20, -gh + 4)
        emptyText:SetPoint("RIGHT", -12, 0)
        emptyText:SetText(L["You're not in a group. As soon as you are, the leader's guide is synced here."])
        emptyText:Show()
        gh = gh + 34
        guideCard:SetHeight(gh)
    else
        emptyText:Hide()
    end
    y = y - gh - 8

    -- the group
    if snap.inGroup and W:Shows("summary", role) then
        y = y - Folding(summaryCard, LayoutSummary(y, snap)) - 8
    else
        summaryCard:Hide()
    end
    if snap.inGroup and W:Shows("members", role) then
        y = y - Folding(membersCard, LayoutMembers(y, snap)) - 8
    else
        membersCard:Hide()
        for i = 1, #rows do rows[i]:Hide() end
    end

    -- helper cards
    for _, c in ipairs(W.cards or {}) do
        if W:Shows(c.key, role) then
            local h = Folding(c.card, c.mod:Layout(y, snap))
            if h > 0 then y = y - h - 8 end
        elseif c.card then
            c.card:Hide()
        end
    end

    -- buttons
    for _, b in pairs(buttons) do b:Hide() end
    local row = W:Buttons(snap)
    if #row > 0 then
        local w = (CW - 6 * (#row - 1)) / #row
        for i, key in ipairs(row) do
            local b = buttons[key]
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", PAD + (i - 1) * (w + 6), y - 2)
            b:SetWidth(w)
            b:Show()
        end
        y = y - 34
    end
    frame:SetHeight(-y + 30)
    if menu and menu:IsShown() then W:RefreshMenu() end
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
