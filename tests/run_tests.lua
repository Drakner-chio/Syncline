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
RXP:LoadGuide(GUIDES["RestedXP Horde Magier AoE||12-17 Das Brachland AoE"]); RunTimers()

-- the windows
SlashCmdList.SYNCLINE(""); RunTimers()
check(SynclineGroupFrame:IsShown(), "/sl opens the group window")
check(TextShown("06-10 Durotar"), "window shows the group guide")
check(TextShown("Schritt skippen") and TextShown("Alle zu mir") and TextShown("Guide senden"), "leader buttons (German)")
check(TextShown("Schritt des Leiters"), "leader's step in the window")
-- (Bob is in another guide right now: that shows first; settings show when the guide is the same)
check(TextShown("Bob"), "window lists Bob")
-- the window follows changes
T.OnMessage("S^2^" .. D1 .. "^" .. EN .. "^01-06 Durotar", "Bob-Beansen"); RunTimers()
check(TextShown("anderer Guide: 01-06 Durotar"), "window updates")
T.OnMessage("S^2^" .. MAGE .. "^^^1^20", "Bob-Beansen"); RunTimers()
check(TextShown("Einstellungen anders"), "same guide, other settings: marked")
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
