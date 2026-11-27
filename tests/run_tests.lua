-- Syncline tests. Run from the repo root: lua5.1 tests/run.lua
local function check(c, m) if not c then error(m or "check failed", 2) end end
local function logHas(s) for i = #LOG, 1, -1 do if LOG[i]:find(s, 1, true) then return true end end end
local function lastSent(prefix) for i = #SENT, 1, -1 do if SENT[i]:find(prefix, 1, true) == 1 then return SENT[i] end end end
local function guide() return RXPCData.currentGuideGroup .. " / " .. RXPCData.currentGuideName end
local ns = {}
assert(loadfile("Locale.lua"))("Syncline", ns)
assert(loadfile("GuideMap.lua"))("Syncline", ns)
assert(loadfile("Theme.lua"))("Syncline", ns)
assert(loadfile("Core.lua"))("Syncline", ns)
assert(loadfile("XP.lua"))("Syncline", ns)
assert(loadfile("Missing.lua"))("Syncline", ns)
assert(loadfile("Blockers.lua"))("Syncline", ns)
assert(loadfile("Share.lua"))("Syncline", ns)
assert(loadfile("Progress.lua"))("Syncline", ns)
assert(loadfile("Travel.lua"))("Syncline", ns)
assert(loadfile("Slack.lua"))("Syncline", ns)
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
check(SENT[1] == "Q^2" and SENT[2] == "S^2^" .. D1 .. "^" .. DE .. "^01-06 Durotar^1^20^3", "asks the leader after login: " .. tostring(SENT[2]))

-- the map knows German and English names
check(T.GuideID(DE, "01-06 Durotar") == D1 and T.GuideID(EN, "01-06 Durotar") == D1, "ids for both languages")
check(T.GuideID("RestedXP Horde Mage AoE", "12-17 The Barrens AoE") == MAGE, "translated names")

