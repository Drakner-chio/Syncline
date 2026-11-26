-- Syncline tests. Run from the repo root: lua5.1 tests/run.lua
local function check(c, m) if not c then error(m or "check failed", 2) end end
local function logHas(s) for i = #LOG, 1, -1 do if LOG[i]:find(s, 1, true) then return true end end end
local function guide() return RXPCData.currentGuideGroup .. " / " .. RXPCData.currentGuideName end
local ns = {}
assert(loadfile("Locale.lua"))("Syncline", ns)
assert(loadfile("GuideMap.lua"))("Syncline", ns)
assert(loadfile("Theme.lua"))("Syncline", ns)
assert(loadfile("Core.lua"))("Syncline", ns)
assert(loadfile("GroupWindow.lua"))("Syncline", ns)
assert(loadfile("Options.lua"))("Syncline", ns)
local T = ns.test
local D1, D2 = "forever/Horde-01-12_Durotar.lua#1", "forever/Horde-01-12_Durotar.lua#2"
local MAGE = "forever/Horde-Mage-12-21.lua#1"
Fire("ADDON_LOADED", "Syncline"); Fire("PLAYER_LOGIN"); Fire("PLAYER_ENTERING_WORLD", true, false); RunTimers()
check(logHas("geladen"), "loaded message")
-- logo, minimap button, AddOns settings entry
check(SynclineMinimapButton and SynclineMinimapButton:IsShown(), "minimap button")
check(SETTINGS[1] == "Syncline", "entry in the game's AddOns settings")
check(ns.Theme.CHAT_PREFIX:find("media\\Logo", 1, true), "logo in the chat prefix")
check(SENT[1] == "Q^2" and SENT[2] == "S^2^" .. D1 .. "^" .. DE .. "^01-06 Durotar^1^20", "asks the leader after login: " .. tostring(SENT[2]))

-- the map knows German and English names
check(T.GuideID(DE, "01-06 Durotar") == D1 and T.GuideID(EN, "01-06 Durotar") == D1, "ids for both languages")
check(T.GuideID("RestedXP Horde Mage AoE", "12-17 The Barrens AoE") == MAGE, "translated names")

