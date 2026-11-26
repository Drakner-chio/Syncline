-- Syncline: the slack meter. Only the leader sees it: who keeps the group
-- waiting. Counted from what the leader knows anyway (each member's step, see
-- Core.lua), nothing extra is sent.
--
-- Waited: time a member is behind the leader's step in the group guide.
-- Paused while the leader is in combat or away (AFK), while the member is
-- offline, and when the leader himself isn't in the group guide.
-- Per step: time in the group guide / steps the member got further.

local ADDON, ns = ...
local L, T = ns.L, ns.Theme
local C = T.C
local S = {}
ns.Slack = S

local TICK = 2              -- seconds between counts
local RESET_AFTER = 60      -- out of a group this long: new session
local SHOW = 5              -- rows in the window

-- titles for the one on top, by minutes waited
local TITLES = {
    { 30, "Snail of the session" },
    { 10, "Tourist" },
    { 2, "Flower picker" },
}

local function Data()
    ns.db.slack = ns.db.slack or { members = {} }
    return ns.db.slack
end

function S:Reset()
    ns.db.slack = { members = {} }
    if ns.GroupWindow then ns.GroupWindow:Refresh() end
end

local outSince

-- one count: called every TICK seconds
function S:Tick(snap)
    snap = snap or ns.Snapshot()
    local now = GetTime and GetTime() or 0
    if not snap.inGroup then
        outSince = outSince or now
        if now - outSince >= RESET_AFTER and next(Data().members) then S:Reset() end
        return
    end
    outSince = nil
    if not snap.isLeader or not ns.db.slackMeter then return end
    if InCombatLockdown() or (UnitIsAFK and UnitIsAFK("player")) then return end
    if not snap.inTarget then return end

    local data = Data()
    for _, m in ipairs(snap.members) do
        if not m.me and m.state == "same" then
            local key = (m.name or "?"):gsub("[%- ].*", "")
            local d = data.members[key] or { waited = 0, time = 0, steps = 0 }
            data.members[key] = d
            d.class = m.class or d.class
            local online = m.connected ~= false
            if online then
                d.time = d.time + TICK
                if m.diff and m.diff < 0 then d.waited = d.waited + TICK end
                if m.step and d.lastStep and m.step > d.lastStep and m.step - d.lastStep < 20 then
                    d.steps = d.steps + (m.step - d.lastStep)
                end
                d.lastStep = m.step or d.lastStep
            end
        end
    end
end