-- English leader, German me: same guide by id
T.OnMessage("G^2^" .. D2 .. "^" .. EN .. "^06-10 Durotar", "Leader-Realm")
check(guide() == DE .. " / 06-10 Durotar", "loads the German copy: " .. guide())
T.OnMessage("G^2^" .. MAGE .. "^RestedXP Horde Mage AoE^12-17 The Barrens AoE", "Leader")
check(guide() == "RestedXP Horde Magier AoE / 12-17 Das Brachland AoE", "translated guide name: " .. guide())
RunTimers()
check(SENT[#SENT] == "S^2^" .. MAGE .. "^RestedXP Horde Magier AoE^12-17 Das Brachland AoE^1^20^3", "status: " .. SENT[#SENT])

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
check(lastSent("G^") == "G^2^" .. D2 .. "^" .. DE .. "^06-10 Durotar", "leader sends: " .. tostring(SENT[#SENT]))
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
check(lastSent("G^") == "G^2^" .. D1 .. "^" .. DE .. "^01-06 Durotar", "sent after combat")
-- leader: Bob (English) suggests a guide, I take it, everyone gets it
np = #POPUPS
T.OnMessage("P^2^" .. MAGE .. "^RestedXP Horde Mage AoE^12-17 The Barrens AoE", "Bob-Beansen")
check(#POPUPS == np + 1 and POPUPS[#POPUPS].which == "SYNCLINE_SUGGEST", "leader gets suggestion popup")
check(POPUPS[#POPUPS].text:find("12-17 Das Brachland AoE", 1, true), "popup in my language")
StaticPopupDialogs.SYNCLINE_SUGGEST.OnAccept(nil, POPUPS[#POPUPS].data); RunTimers()
check(guide() == "RestedXP Horde Magier AoE / 12-17 Das Brachland AoE", "leader loaded it")
check(logHas("Vorschlag von Bob übernommen"), "taken message")
check(lastSent("G^") == "G^2^" .. MAGE .. "^RestedXP Horde Magier AoE^12-17 Das Brachland AoE", "sent to group: " .. SENT[#SENT])
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
check(lastSent("G^") == "G^2^" .. D2 .. "^" .. DE .. "^06-10 Durotar", "sent after combat: " .. SENT[#SENT])
---------------------------------------------------------------------------
-- Steps
---------------------------------------------------------------------------
local MAGE_DE = "^RestedXP Horde Magier AoE^12-17 Das Brachland AoE"
RXP:LoadGuide(GUIDES["RestedXP Horde Magier AoE||12-17 Das Brachland AoE"]); RunTimers()
check(T.MyStep() == 1, "my step")
-- leader: my step changes -> T to the group
RXP.SetStep(5); RunTimers()
check(lastSent("T^") == "T^2^5^20^15", "step sent: " .. tostring(lastSent("T^")))
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
check(lastSent("K^") == "K^2^5^" .. MAGE .. MAGE_DE .. "^15", "skip sent: " .. tostring(lastSent("K^")))
check(T.MyStep() == 6, "leader skipped too")
-- Bob asks to skip step 4
local np = #POPUPS
T.OnMessage("R^2^4^" .. MAGE .. "^RestedXP Horde Mage AoE^12-17 The Barrens AoE", "Bob-Beansen")
check(#POPUPS == np + 1 and POPUPS[#POPUPS].which == "SYNCLINE_SKIPREQ", "skip request popup")
check(POPUPS[#POPUPS].text:find("Bob möchte", 1, true) and POPUPS[#POPUPS].text:find("Schritt 4", 1, true), "request text")
StaticPopupDialogs.SYNCLINE_SKIPREQ.OnAccept(nil, POPUPS[#POPUPS].data); RunTimers()
check(lastSent("K^") == "K^2^4^" .. MAGE .. MAGE_DE .. "^12", "request accepted: skip 4 for all")
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
check(lastSent("J^") == "J^2^6^" .. MAGE .. MAGE_DE .. "^18", "pull: " .. tostring(lastSent("J^")))

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
check(lastSent("R^") == "R^2^15^" .. MAGE .. MAGE_DE .. "^45", "request sent: " .. tostring(lastSent("R^")))
T.OnMessage("N^2^Me^R", "Leader")
check(logHas("überspringt den Schritt nicht"), "request declined message")
-- status line has the step
SlashCmdList.SYNCLINE("status")
check(logHas("Schritt 15/20"), "status shows my step")
STATE.me = "Leader"

---------------------------------------------------------------------------
-- Imported (paid) guides: names differ by language, quests don't
---------------------------------------------------------------------------
local FP = "q:43-44:9001.9002.9003.9004.9005.9006.9007.9008.9009.9010"
STATE.me = "Me"
local before = LOG[#LOG]
T.OnMessage("G^2^" .. FP .. "^RestedXP Forever Guide (H)^43-44 Riverglades II", "Leader Beansen")
check(guide() == DE .. " / 43-44 Flusslande II", "English leader, German import: " .. guide())
check(logHas("Leader hat |cffffd10043-44 Flusslande II"), "German name in the message, leader with space-realm")
-- a newer guide version: 8 of 10 quests the same still matches
RXP:LoadGuide(GUIDES[DE .. "||01-06 Durotar"])
T.OnMessage("G^2^q:43-44:9001.9002.9003.9004.9005.9006.9007.9008.9998.9999^RestedXP Forever Guide (H)^43-44 Riverglades II", "Leader")
check(guide() == DE .. " / 43-44 Flusslande II", "fuzzy fingerprint")
-- the other 43-44 guide is never taken for it
T.OnMessage("G^2^q:43-44:7001.7002.7003^RestedXP Forever Guide (H)^43-44 Dustwallow", "Leader")
check(guide() == DE .. " / 43-44 Sümpfe des Elends", "picks by quests, not by range alone: " .. guide())
-- unknown quests for that range: not found, said once
local nlog = #LOG
T.OnMessage("G^2^q:43-44:1.2.3^RestedXP Forever Guide (H)^43-44 Somewhere", "Leader")
T.OnMessage("G^2^q:43-44:1.2.3^RestedXP Forever Guide (H)^43-44 Somewhere", "Leader")
local missing = 0
for i = nlog + 1, #LOG do if LOG[i]:find("gibt es bei dir nicht", 1, true) then missing = missing + 1 end end
check(missing == 1, "missing message only once: " .. missing)
-- chapter guides: "11. The Drowned Capitals" (English) is our "11. Die Ertrunkenen Hauptstädte"
T.OnMessage("G^2^q:c11:8101.8102.8103.8104^RestedXP Forever Guide (H)^11. The Drowned Capitals", "Leader")
check(guide() == DE .. " / 11. Die Ertrunkenen Hauptstädte", "chapter guide: " .. guide())
-- a guide without any number: by its quests alone
T.OnMessage("G^2^q::8301.8302^RestedXP Forever Guide (H)^Bonus: Fishing", "Leader")
check(guide() == DE .. " / Bonus: Angeln", "no number, by quests: " .. guide())
-- and not just any guide without number when the quests don't match
T.OnMessage("G^2^q::1.2.3^RestedXP Forever Guide (H)^Something Else", "Leader")
check(guide() == DE .. " / Bonus: Angeln", "no match without number: stays")
-- my imported guide: I send its fingerprint, and the status counts as same
RXP:LoadGuide(GUIDES[DE .. "||43-44 Flusslande II"]); RunTimers()
local mine = T.Mine()
check(mine.id == FP, "my fingerprint: " .. tostring(mine.id))
STATE.me = "Leader"
ns.Actions.Send(); RunTimers()
check(lastSent("G^") == "G^2^" .. FP .. "^" .. DE .. "^43-44 Flusslande II", "leader sends the fingerprint: " .. tostring(lastSent("G^")))
T.OnMessage("S^2^" .. FP .. "^RestedXP Forever Guide (H)^43-44 Riverglades II^3^60", "Bob Beansen")
snap = ns.Snapshot(); for _, m in ipairs(snap.members) do if m.name == "Bob-Beansen" then bob = m end end
check(bob.state == "same", "English Bob in the imported guide counts as same: " .. tostring(bob.state))
RXP:LoadGuide(GUIDES["RestedXP Horde Magier AoE||12-17 Das Brachland AoE"]); RunTimers()

---------------------------------------------------------------------------
-- RestedXP route settings
---------------------------------------------------------------------------
local P = RXP.settings.profile
-- language independent: only keys, numbers and RestedXP's dungeon tags (DM, RFC, ...)
check(ns.MyRoute():match("^[%a]=[%w.,]*[;%a=%w.,]*$"), "route settings carry no translated text")
check(ns.MyRoute() == "a=0;r=1.00;x=1;g=1;f=0;d=DM,RFC", "my route: " .. tostring(ns.MyRoute()))
-- member: the leader has other dungeons and no overleveled skipping
STATE.me = "Me"
local r0 = RELOADS
T.OnMessage("W^2^a=0;r=1.00;x=0;g=1;f=0;d=DM,SFK,WC", "Leader Beansen"); RunTimers()
check(P.enableXpStepSkipping == false and P.dungeons.SFK == true and P.dungeons.WC == true and P.dungeons.RFC == false,
      "member took the leader's route settings")
check(RELOADS == r0 + 1, "RestedXP reloads the guide once")
check(logHas("übernommen: Überlevelte Schritte überspringen, Dungeons"), "says what changed")
check(lastSent("V^") == "V^2^a=0;r=1.00;x=0;g=1;f=0;d=DM,SFK,WC", "tells the group: " .. tostring(lastSent("V^")))
-- same again: nothing to do
r0 = RELOADS
T.OnMessage("W^2^a=0;r=1.00;x=0;g=1;f=0;d=DM,SFK,WC", "Leader"); RunTimers()
check(RELOADS == r0, "same settings: no reload")
-- only the leader
T.OnMessage("W^2^a=0;r=1.00;x=1;g=1;f=0;d=", "Bob-Beansen"); RunTimers()
check(P.enableXpStepSkipping == false, "only the leader's settings count")
-- automatic EXP rate: the rate itself isn't compared
P.enableAutomaticXpRate = true; P.xprate = 1.35
check(not ns.MyRoute():find("r=", 1, true), "automatic rate not sent")
P.enableAutomaticXpRate = false; P.xprate = 1
-- ask mode
SlashCmdList.SYNCLINE("fragen")
T.OnMessage("W^2^a=0;r=1.00;x=1;g=1;f=0;d=DM,SFK,WC", "Leader"); RunTimers()
check(P.enableXpStepSkipping == false and POPUPS[#POPUPS].which == "SYNCLINE_ROUTE", "asks first")
check(POPUPS[#POPUPS].text:find("Überlevelte Schritte", 1, true), "popup says what differs")
StaticPopupDialogs.SYNCLINE_ROUTE.OnAccept(nil, POPUPS[#POPUPS].data); RunTimers()
check(P.enableXpStepSkipping == true, "accepted")
SlashCmdList.SYNCLINE("auto")
-- switched off
ns.db.followRoute = false
T.OnMessage("W^2^a=0;r=1.00;x=0;g=1;f=0;d=DM", "Leader"); RunTimers()
check(P.enableXpStepSkipping == true and P.dungeons.SFK == true, "followRoute off")
ns.db.followRoute = true
-- in combat: afterwards
STATE.combat = true
T.OnMessage("W^2^a=0;r=1.00;x=1;g=0;f=0;d=DM,SFK,WC", "Leader"); RunTimers()
check(P.enableGroupQuests == true, "waits in combat")
STATE.combat = false; Fire("PLAYER_REGEN_ENABLED"); RunTimers()
check(P.enableGroupQuests == false, "after combat")
-- leader side
STATE.me = "Leader"
P.enableGroupQuests = true
T.CheckRoute(); RunTimers()
check(lastSent("W^") == "W^2^" .. ns.MyRoute(), "leader's change goes to the group: " .. tostring(lastSent("W^")))
local w0 = #SENT
T.CheckRoute(); RunTimers()
check(#SENT == w0, "no change: nothing sent")
-- Bob has other dungeons: the window shows it
T.OnMessage("V^2^a=0;r=1.00;x=1;g=1;f=0;d=DM", "Bob Beansen")
snap = ns.Snapshot(); for _, m in ipairs(snap.members) do if m.name == "Bob-Beansen" then bob = m end end
check(bob.routeDiff and bob.routeDiff[1] == "Dungeons", "Bob's other dungeons")
SlashCmdList.SYNCLINE("status")
check(logHas("andere Einstellungen: Dungeons"), "status line")
-- the guide brings the settings along
ns.Actions.Send(); RunTimers()
check(lastSent("W^") == "W^2^" .. ns.MyRoute(), "sent with the guide")

-- "Guide sent" in the chat only when it's news
local function sentLines(from) local n = 0 for i = from, #LOG do if LOG[i]:find("Guide an die Gruppe geschickt", 1, true) then n = n + 1 end end return n end
local l0, s0 = #LOG + 1, #SENT
T.OnMessage("Q^2", "Bob Beansen"); RunTimers()
T.OnMessage("Q^2", "Fluffy-Shocks"); RunTimers()
check(sentLines(l0) == 0, "answers to Q are quiet")
local gs = 0 for i = s0 + 1, #SENT do if SENT[i]:find("^G") then gs = gs + 1 end end
check(gs >= 1, "but the guide still goes out")
ns.Actions.Send(); RunTimers()
check(sentLines(l0) == 1, "by hand: in the chat")
RXP:LoadGuide(GUIDES[DE .. "||06-10 Durotar"]); RunTimers()
check(sentLines(l0) == 2, "new guide: in the chat")
-- member: a loading-screen flicker doesn't ask again
STATE.me = "Me"
T.OnMessage("G^2^" .. D2 .. "^^", "Leader")
local q0 = #SENT
STATE.group = false; Fire("GROUP_ROSTER_UPDATE")
STATE.group = true; Fire("GROUP_ROSTER_UPDATE"); RunTimers()
local asked = false for i = q0 + 1, #SENT do if SENT[i] == "Q^2" then asked = true end end
check(not asked, "no new question after a flicker")
check(T.leaderGuide() and T.leaderGuide().id == D2, "still knows the leader's guide")
STATE.me = "Leader"
---------------------------------------------------------------------------
-- Classes: RestedXP leaves out steps for other classes, numbers differ, lines don't
---------------------------------------------------------------------------
-- leader (me) has all 20 steps; Bob lacks the step at line 9 (another class): 19 steps
RXP:LoadGuide(GUIDES["RestedXP Horde Magier AoE||12-17 Das Brachland AoE"]); RXP.SetStep(8); RunTimers()   -- line 24
T.OnMessage("S^2^" .. MAGE .. "^^^7^19^24", "Bob Beansen")
snap = ns.Snapshot(); for _, m in ipairs(snap.members) do if m.name == "Bob-Beansen" then bob = m end end
check(bob.step == 7 and bob.diff == 0, "Bob at 7/19 is at my 8/20: same step (" .. tostring(bob.diff) .. ")")
-- an older Syncline without lines and another step count: no made-up difference
T.OnMessage("S^2^" .. MAGE .. "^^^57^100", "Fluffy-Shocks")
snap = ns.Snapshot()
for _, m in ipairs(snap.members) do if m.name == "Fluffy-Shocks" then check(m.diff == nil, "no diff without lines: " .. tostring(m.diff)) end end
-- Bob asks to skip his step 7 (line 24): the popup and the skip are about my step 8
T.OnMessage("R^2^7^" .. MAGE .. "^^^24", "Bob Beansen")
check(POPUPS[#POPUPS].text:find("Schritt 8", 1, true), "request shown as my step 8")
StaticPopupDialogs.SYNCLINE_SKIPREQ.OnAccept(nil, POPUPS[#POPUPS].data); RunTimers()
check(lastSent("K^") == "K^2^8^" .. MAGE .. MAGE_DE .. "^24", "skip by line: " .. tostring(lastSent("K^")))
check(T.MyStep() == 9, "I was at it: moved on")

-- member side: my guide lacks the step at line 9
STATE.me = "Me"
RXP:LoadGuide(GUIDES["RestedXP Horde Magier AoE||12-17 Das Brachland AoE"])
local full = RXP.currentGuide
local mine19 = { group = full.group, name = full.name, guideId = full.guideId, steps = {} }
for i, st in ipairs(full.steps) do if st.stepId - full.guideId ~= 9 then mine19.steps[#mine19.steps + 1] = st end end
RXP.currentGuide = mine19
RXP.SetStep(6)   -- line 21 here, the leader calls it step 7
T.OnMessage("K^2^7^" .. MAGE .. "^^^21", "Leader")
check(T.MyStep() == 7, "skip finds my step by line: " .. T.MyStep())
T.OnMessage("K^2^7^" .. MAGE .. "^^^21", "Leader")
check(T.MyStep() == 7 and logHas("du bist bei Schritt 7"), "not at it any more: only info")
T.OnMessage("J^2^10^" .. MAGE .. "^^^30", "Leader")
check(T.MyStep() == 9, "pull to the leader's line 30 = my step 9: " .. T.MyStep())
-- the step at line 9 doesn't exist here: pull lands on the next one I have
T.OnMessage("J^2^3^" .. MAGE .. "^^^9", "Leader")
check(T.MyStep() == 3 and T.StepLine(3) == 12, "missing line: next step I have")
RXP.currentGuide = full
STATE.me = "Leader"
RXP:LoadGuide(GUIDES["RestedXP Horde Magier AoE||12-17 Das Brachland AoE"]); RunTimers()

---------------------------------------------------------------------------
-- Safe to skip?
---------------------------------------------------------------------------
local function E(tag, id) return { tag = tag, questId = id } end
QNAMES = { [100] = "Ärger am Fluss", [101] = "Die Spur der Räuber", [102] = "Das Lager", [103] = "Der Anführer", [200] = "Kräuter sammeln" }
RXP.GetQuestName = function(id) return QNAMES[id] end
local chain = { group = DE, name = "43-44 Flusslande II", guideId = 5000, steps = {
    { stepId = 5003, elements = { E("accept", 100) } },                                      -- 1
    { stepId = 5006, elements = { E("complete", 100) } },                                    -- 2
    { stepId = 5009, elements = { E("turnin", 100), E("accept", 101) } },                    -- 3
    { stepId = 5012, elements = { E("complete", 101) } },                                    -- 4
    { stepId = 5015, elements = { E("turnin", 101), E("accept", 102) } },                    -- 5
    { stepId = 5018, elements = { { tag = "isQuestTurnedIn", questIds = { 102 } }, E("accept", 103) } }, -- 6
    { stepId = 5021, elements = { E("accept", 200) } },                                      -- 7
    { stepId = 5024, elements = { E("complete", 200) } },                                    -- 8
    { stepId = 5027, elements = { E("turnin", 200) } },                                      -- 9
    { stepId = 5030, elements = { { text = "Lauft zum Lager" } } },                          -- 10
} }
RXP.currentGuide = chain
RXPCData.currentGuideGroup, RXPCData.currentGuideName = DE, "43-44 Flusslande II"
local r2 = ns.SkipRisk(2)
check(r2.level == "chain" and #r2.followups == 3, "chain behind A: " .. r2.level .. " " .. #r2.followups)
check(ns.RiskText(r2):find("3 Folgequest(s): Die Spur der Räuber, Das Lager, Der Anführer", 1, true), "names: " .. ns.RiskText(r2))
local r5 = ns.SkipRisk(5)
check(r5.level == "some" and r5.followups[1] == 103, "turn-in step: one follow-up via isQuestTurnedIn")
check(ns.SkipRisk(8).level == "safe", "single quest: safe")
check(ns.RiskText(ns.SkipRisk(8)):find("sicher zu skippen", 1, true), "safe text")
check(ns.SkipRisk(10).level == "none", "travel step: no quest")
-- leader skips a risky step: asked first
RXP.SetStep(2)
local np = #POPUPS
ns.Actions.SkipForGroup(); RunTimers()
check(#POPUPS == np + 1 and POPUPS[#POPUPS].which == "SYNCLINE_SKIPRISK", "risky skip asks first")
check(POPUPS[#POPUPS].text:find("Folgequest", 1, true), "popup shows the follow-ups")
local k0 = lastSent("K^")
StaticPopupDialogs.SYNCLINE_SKIPRISK.OnAccept(nil, POPUPS[#POPUPS].data); RunTimers()
check(lastSent("K^") ~= k0 and lastSent("K^"):find("^K%^2%^2%^"), "skipped after OK: " .. tostring(lastSent("K^")))
-- a safe step goes straight away
RXP.SetStep(8); np = #POPUPS
ns.Actions.SkipForGroup(); RunTimers()
check(#POPUPS == np and lastSent("K^"):find("^K%^2%^8%^"), "safe skip without asking")
-- a member asks: the popup has the check in it
T.OnMessage("R^2^4^" .. (T.Mine().id or "") .. "^" .. DE .. "^43-44 Flusslande II^12", "Bob Beansen")
check(POPUPS[#POPUPS].which == "SYNCLINE_SKIPREQ" and POPUPS[#POPUPS].text:find("Folgequest", 1, true), "request popup with check")
-- the window shows it for the leader's step
RXP.SetStep(2)
if not ns.GroupWindow:IsShown() then SlashCmdList.SYNCLINE("") end
ns.GroupWindow:Refresh(); RunTimers()
check(TextShown("3 Folgequest(s)"), "window: skip check line")
SlashCmdList.SYNCLINE("")   -- close again

---------------------------------------------------------------------------
-- Missing quests (same quest chain)
---------------------------------------------------------------------------
local Miss = ns.Missing
Miss.HookAbandon()
RXP.SetStep(2)                         -- "complete A" is next
local list = Miss:Scan()
check(#list == 1 and list[1].id == 100 and list[1].step == 2 and list[1].tag == "complete",
      "A is needed but not in the log: " .. #list)
ONQUEST[100] = true
check(#Miss:Scan() == 0, "A in the log: nothing missing")
ONQUEST[100] = nil; TURNEDIN[100] = true
check(#Miss:Scan() == 0, "A turned in: nothing missing")
TURNEDIN[100] = nil
-- quests the guide picks up again later don't count (B, C, D and E are accepted ahead)
RXP.SetStep(4); ONQUEST[101] = true
check(#Miss:Scan() == 0, "B in the log, later quests are accepted later")
-- told once in the chat, sent to the group
ONQUEST[101] = nil
local nlog = #LOG
Miss:Update(); Miss:Update()
local tells = 0 for i = nlog + 1, #LOG do if LOG[i]:find("nicht angenommen (Schritt 3)", 1, true) then tells = tells + 1 end end
check(tells == 1, "told once: " .. tells)
check(logHas("Die Spur der Räuber"), "by name")
check(lastSent("M^") == "M^2^1^101!", "sent, marked as not accepted: " .. tostring(lastSent("M^")))
-- abandoning a quest the guide still needs
ONQUEST[101] = true; ABANDONING = 101
local np = #POPUPS
C_QuestLog.SetAbandonQuest()
check(#POPUPS == np + 1 and POPUPS[#POPUPS].which == "SYNCLINE_ABANDON", "abandon warning")
check(POPUPS[#POPUPS].text:find("Die Spur der Räuber", 1, true) and POPUPS[#POPUPS].text:find("Ziele bei Schritt 4", 1, true)
      and POPUPS[#POPUPS].text:find("Abgabe bei Schritt 5", 1, true), "says where: " .. POPUPS[#POPUPS].text)
-- a quest the guide picks up again before it needs it: no warning
ABANDONING = 200; np = #POPUPS
C_QuestLog.SetAbandonQuest()
check(#POPUPS == np, "picked up again later: no warning")
-- the guide itself says abandon: no warning
chain.steps[4].elements[2] = { ids = { 101 }, text = "Abandon" }
ABANDONING = 101; np = #POPUPS
C_QuestLog.SetAbandonQuest()
check(#POPUPS == np, "guide says abandon: no warning")
chain.steps[4].elements[2] = nil
-- the group: Bob misses two
T.OnMessage("M^2^2^100,200", "Bob Beansen")
local bc, bids = Miss:Get("Bob-Beansen")
check(bc == 2 and bids[2] == 200, "Bob's missing quests")
ONQUEST[101] = nil; Miss:Scan()
if not ns.GroupWindow:IsShown() then SlashCmdList.SYNCLINE("") end
ns.GroupWindow:Refresh()
check(TextShown("FEHLENDE QUESTS") and TextShown("2: Ärger am Fluss, Kräuter sammeln"), "window card")
SlashCmdList.SYNCLINE("")
SlashCmdList.SYNCLINE("fehlend")
check(logHas("1 Quest(s), die dein Guide noch braucht") and logHas("Die Spur der Räuber (bei Schritt 3 nicht angenommen)"), "/sl fehlend")
ONQUEST[101] = true; Miss:Scan(); ABANDONING = nil

---------------------------------------------------------------------------
-- Why can't the step be done yet? (same chain)
---------------------------------------------------------------------------
local Blk = ns.Blockers
local function codes(n) local t = {} for _, r in ipairs(Blk:Check(n)) do t[#t + 1] = r.code .. (r.quest and (":" .. r.quest) or "") end return table.concat(t, " ") end
wipe(ONQUEST); wipe(TURNEDIN)
-- step 3 turns A in and accepts B: A's turn-in is the step's own job
ONQUEST[100] = true
check(not codes(3):find("prereq", 1, true), "own turn-in is no prerequisite: " .. codes(3))
-- step 6 needs C turned in
check(codes(6) == "prereq:102", "prerequisite C: " .. codes(6))
check(Blk:Text(Blk:Check(6)[1]) == "erst |cffffd100Das Lager|r abgeben", "text: " .. Blk:Text(Blk:Check(6)[1]))
check(Blk:Text({ code = "prereq", quest = 101, step = 5 }) == "erst |cffffd100Die Spur der Räuber|r abgeben (Schritt 5)", "with the step")
-- step 4 completes B, which isn't in the log
check(codes(4) == "notinlog:101", "not in the log: " .. codes(4))
-- step 5 turns B in: in the log but not done
ONQUEST[101] = true
OBJECTIVES[101] = { { text = "Räuber getötet: 3/8", finished = false } }
check(codes(5) == "notdone:101", "objectives open: " .. codes(5))
check(Blk:Text(Blk:Check(5)[1]):find("Räuber getötet: 3/8", 1, true), "objective text")
-- already turned in
TURNEDIN[200] = true
check(codes(7) == "already:200", "already turned in: " .. codes(7))
TURNEDIN[200] = nil
-- level: needs 50 (I'm 44), overleveled below 10
chain.steps[7].elements[2] = { tag = "xp", level = 50 }
check(codes(7):find("level", 1, true), "needs level 50: " .. codes(7))
check(Blk:Text({ code = "level", arg = 50 }) == "braucht Stufe 50 (du bist " .. MYXP.level .. ")", "level text")
chain.steps[7].elements[2] = { tag = "xp", level = 10, reverseLogic = true }
check(codes(7):find("over", 1, true), "overleveled: " .. codes(7))
chain.steps[7].elements[2] = nil
-- quest log full
QUESTMAX = 3
check(codes(7) == "logfull", "log full: " .. codes(7))
QUESTMAX = 25
-- grey quest in my log
QUESTLOG[#QUESTLOG + 1] = { questID = 200, xp = 100, level = 20, done = false }
ONQUEST[200] = true
check(codes(8):find("grey:200", 1, true), "grey: " .. codes(8))
table.remove(QUESTLOG); ONQUEST[200] = nil
-- the group gets the first reason; the window shows Bob's
RXP.SetStep(6); Blk:Update(); RunTimers()
check(lastSent("Y^") == "Y^2^18^prereq^102^", "sent: " .. tostring(lastSent("Y^")))
T.OnMessage("Y^2^18^prereq^102^", "Bob Beansen")
T.OnMessage("S^2^" .. (T.Mine().id or "") .. "^" .. DE .. "^43-44 Flusslande II^6^10^18", "Bob Beansen")
if not ns.GroupWindow:IsShown() then SlashCmdList.SYNCLINE("") end
ns.GroupWindow:Refresh()
check(TextShown("hängt: erst |cffffd100Das Lager|r abgeben"), "Bob stuck in the window")
check(TextShown("Du: erst |cffffd100Das Lager|r abgeben"), "my own reason in the guide card")
T.OnMessage("Y^2^18", "Bob Beansen")
check(Blk:Get("Bob-Beansen") == nil, "Bob unstuck")
SlashCmdList.SYNCLINE("warum")
check(logHas("erst |cffffd100Das Lager|r abgeben"), "/sl warum")

---------------------------------------------------------------------------
-- Quest progress of the group (same chain)
---------------------------------------------------------------------------
local Pr = ns.Progress
STATE.me = "Leader"
RXP.SetStep(4)                                   -- complete B
ONQUEST[101] = true
OBJECTIVES[101] = { { text = "Räuber getötet: 3/8", numFulfilled = 3, numRequired = 8, finished = false } }
Pr:Scan(); Pr:Send(true); RunTimers()
check(lastSent("O^") == "O^2^101=3/8", "sent: " .. tostring(lastSent("O^")))
T.OnMessage("O^2^101=8/8!", "Bob Beansen")
T.OnMessage("O^2^101=5/8", "Fluffy-Shocks")
check(not Pr:AllDone(101), "not everyone done")
if not ns.GroupWindow:IsShown() then SlashCmdList.SYNCLINE("") end
ns.GroupWindow:Refresh()
check(TextShown("QUESTFORTSCHRITT"), "progress card")
check(TextShown("Bob|r |cff5cd97a8/8") and TextShown("Fluffy|r |cffffffff5/8"), "everyone's progress")
-- everyone done: said once
OBJECTIVES[101] = { { numFulfilled = 8, numRequired = 8, finished = true } }
COMPLETE[101] = true
Pr:Scan()
local nlog2 = #LOG
T.OnMessage("O^2^101=8/8!", "Fluffy-Shocks")
T.OnMessage("O^2^101=8/8!", "Fluffy-Shocks")
local done = 0 for i = nlog2 + 1, #LOG do if LOG[i]:find("Alle sind fertig mit Die Spur der Räuber", 1, true) then done = done + 1 end end
check(done == 1 and SOUNDS[#SOUNDS] == 1, "everyone done, once, with a sound: " .. done)
COMPLETE[101] = nil; OBJECTIVES[101] = nil

---------------------------------------------------------------------------
-- Group step (same chain)
---------------------------------------------------------------------------
chain.steps[6].group = true
RXP.SetStep(6)
T.OnMessage("H^2^103", "Bob Beansen")         -- Bob lacks D
T.OnMessage("H^2^", "Fluffy-Shocks")          -- Fluffy has everything
RANGE.party2 = false                          -- but is far away
local gc = Pr:GroupCheck(ns.Snapshot())
local byName = {} for _, c in ipairs(gc) do byName[c.name] = c end
check(byName.Bob and byName.Bob.lacks[1] == 103 and not byName.Bob.far, "Bob lacks the quest")
check(byName.Fluffy and #byName.Fluffy.lacks == 0 and byName.Fluffy.far, "Fluffy is far")
ns.GroupWindow:Refresh()
check(TextShown("fehlt Der Anführer") and TextShown("nicht in Reichweite"), "group step in the window")
RANGE.party2 = true
T.OnMessage("H^2^", "Bob Beansen")
check(#Pr:GroupCheck(ns.Snapshot()) == 0, "everyone ready")
ns.GroupWindow:Refresh()
check(TextShown("alle haben die Quest und sind in der Nähe"), "all set line")
chain.steps[6].group = nil
-- not a group step: no check
check(Pr:GroupCheck(ns.Snapshot()) == nil, "no group step, no check")

---------------------------------------------------------------------------
-- Accept check: the leader hears once
---------------------------------------------------------------------------
local nlog3 = #LOG
T.OnMessage("M^2^1^101!", "Bob Beansen")
T.OnMessage("M^2^1^101!", "Bob Beansen")
local heard = 0 for i = nlog3 + 1, #LOG do if LOG[i]:find("Bob hat Die Spur der Räuber nicht angenommen", 1, true) then heard = heard + 1 end end
check(heard == 1, "leader told once: " .. heard)
ns.GroupWindow:Refresh()
check(TextShown("nicht angenommen: Die Spur der Räuber"), "window marks it")
T.OnMessage("M^2^0^", "Bob Beansen")

---------------------------------------------------------------------------
-- Hearthstone and flight paths (same chain)
---------------------------------------------------------------------------
local Tr = ns.Travel
chain.steps[9].elements[2] = { tag = "hs", text = "Hearth to Goldhain" }
chain.steps[9].elements[3] = { tag = "bindlocation", location = "Goldhain", flags = 0 }
chain.steps[10].elements[2] = { tag = "fly", location = "SENTINEL HILL" }
chain.steps[10].elements[3] = { tag = "fly", location = "CROSSROADS" }
RXP.SetStep(8)
HEARTH = { NOW - 100, 3600 }                  -- 3500 s left
local tm = Tr:Scan()
check(tm.hsIn == 1 and tm.bindOk == false and tm.bind == "Orgrimmar", "hearth soon, set elsewhere")
check(#tm.fps == 1 and tm.fps[1] == 12, "lacks Sentinel Hill, knows Crossroads")
Tr:Send(true); RunTimers()
check(lastSent("Z^") == "Z^2^3540^1^0^Orgrimmar^12", "sent: " .. tostring(lastSent("Z^")))
BIND = "Goldhain"
check(Tr:Scan().bindOk == true, "set right")
T.OnMessage("Z^2^600^1^1^Goldhain^", "Bob Beansen")
ns.GroupWindow:Refresh()
check(TextShown("RUHESTEIN UND FLUGPUNKTE"), "travel card")
check(TextShown("Flugpunkt fehlt: Sentinel Hill"), "my missing flight path")
check(TextShown("Ruhestein: |cfff2b84d10 Min."), "Bob's cooldown")
HEARTH = { 0, 0 }; BIND = "Orgrimmar"
for i = 2, 3 do chain.steps[9].elements[i] = nil; chain.steps[10].elements[i] = nil end
RXP.SetStep(6)

---------------------------------------------------------------------------
-- Share quests
---------------------------------------------------------------------------
local Sh = ns.Share
-- what my guide still wants: from step 6 on, not in the log, not turned in
ONQUEST[101] = nil
check(table.concat(Sh:Scan(), ",") == "103,200", "my wanted: " .. table.concat(Sh:Scan(), ","))
Sh:Send(true); RunTimers()
check(lastSent("H^") == "H^2^103,200", "sent: " .. tostring(lastSent("H^")))
-- Bob wants 1 and 3 (both in my log, 3 not shareable)
QUESTLOG[4].pushable = false
T.OnMessage("H^2^1,3,999", "Bob Beansen")
T.OnMessage("H^2^1", "Fluffy-Shocks")
local offers = Sh:Offers()
check(#offers == 1 and offers[1].quest == 1 and offers[1].who[1] == "Bob" and offers[1].who[2] == "Fluffy", "offers: " .. #offers)
ns.GroupWindow:Refresh()
check(TextShown("QUESTS TEILEN") and TextShown("für Bob, Fluffy"), "share card")
wipe(PUSHED)
Sh:ShareQuest(1); RunTimers()
check(PUSHED[1] == 1 and logHas("mit der Gruppe geteilt (für Bob, Fluffy)"), "shared with a click")
wipe(PUSHED)
SlashCmdList.SYNCLINE("teilen"); RunTimers()
check(PUSHED[1] == 1, "/sl teilen shares all")
-- autoshare: shares what comes in, not twice in a minute
wipe(PUSHED); NOW = NOW + 61
SlashCmdList.SYNCLINE("autoteilen"); RunTimers()
check(ns.db.autoShare and logHas("Autoteilen an"), "autoshare on")
check(PUSHED[1] == 1, "autoshare shares")
T.OnMessage("H^2^1", "Bob Beansen"); RunTimers()
check(#PUSHED == 1, "not again within a minute")
NOW = NOW + 61
T.OnMessage("H^2^1", "Bob Beansen"); RunTimers()
check(#PUSHED == 2, "again after a minute")
STATE.combat = true; NOW = NOW + 61
T.OnMessage("H^2^1", "Bob Beansen"); RunTimers()
check(#PUSHED == 2, "not in combat")
STATE.combat = false
SlashCmdList.SYNCLINE("autoteilen aus")
check(not ns.db.autoShare, "autoshare off")
QUESTLOG[4].pushable = nil
SlashCmdList.SYNCLINE("")

RXP:LoadGuide(GUIDES["RestedXP Horde Magier AoE||12-17 Das Brachland AoE"]); RunTimers()

---------------------------------------------------------------------------
-- Slack meter (leader only)
---------------------------------------------------------------------------
local Slack = ns.Slack
Slack:Reset()
RXP.SetStep(10); RunTimers()                     -- leader at line 30
local function behind(name, step, line) T.OnMessage("T^2^" .. step .. "^20^" .. line, name) end
T.OnMessage("S^2^" .. MAGE .. "^^^7^20^21", "Bob Beansen")     -- Bob 3 behind
T.OnMessage("S^2^" .. MAGE .. "^^^10^20^30", "Fluffy-Shocks")  -- Fluffy with me
for _ = 1, 5 do Slack:Tick() end
local rank = Slack:Ranking()
check(rank[1].name == "Bob" and rank[1].waited == 10, "Bob waited 10 s: " .. rank[1].name .. " " .. rank[1].waited)
check(rank[2].name == "Fluffy" and rank[2].waited == 0, "Fluffy didn't keep anyone waiting")
-- paused: leader in combat, leader AFK, Bob offline
STATE.combat = true; Slack:Tick(); STATE.combat = false
AFK = true; Slack:Tick(); AFK = false
OFFLINE.party1 = true; Slack:Tick(); OFFLINE.party1 = nil
check(Slack:Ranking()[1].waited == 10, "combat, AFK, offline don't count")
-- Bob catches up: no more waiting, steps counted
behind("Bob Beansen", 10, 30); Slack:Tick(); Slack:Tick()
rank = Slack:Ranking()
check(rank[1].waited == 10 and rank[1].perStep, "caught up: waiting stops, per step known")
-- titles
ns.db.slack.members.Bob.waited = 11 * 60
check(Slack:Title(11 * 60) == "Tourist" and Slack:Title(31 * 60) == "Schnecke der Session" and Slack:Title(60) == nil, "titles")
local lines = Slack:ChatLines()
check(lines[2] == "1. Bob 11:00 – Tourist", "chat line: " .. tostring(lines[2]))
Slack:Post()
check(CHAT[1] and CHAT[1]:find("^PARTY: Syncline Bummel%-Meter") and CHAT[2] == "PARTY: 1. Bob 11:00 – Tourist", "posted: " .. tostring(CHAT[2]))
-- the window shows it, for the leader only
if not ns.GroupWindow:IsShown() then SlashCmdList.SYNCLINE("") end
ns.GroupWindow:Refresh()
check(TextShown("BUMMEL-METER"), "window card title"); check(TextShown("11:00"), "window card time")
-- a member: nothing counted
STATE.me = "Me"
local before = ns.db.slack.members.Bob.waited
behind("Bob Beansen", 5, 15); Slack:Tick()
check(ns.db.slack.members.Bob.waited == before, "members don't count")
STATE.me = "Leader"
-- switched off
ns.db.slackMeter = false; behind("Bob Beansen", 5, 15); Slack:Tick()
check(ns.db.slack.members.Bob.waited == before, "switched off")
ns.db.slackMeter = true
-- out of the group for a minute: new session
STATE.group = false; Slack:Tick(); NOW = NOW + 61; Slack:Tick()
check(next(ns.db.slack.members) == nil, "reset after leaving the group")
NOW = NOW + 1; STATE.group = true; Fire("GROUP_ROSTER_UPDATE"); RunTimers()
SlashCmdList.SYNCLINE("")   -- close the window again

---------------------------------------------------------------------------
-- Experience overview
---------------------------------------------------------------------------
local XP = ns.XP
local me = XP:Mine()
check(me.level == 43 and me.xp == 3000 and me.max == 10000 and me.rested == 1500, "my experience")
check(me.ready == 1200 and me.all == 2100, "quest xp: ready " .. me.ready .. ", all " .. me.all)
check(me.rate == nil, "no rate without data")
-- 30 minutes: 3000 -> 9500, then 500 to the level-up and 500 after it = 7500 xp
XP:Sample()
NOW = NOW + 600; MYXP.xp = 6000; XP:Sample()
NOW = NOW + 600; MYXP.xp = 9500; XP:Sample()
NOW = NOW + 600; MYXP.level, MYXP.xp, MYXP.max = 44, 500, 11000; XP:Sample()   -- +500 to the level-up, +500 after
me = XP:Mine()
check(math.floor(me.rate + 0.5) == 15000, "15000 xp per hour: " .. tostring(me.rate))
local missing, t, after, t2 = XP:Times(me)
check(missing == 10500 and after == 10500 - 1200, "missing and after turning in")
check(math.floor(t / 60 + 0.5) == 42, "level-up in about 42 min: " .. t / 60)
XP:Send(); RunTimers()
check(lastSent("X^") == "X^2^44^500^11000^1500^15000^1200^2100", "sent: " .. tostring(lastSent("X^")))
-- Bob: ready quests are enough for his level-up
T.OnMessage("X^2^43^9000^10000^0^6500^1500^2000", "Bob Beansen")
local bobxp = XP:Get("Bob-Beansen")
check(bobxp and bobxp.level == 43 and bobxp.rate == 6500, "Bob's experience")
local _, _, bobAfter = XP:Times(bobxp)
check(bobAfter == 0, "Bob levels by turning in")
-- the window
if not ns.GroupWindow:IsShown() then SlashCmdList.SYNCLINE("") end
ns.GroupWindow:Refresh()
check(TextShown("ERFAHRUNG"), "experience card")
check(TextShown("fehlt 10.5k") and TextShown("abgeben!"), "my missing xp and Bob's hint")
check(TextShown("15k/h"), "rate shown")
check(XP.Short(1200) == "1.2k" and XP.Short(950) == "950" and XP.Short(250000) == "250k" and XP.Short(2000) == "2k", "short numbers")
-- max level
T.OnMessage("X^2^60^0^0^0^^0^0", "Fluffy-Shocks")
ns.GroupWindow:Refresh()
check(TextShown("Höchststufe"), "max level")
-- switched off
ns.db.xpOverview = false; ns.GroupWindow:Refresh(); ns.db.xpOverview = true
SlashCmdList.SYNCLINE("")

-- the windows
SlashCmdList.SYNCLINE(""); RunTimers()
check(SynclineGroupFrame:IsShown(), "/sl opens the group window")
check(TextShown("12-17 Das Brachland AoE"), "window shows the group guide")
check(TextShown("Schritt skippen") and TextShown("Alle zu mir") and TextShown("Guide senden"), "leader buttons (German)")
check(TextShown("Schritt des Leiters"), "leader's step in the window")
-- (Bob is in another guide right now: that shows first; settings show when the guide is the same)
check(TextShown("Bob"), "window lists Bob")
-- the window follows changes
T.OnMessage("S^2^" .. D1 .. "^" .. EN .. "^01-06 Durotar", "Bob-Beansen"); RunTimers()
check(TextShown("anderer Guide: 01-06 Durotar"), "window updates")
T.OnMessage("S^2^" .. MAGE .. "^^^1^20", "Bob-Beansen"); RunTimers()
check(TextShown("Einstellungen anders"), "same guide, other settings: marked")

-- views of the group window
local GW = ns.GroupWindow
local function CardOf(key) for _, c in ipairs(GW.cards) do if c.key == key then return c.card end end end
check(GW:View("Leader") == "full" and GW:View("Member") == "compact", "default views")
check(GW.frames.members:IsShown() and not GW.frames.summary:IsShown(), "full: the member list")
check(TextShown("Ansicht: Komplett"), "view button")
GW:SetView("Leader", "compact")
check(GW.frames.summary:IsShown() and not GW.frames.members:IsShown(), "compact: the overview instead of the list")
check(TextShown("GRUPPE AUF EINEN BLICK") and TextShown("Bob|r: ") and TextShown("Einstellungen anders"), "overview names Bob's problem")
check(not CardOf("xp"):IsShown(), "compact: no experience card")
check(GW.buttons.skip:IsShown() and not GW.buttons.send:IsShown(), "compact leader: skip and pull, no send when nobody strayed")
check(TextShown("Ansicht: Kompakt"), "view button follows")
-- one section on: custom, starting from compact
GW:SetSection("Leader", "xp", true)
check(GW:View("Leader") == "custom" and GW:Shows("xp", "Leader") and GW:Shows("summary", "Leader")
    and not GW:Shows("members", "Leader"), "custom view from compact")
check(GW:View("Member") == "compact", "member view untouched")
-- the menu
GW:ToggleMenu()
check(TextShown("ANSICHT ALS LEITER") and TextShown("Mitgliederliste"), "view menu")
GW:ToggleMenu()
-- fold a card
GW:Fold("summary", true)
check(GW.frames.summary.sign:GetText() == "+" and GW:IsFolded("summary"), "folded")
GW:Fold("summary", false)
check(GW.frames.summary.sign:GetText() == "–", "unfolded")
GW:SetView("Leader", "full")
check(GW.frames.members:IsShown() and GW.buttons.send:IsShown(), "back to full")
-- members: only what fits right now, only their own problems
local B = GW:Buttons({ inGroup = true, isLeader = false, target = "X", inTarget = true, members = {} })
check(#B == 1 and B[1] == "request", "member in the guide: request skip")
B = GW:Buttons({ inGroup = true, isLeader = false, target = "X", inTarget = false, members = {} })
check(B[1] == "get" and B[2] == "suggest", "member elsewhere: get guide")
local iss = GW:Issues({ inGroup = true, isLeader = false, members = {
    { name = "Me", me = true, state = "same", diff = -3 },
    { name = "Bob", state = "other", guide = "Y" } } })
check(#iss == 1 and iss[1].text:find("du bist 3 Schritt(e) hinter dem Leiter", 1, true), "member sees only their own: " .. tostring(iss[1] and iss[1].text))
iss = GW:Issues({ inGroup = true, isLeader = true, members = {
    { name = "Leader", me = true, lead = true, state = "same" },
    { name = "Bob", state = "other", guide = "Y" }, { name = "Dani", state = "same", diff = -2 } } })
check(#iss == 2 and iss[1].text:find("anderer Guide: Y", 1, true) and iss[2].text:find("2 Schritt(e) zurück", 1, true), "leader sees everyone's, worst first")
ns.HandleClick("LeftButton")
check(not SynclineGroupFrame:IsShown(), "left click closes it again")
ns.HandleClick("RightButton")
check(SynclineOptionsFrame:IsShown(), "right click: settings")
check(TextShown("Ansicht als Mitglied") and TextShown("Kompakt"), "views in the settings")
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