-- English leader, German me: same guide by id
T.OnMessage("G^2^" .. D2 .. "^" .. EN .. "^06-10 Durotar", "Leader-Realm")
check(guide() == DE .. " / 06-10 Durotar", "loads the German copy: " .. guide())
T.OnMessage("G^2^" .. MAGE .. "^RestedXP Horde Mage AoE^12-17 The Barrens AoE", "Leader")
check(guide() == "RestedXP Horde Magier AoE / 12-17 Das Brachland AoE", "translated guide name: " .. guide())
RunTimers()
check(SENT[#SENT] == "S^2^" .. MAGE .. "^RestedXP Horde Magier AoE^12-17 Das Brachland AoE^1^20", "status: " .. SENT[#SENT])

-- a guide Syncline doesn't know: group/name, then the same name in another group
T.OnMessage("G^2^^" .. DE .. "^06-10 Durotar", "Leader")
check(guide() == DE .. " / 06-10 Durotar", "no id, same names")
T.OnMessage("G^2^^Some Renamed Group^01-06 Durotar", "Leader")
check(guide() == DE .. " / 01-06 Durotar", "no id, name only")

-- old message format (0.1.0) is ignored
T.OnMessage("G^1^" .. EN .. "^06-10 Durotar", "Leader")
check(guide() == DE .. " / 01-06 Durotar", "ignores protocol 1")
T.OnMessage("S^1^" .. EN .. "^06-10 Durotar", "Fluffy-Shocks")
SlashCmdList.SYNCLINE("status")
check(logHas("Fluffy-Shocks: |cffff9900alte Syncline-Version"), "old version shown")

-- names of group members are secret (Midnight/Forever): the leader still counts
STATE.secretNames = true
T.OnMessage("G^2^" .. D2 .. "^" .. EN .. "^06-10 Durotar", "Leader-Beansen")
check(guide() == DE .. " / 06-10 Durotar", "leader found with secret unit names: " .. guide())
SlashCmdList.SYNCLINE("status")   -- the overview must not break either
T.OnMessage("G^2^" .. D1 .. "^" .. EN .. "^01-06 Durotar", "Leader")
check(guide() == DE .. " / 01-06 Durotar", "leader without realm")
T.OnMessage("G^2^" .. D2 .. "^^", "Bob-Beansen")
check(guide() == DE .. " / 01-06 Durotar", "still ignores non-leader")
STATE.secretNames = false

-- a non-leader can't switch me
T.OnMessage("G^2^" .. D2 .. "^^", "Bob-Realm")
check(guide() == DE .. " / 01-06 Durotar", "ignores non-leader")

-- missing / locked guide
T.OnMessage("G^2^forever/Alliance-1-13_Human.lua#1^RestedXP Forever Guide (A)^01-06 Northshire", "Leader")
check(logHas("gibt es bei dir nicht"), "missing guide message")
T.OnMessage("G^2^^" .. DE .. "^Locked", "Leader")
check(logHas("nicht geladen"), "not loaded message")

-- in combat: waits
RXPCData.currentGuideGroup, RXPCData.currentGuideName = DE, "06-10 Durotar"
STATE.combat = true
T.OnMessage("G^2^" .. D1 .. "^" .. EN .. "^01-06 Durotar", "Leader")
check(RXPCData.currentGuideName == "06-10 Durotar" and logHas("nach dem Kampf"), "waits in combat")
STATE.combat = false; Fire("PLAYER_REGEN_ENABLED")
check(RXPCData.currentGuideName == "01-06 Durotar", "loads after combat")

-- already in the same guide (other language): nothing happens
local loads = LOADS
T.OnMessage("G^2^" .. D1 .. "^" .. EN .. "^01-06 Durotar", "Leader")
check(LOADS == loads, "no reload for the same guide")

-- ask mode: popup, accept loads
SlashCmdList.SYNCLINE("fragen")
T.OnMessage("G^2^" .. D2 .. "^" .. EN .. "^06-10 Durotar", "Leader")
check(#POPUPS == 1 and RXPCData.currentGuideName == "01-06 Durotar", "asks first")
StaticPopupDialogs.SYNCLINE_SWITCH.OnAccept(nil, POPUPS[1].data)
check(RXPCData.currentGuideName == "06-10 Durotar", "accept loads")
SlashCmdList.SYNCLINE("auto")

-- member changes guide themselves: hint, and an offer to suggest it
local np = #POPUPS
RXP:LoadGuide(GUIDES[DE .. "||01-06 Durotar"]); RunTimers()
check(logHas("nicht mehr im Gruppen-Guide"), "left hint")
check(#POPUPS == np + 1 and POPUPS[#POPUPS].which == "SYNCLINE_OFFER", "offer popup")
StaticPopupDialogs.SYNCLINE_OFFER.OnAccept(nil, POPUPS[#POPUPS].data); RunTimers()
check(SENT[#SENT] == "P^2^" .. D1 .. "^" .. DE .. "^01-06 Durotar", "suggestion sent: " .. SENT[#SENT])
check(logHas("Dem Leiter vorgeschlagen"), "suggest message")
SlashCmdList.SYNCLINE("vorschlagen"); RunTimers()
check(SENT[#SENT]:find("^P%^2"), "/sl vorschlagen")
-- leader says no
T.OnMessage("N^2^Me", "Leader-Beansen")
check(logHas("bleibt beim aktuellen Guide"), "declined message")
-- another member's suggestion: just info for me
T.OnMessage("P^2^" .. D2 .. "^" .. EN .. "^06-10 Durotar", "Fluffy-Shocks")
check(logHas("Fluffy schlägt dem Leiter"), "info about others' suggestions")

-- sync off: stays
SlashCmdList.SYNCLINE("aus")
T.OnMessage("G^2^" .. D2 .. "^" .. EN .. "^06-10 Durotar", "Leader")
check(RXPCData.currentGuideName == "01-06 Durotar", "off keeps own guide")
SlashCmdList.SYNCLINE("an")

-- now I'm the (German) leader: picking a guide sends it with its id
STATE.me = "Leader"; local n = #SENT
RXP:LoadGuide(GUIDES[DE .. "||06-10 Durotar"]); RunTimers()
check(SENT[#SENT] == "G^2^" .. D2 .. "^" .. DE .. "^06-10 Durotar", "leader sends: " .. tostring(SENT[#SENT]))
T.OnMessage("Q^2", "Bob"); RunTimers()
local gotG = false for i = n + 2, #SENT do if SENT[i]:find("^G") then gotG = true end end
check(gotG, "leader answers Q")
-- status: Bob (English client) in the same guide counts as same
T.OnMessage("S^2^" .. D2 .. "^" .. EN .. "^06-10 Durotar", "Bob-Beansen")
T.OnMessage("S^2^" .. D2 .. "^" .. DE .. "^06-10 Durotar", "Fluffy-Shocks")
SlashCmdList.SYNCLINE("status")
check(logHas("Bob-Beansen: |cff40ff40gleicher Guide"), "English Bob counts as same guide")
T.OnMessage("S^2^" .. D1 .. "^" .. EN .. "^01-06 Durotar", "Bob-Beansen")
SlashCmdList.SYNCLINE("status")
check(logHas("Bob-Beansen: |cffff6060anderer Guide: 01-06 Durotar"), "status shows Bob elsewhere")
check(logHas("Fluffy-Shocks: |cff40ff40gleicher Guide"), "Fluffy from another realm")
check(logHas("Leader-Beansen (Leiter): |cff40ff40gleicher Guide"), "status shows leader")
-- combat: messages wait
STATE.combat = true; n = #SENT
RXP:LoadGuide(GUIDES[DE .. "||01-06 Durotar"]); RunTimers()
check(#SENT == n, "no send in combat")
STATE.combat = false; Fire("PLAYER_REGEN_ENABLED"); RunTimers()
check(SENT[#SENT] == "G^2^" .. D1 .. "^" .. DE .. "^01-06 Durotar", "sent after combat")
-- leader: Bob (English) suggests a guide, I take it, everyone gets it
np = #POPUPS
T.OnMessage("P^2^" .. MAGE .. "^RestedXP Horde Mage AoE^12-17 The Barrens AoE", "Bob-Beansen")
check(#POPUPS == np + 1 and POPUPS[#POPUPS].which == "SYNCLINE_SUGGEST", "leader gets suggestion popup")
check(POPUPS[#POPUPS].text:find("12-17 Das Brachland AoE", 1, true), "popup in my language")
StaticPopupDialogs.SYNCLINE_SUGGEST.OnAccept(nil, POPUPS[#POPUPS].data); RunTimers()
check(guide() == "RestedXP Horde Magier AoE / 12-17 Das Brachland AoE", "leader loaded it")
check(logHas("Vorschlag von Bob übernommen"), "taken message")
check(SENT[#SENT] == "G^2^" .. MAGE .. "^RestedXP Horde Magier AoE^12-17 Das Brachland AoE", "sent to group: " .. SENT[#SENT])
-- leader declines
T.OnMessage("P^2^" .. D2 .. "^" .. EN .. "^06-10 Durotar", "Bob-Beansen")
StaticPopupDialogs.SYNCLINE_SUGGEST.OnCancel(nil, POPUPS[#POPUPS].data, "clicked"); RunTimers()
check(SENT[#SENT] == "N^2^Bob", "decline sent: " .. SENT[#SENT])
check(guide() == "RestedXP Horde Magier AoE / 12-17 Das Brachland AoE", "declined keeps guide")
-- in combat: taken afterwards
STATE.combat = true
T.OnMessage("P^2^" .. D2 .. "^" .. EN .. "^06-10 Durotar", "Bob-Beansen")
StaticPopupDialogs.SYNCLINE_SUGGEST.OnAccept(nil, POPUPS[#POPUPS].data)
check(logHas("wird nach dem Kampf übernommen"), "take later")
STATE.combat = false; Fire("PLAYER_REGEN_ENABLED"); RunTimers()
check(SENT[#SENT] == "G^2^" .. D2 .. "^" .. DE .. "^06-10 Durotar", "sent after combat: " .. SENT[#SENT])
---------------------------------------------------------------------------
-- Steps
---------------------------------------------------------------------------
local MAGE_DE = "^RestedXP Horde Magier AoE^12-17 Das Brachland AoE"
local function lastSent(prefix) for i = #SENT, 1, -1 do if SENT[i]:find(prefix, 1, true) == 1 then return SENT[i] end end end
RXP:LoadGuide(GUIDES["RestedXP Horde Magier AoE||12-17 Das Brachland AoE"]); RunTimers()
check(T.MyStep() == 1, "my step")
-- leader: my step changes -> T to the group
RXP.SetStep(5); RunTimers()
check(lastSent("T^") == "T^2^5^20", "step sent: " .. tostring(lastSent("T^")))
-- Bob is at 3, in the same guide: 2 behind
T.OnMessage("S^2^" .. MAGE .. "^RestedXP Horde Mage AoE^12-17 The Barrens AoE^3^20", "Bob-Beansen")
local snap = ns.Snapshot()
local bob; for _, m in ipairs(snap.members) do if m.name == "Bob-Beansen" then bob = m end end
check(bob.step == 3 and bob.diff == -2, "Bob 2 behind: " .. tostring(bob.diff))
check(snap.leaderStepText == "Kaltunk Schritt 5 bei Kaltunk", "step text cleaned: " .. tostring(snap.leaderStepText))
T.OnMessage("T^2^4^20", "Bob-Beansen")
snap = ns.Snapshot(); for _, m in ipairs(snap.members) do if m.name == "Bob-Beansen" then bob = m end end
check(bob.step == 4 and bob.state == "same", "T keeps the guide, updates the step")
-- leader skips step 5 for the group
ns.Actions.SkipForGroup(); RunTimers()
check(lastSent("K^") == "K^2^5^" .. MAGE .. MAGE_DE, "skip sent: " .. tostring(lastSent("K^")))
check(T.MyStep() == 6, "leader skipped too")
-- Bob asks to skip step 4
local np = #POPUPS
T.OnMessage("R^2^4^" .. MAGE .. "^RestedXP Horde Mage AoE^12-17 The Barrens AoE", "Bob-Beansen")
check(#POPUPS == np + 1 and POPUPS[#POPUPS].which == "SYNCLINE_SKIPREQ", "skip request popup")
check(POPUPS[#POPUPS].text:find("Bob möchte", 1, true) and POPUPS[#POPUPS].text:find("Schritt 4", 1, true), "request text")
StaticPopupDialogs.SYNCLINE_SKIPREQ.OnAccept(nil, POPUPS[#POPUPS].data); RunTimers()
check(lastSent("K^") == "K^2^4^" .. MAGE .. MAGE_DE, "request accepted: skip 4 for all")
check(T.MyStep() == 6, "leader at 6 stays")
-- declined
T.OnMessage("R^2^4^" .. MAGE .. "^^", "Bob-Beansen")
StaticPopupDialogs.SYNCLINE_SKIPREQ.OnCancel(nil, POPUPS[#POPUPS].data, "clicked"); RunTimers()
check(lastSent("N^") == "N^2^Bob^R", "decline: " .. tostring(lastSent("N^")))
-- a request for another guide is ignored
np = #POPUPS
T.OnMessage("R^2^4^" .. D1 .. "^^", "Bob-Beansen")
check(#POPUPS == np, "request for another guide ignored")
-- pull everyone to my step
ns.Actions.PullToMyStep(); RunTimers()
check(lastSent("J^") == "J^2^6^" .. MAGE .. MAGE_DE, "pull: " .. tostring(lastSent("J^")))

-- member side
STATE.me = "Me"
RXP.SetStep(6)
T.OnMessage("K^2^6^" .. MAGE .. "^RestedXP Horde Mage AoE^12-17 The Barrens AoE", "Leader-Beansen")
check(T.MyStep() == 7 and logHas("hat Schritt 6"), "member: leader skips my step")
T.OnMessage("K^2^3^" .. MAGE .. "^^", "Leader")
check(T.MyStep() == 7 and logHas("du bist bei Schritt 7"), "member elsewhere: only info")
T.OnMessage("K^2^7^" .. MAGE .. "^^", "Bob-Beansen")
check(T.MyStep() == 7, "only the leader skips")
T.OnMessage("K^2^7^" .. D1 .. "^^", "Leader")
check(T.MyStep() == 7, "skip in another guide ignored")
T.OnMessage("J^2^12^" .. MAGE .. "^^", "Leader")
check(T.MyStep() == 12 and logHas("holt die Gruppe zu Schritt 12"), "pulled to 12")
-- in combat: afterwards
STATE.combat = true
T.OnMessage("J^2^14^" .. MAGE .. "^^", "Leader")
check(T.MyStep() == 12, "waits in combat")
STATE.combat = false; Fire("PLAYER_REGEN_ENABLED")
check(T.MyStep() == 14, "after combat")
-- ask mode
SlashCmdList.SYNCLINE("fragen")
T.OnMessage("K^2^14^" .. MAGE .. "^^", "Leader")
check(T.MyStep() == 14 and POPUPS[#POPUPS].which == "SYNCLINE_STEP", "asks first")
StaticPopupDialogs.SYNCLINE_STEP.OnAccept(nil, POPUPS[#POPUPS].data)
check(T.MyStep() == 15, "accepted")
SlashCmdList.SYNCLINE("auto")
-- switched off
ns.db.followSteps = false
T.OnMessage("J^2^2^" .. MAGE .. "^^", "Leader")
check(T.MyStep() == 15, "followSteps off")
ns.db.followSteps = true
-- ask for a skip
SlashCmdList.SYNCLINE("skippen"); RunTimers()
check(lastSent("R^") == "R^2^15^" .. MAGE .. MAGE_DE, "request sent: " .. tostring(lastSent("R^")))
T.OnMessage("N^2^Me^R", "Leader")
check(logHas("überspringt den Schritt nicht"), "request declined message")
-- status line has the step
SlashCmdList.SYNCLINE("status")
check(logHas("Schritt 15/20"), "status shows my step")
STATE.me = "Leader"

-- the windows
SlashCmdList.SYNCLINE(""); RunTimers()
check(SynclineGroupFrame:IsShown(), "/sl opens the group window")
check(TextShown("06-10 Durotar"), "window shows the group guide")
check(TextShown("Schritt skippen") and TextShown("Alle zu mir") and TextShown("Guide senden"), "leader buttons (German)")
check(TextShown("Schritt des Leiters"), "leader's step in the window")
check(TextShown("Bob"), "window lists Bob")
-- the window follows changes
T.OnMessage("S^2^" .. D1 .. "^" .. EN .. "^01-06 Durotar", "Bob-Beansen"); RunTimers()
check(TextShown("anderer Guide: 01-06 Durotar"), "window updates")
ns.HandleClick("LeftButton")
check(not SynclineGroupFrame:IsShown(), "left click closes it again")
ns.HandleClick("RightButton")
check(SynclineOptionsFrame:IsShown(), "right click: settings")
check(TextShown("Dem Guide des Gruppenleiters folgen"), "settings in German")
check(TextShown("|cff5cd97agefunden"), "RestedXP found")
SlashCmdList.SYNCLINE("minimap aus")
check(not SynclineMinimapButton:IsShown(), "/sl minimap aus")
SlashCmdList.SYNCLINE("minimap")
check(SynclineMinimapButton:IsShown(), "/sl minimap toggles")
TOOLTIP = {}
Syncline_OnCompartmentEnter(nil, UIParent)
check(TOOLTIP[2] and TOOLTIP[2]:find("Gruppen-Guide", 1, true), "tooltip shows the group guide: " .. tostring(TOOLTIP[2]))
-- the minimap button can be dragged round
SynclineMinimapButton:GetScript("OnDragStart")(SynclineMinimapButton)
check(SynclineMinimapButton:GetScript("OnUpdate"), "dragging")
-- out of the group: the window explains
STATE.group = false; Fire("GROUP_ROSTER_UPDATE"); RunTimers()
SlashCmdList.SYNCLINE(""); RunTimers()
check(TextShown("Du bist in keiner Gruppe"), "not in group text")
LOG[#LOG + 1] = "ALL PASSED"