-- sorted: most waited first
function S:Ranking()
    local list = {}
    for name, d in pairs(Data().members) do
        list[#list + 1] = { name = name, class = d.class, waited = d.waited, perStep = d.steps > 0 and d.time / d.steps or nil }
    end
    table.sort(list, function(a, b)
        if a.waited ~= b.waited then return a.waited > b.waited end
        return a.name < b.name
    end)
    return list
end

local function Clock(sec)
    sec = math.floor(sec or 0)
    if sec >= 3600 then return ("%d:%02d:%02d"):format(sec / 3600, (sec % 3600) / 60, sec % 60) end
    return ("%d:%02d"):format(sec / 60, sec % 60)
end
S.Clock = Clock

function S:Title(waited)
    for _, t in ipairs(TITLES) do
        if waited >= t[1] * 60 then return L[t[2]] end
    end
end

-- the ranking as chat lines
function S:ChatLines()
    local list = S:Ranking()
    local out = { L["Syncline slack meter (time the group waited):"] }
    for i = 1, math.min(SHOW, #list) do
        local e = list[i]
        local title = i == 1 and S:Title(e.waited)
        out[#out + 1] = ("%d. %s %s%s"):format(i, e.name, Clock(e.waited), title and (" – " .. title) or "")
    end
    return out
end

function S:Post()
    local list = S:Ranking()
    if #list == 0 then return end
    local channel = IsInRaid() and "RAID" or "PARTY"
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
        and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        channel = "INSTANCE_CHAT"
    end
    for _, line in ipairs(S:ChatLines()) do
        pcall(SendChatMessage, line, channel)
    end
end

---------------------------------------------------------------------------
-- In the group window: a card under the member list
---------------------------------------------------------------------------
local card, rows, empty, postBtn, resetBtn = nil, {}, nil, nil, nil
local ROW_H = 22

function S:Attach(parent, x, width)
    card = T.Card(parent, "Slack meter", x, 0, width, 100)
    empty = T.Text(card, "", 12, C.muted, true)
    empty:SetPoint("TOPLEFT", 20, -34)
    empty:SetPoint("RIGHT", -12, 0)
    empty:SetWordWrap(true)
    empty:SetText(L["Nobody kept the group waiting yet."])

    postBtn = T.FlatButton(card, L["Post"], 64, 20)
    postBtn:SetPoint("TOPRIGHT", -78, -6)
    postBtn:SetScript("OnClick", function() S:Post() end)
    T.Tooltip(postBtn, "Post", "Posts the ranking in the group chat.")
    resetBtn = T.FlatButton(card, L["Reset"], 64, 20)
    resetBtn:SetPoint("TOPRIGHT", -8, -6)
    resetBtn:SetScript("OnClick", function() S:Reset() end)

    for i = 1, SHOW do
        local r = CreateFrame("Frame", nil, card)
        r:SetSize(width - 2, ROW_H)
        r:SetPoint("TOPLEFT", 1, -32 - (i - 1) * ROW_H)
        r.bar = r:CreateTexture(nil, "BACKGROUND")
        r.bar:SetPoint("LEFT", 14, 0)
        r.bar:SetHeight(ROW_H - 6)
        r.name = T.Text(r, "", 13, C.text, true)
        r.name:SetPoint("LEFT", 20, 0)
        r.name:SetWidth(170)
        r.name:SetWordWrap(false)
        r.time = T.Text(r, "", 12, C.text, true)
        r.time:SetPoint("LEFT", 200, 0)
        r.per = T.Text(r, "", 11, C.muted, true)
        r.per:SetPoint("LEFT", 255, 0)
        r.per:SetPoint("RIGHT", -10, 0)
        r.per:SetWordWrap(false)
        rows[i] = r
    end
    return card
end

-- place the card at y; returns its height (0 when hidden)
function S:Layout(y, snap)
    if not card then return 0 end
    if not (snap.inGroup and snap.isLeader and ns.db.slackMeter) then
        card:Hide()
        return 0
    end
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", 12, y)
    card:Show()
    local list = S:Ranking()
    local shown = math.min(SHOW, #list)
    local max = (list[1] and list[1].waited > 0) and list[1].waited or 1
    local width = card:GetWidth() - 30
    for i = 1, SHOW do
        local r, e = rows[i], list[i]
        if e then
            local c = (e.waited > 0) and (i == 1 and C.bad or C.warn) or C.good
            r.bar:SetColorTexture(c[1], c[2], c[3], 0.22)
            r.bar:SetWidth(math.max(2, width * e.waited / max))
            local title = i == 1 and S:Title(e.waited)
            r.name:SetText("|cff" .. T.ClassHex(e.class) .. e.name .. "|r"
                .. (title and ("  |cff" .. T.Hex(C.warn) .. title .. "|r") or ""))
            r.time:SetText(Clock(e.waited))
            r.per:SetText(e.perStep and L["Ø %s/step"]:format(Clock(e.perStep)) or "")
            r:Show()
        else
            r:Hide()
        end
    end
    empty:SetShown(shown == 0)
    postBtn:SetShown(shown > 0)
    local h = shown > 0 and (32 + shown * ROW_H + 10) or 64
    card:SetHeight(h)
    return h
end

function S:Start()
    if S.ticker then return end
    S.ticker = C_Timer.NewTicker(TICK, function()
        local snap = ns.Snapshot()
        S:Tick(snap)
        if ns.GroupWindow and ns.GroupWindow:IsShown() then ns.GroupWindow:Refresh() end
    end)
end
