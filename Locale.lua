-- Syncline: texts. English by default, German when the client is German.
local ADDON, ns = ...

local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

L.LOADED = "loaded. The group leader's RestedXP guide is now synced. /sl for help."
L.NO_RXP = "RestedXP Guides is not loaded, Syncline does nothing."
L.SENT = "Sent guide to the group: %s"
L.SWITCHED = "%s picked |cffffd100%s|r, guide loaded."
L.SWITCH_LATER = "%s picked |cffffd100%s|r, loading it after combat."
L.MISSING = "%s picked |cffffd100%s|r, but that guide doesn't exist here (other faction, or guide pack missing)."
L.NOT_LOADED = "RestedXP didn't load |cffffd100%s|r (maybe not available for your class, faction or level)."
L.LEFT_GROUP_GUIDE = "You left the group guide. |cffffd100/sl get|r brings you back."
L.ASK = "%s (group leader) picked the guide\n\n%s\n\nSwitch to it?"
L.YES = "Switch"
L.NO = "Not now"
L.NOT_LEADER = "Only the group leader can send the guide."
L.NOT_IN_GROUP = "You're not in a group."
L.NO_GUIDE = "You have no guide loaded."
L.STATUS_HEAD = "Group guide: |cffffd100%s|r"
L.STATUS_NONE = "Group guide: none yet"
L.STATUS_SAME = "same guide"
L.STATUS_OTHER = "other guide: %s"
L.STATUS_UNKNOWN = "no Syncline"
L.STATUS_LEADER = "leader"
L.STATUS_OLD = "old Syncline, please update"
L.STATUS_NEWER = "newer Syncline, please update yours"
L.ON = "Sync on."
L.OFF = "Sync off: you keep your own guide."
L.MODE_AUTO = "Switch automatically when the leader picks a guide."
L.MODE_ASK = "Ask before switching."
L.CMD_OPTIONS = "options"
L.CMD_SKIP, L.CMD_PULL = "skip", "pull"
L.CMD_ROUTE = "route"
L.CMD_MISSING = "missing"
L.CMD_AUTOSHARE, L.CMD_SHARE, L.CMD_WHY = "autoshare", "share", "why"
L.BLOCK_PREREQ = "turn in |cffffd100%s|r first"
L.BLOCK_PREREQ_AT = "turn in |cffffd100%s|r first (step %d)"
L.BLOCK_LEVEL = "needs level %d (you're %d)"
L.BLOCK_LEVEL_OTHER = "needs level %d"
L.BLOCK_OVER = "only below level %d: overleveled, RestedXP skips it"
L.BLOCK_GREY = "|cffffd100%s|r is grey: hardly any experience"
L.BLOCK_ALREADY = "|cffffd100%s|r is already turned in"
L.BLOCK_LOGFULL = "quest log full (%d)"
L.BLOCK_NOTINLOG = "|cffffd100%s|r isn't in the quest log"
L.BLOCK_NOTDONE = "|cffffd100%s|r: objectives still open"
L.BLOCK_NOTDONE_AT = "|cffffd100%s|r: %s"
L.BLOCK_NONE = "Nothing in the way: the step can be done."
L.SHARED = "Shared |cffffd100%s|r with the group (for %s)."
L.SHARE_NOTHING = "Nobody needs a quest from your log right now."
L.AUTOSHARE_ON = "Autoshare on: quests the others need are shared by themselves."
L.AUTOSHARE_OFF = "Autoshare off."
L.ALL_DONE = "Everyone is done with %s – off to turn it in!"
L.ACCEPT_FORGOT = "You didn't accept %s (step %d)! Your guide still needs it."
L.ACCEPT_FORGOT_OTHER = "%s didn't accept %s."
L.ACCEPT_FORGOT_SHORT = "%s (not accepted at step %d)"
L.MISSING_TURNIN = "turn-in"
L.MISSING_COMPLETE = "objectives"
L.MISSING_ENTRY = "%s (%s at step %d)"
L.MISSING_AT = "%s at step %d"
L.MISSING_NEW = "Your guide still needs |cffffd100%s|r, but the quest is no longer in your log."
L.MISSING_NONE = "No missing quests: your log has everything your guide still needs."
L.MISSING_HEAD = "%d quest(s) your guide still needs, not in your log:"
L.MISSING_TIP_HEAD = "%s is missing"
L.MISSING_TIP_HINT = "The guide still wants these later. Pick them up again, or have someone share them."
L.ABANDON_WARN = "Careful: your RestedXP guide still needs\n\n%s\n\nlater (%s). If you abandon it, it will be missing there."
L.RISK_NONE = "no quest in it: safe to skip"
L.RISK_SAFE = "safe to skip: no follow-up quests"
L.RISK_FOLLOWUPS = "%d follow-up quest(s): %s"
L.RISK_QUESTS = "Quests in this step: %s"
L.RISK_LATER = "%d later steps belong to them"
L.RISK_CONFIRM = "Skip %s for everyone?\n\n%s\n\nThey would be gone for the whole group."
L.ROUTE_TAKEN = "Took %s's RestedXP route settings: %s."
L.ROUTE_ASK = "%s (group leader) has other RestedXP route settings:\n\n%s\n\nTake them, so everyone has the same steps?"
L.ROUTE_SENT = "Sent your RestedXP route settings to the group."
L.ROUTE_DIFFERS = "other settings: %s"
L.STEP_N = "step %d"
L.STEP_WITH_TEXT = "step %d (%s)"
L.STEP_OF = "step %d/%d"
L.SKIPPED_SENT = "Skipped %s for the group."
L.PULL_SENT = "Everyone in your guide goes to %s."
L.SKIP_REQUEST_SENT = "Asked the leader to skip %s."
L.SKIPPED_ELSEWHERE = "%s skipped %s for the group, you're at step %d: nothing to do."
L.SKIPPED_BY_LEADER = "%s skipped %s for the group."
L.PULLED_BY_LEADER = "%s brings the group to %s."
L.OK_QUESTION = "Go along?"
L.YES_STEP = "OK"
L.SKIP_FOR_GROUP = "Skip for everyone"
L.SKIP_REQUEST_INFO = "%s asks the leader to skip %s."
L.SKIP_REQUEST_ASK = "%s asks to skip\n\n%s\n\nSkip it for the whole group?"
L.SKIP_DECLINED = "%s (leader) doesn't skip the step."
L.HELP = {
    "|cffffd100/sl|r  group window: who is in which guide",
    "|cffffd100/sl status|r  the same in the chat",
    "|cffffd100/sl options|r  settings",
    "|cffffd100/sl minimap|r  show or hide the minimap button",
    "|cffffd100/sl send|r  (leader) send my guide to everyone again",
    "|cffffd100/sl get|r  load the leader's guide",
    "|cffffd100/sl suggest|r  suggest my guide to the leader",
    "|cffffd100/sl skip|r  leader: skip the step for everyone, others: ask the leader",
    "|cffffd100/sl pull|r  leader: everyone in the guide to my step",
    "|cffffd100/sl route|r  leader: send my RestedXP route settings (dungeons, ...) again",
    "|cffffd100/sl missing|r  quests your guide still needs that aren't in your log",
    "|cffffd100/sl why|r  why the step you're at can't be done yet",
    "|cffffd100/sl share|r  share the quests the others need",
    "|cffffd100/sl autoshare|r  share them automatically (on/off)",
    "|cffffd100/sl auto|r / |cffffd100ask|r  switch on my own / ask first",
    "|cffffd100/sl on|r / |cffffd100off|r  sync on or off",
}
L.CMD_SEND, L.CMD_GET, L.CMD_AUTO, L.CMD_ASK, L.CMD_ON, L.CMD_OFF, L.CMD_HELP =
    "send", "get", "auto", "ask", "on", "off", "help"
L.CMD_SUGGEST = "suggest"
L.SUGGEST = "Suggest"
L.TAKE = "Take it"
L.SUGGEST_SENT = "Suggested to the leader: |cffffd100%s|r"
L.SUGGEST_ASK = "%s suggests the guide\n\n%s\n\nTake it for the whole group?"
L.SUGGESTED_INFO = "%s suggests |cffffd100%s|r to the leader."
L.OFFER_ASK = "You picked\n\n%s\n\nSuggest it to the group leader?"
L.TAKEN = "Took %s's suggestion |cffffd100%s|r."
L.TAKE_LATER = "Taking %s's suggestion |cffffd100%s|r after combat."
L.DECLINED = "%s (leader) stays in the current guide."

if GetLocale() == "deDE" then
    L.LOADED = "geladen. Der RestedXP-Guide des Gruppenleiters wird jetzt gesynct. /sl hilfe"
    L.NO_RXP = "RestedXP Guides ist nicht geladen, Syncline macht nichts."
    L.SENT = "Guide an die Gruppe geschickt: %s"
    L.SWITCHED = "%s hat |cffffd100%s|r gewählt, Guide geladen."
    L.SWITCH_LATER = "%s hat |cffffd100%s|r gewählt, wird nach dem Kampf geladen."
    L.MISSING = "%s hat |cffffd100%s|r gewählt, aber den Guide gibt es bei dir nicht (andere Fraktion oder Guide-Paket fehlt)."
    L.NOT_LOADED = "RestedXP hat |cffffd100%s|r nicht geladen (evtl. nicht für deine Klasse, Fraktion oder dein Level)."
    L.LEFT_GROUP_GUIDE = "Du bist nicht mehr im Gruppen-Guide. |cffffd100/sl holen|r bringt dich zurück."
    L.ASK = "%s (Gruppenleiter) hat den Guide\n\n%s\n\ngewählt. Wechseln?"
    L.YES = "Wechseln"
    L.NO = "Jetzt nicht"
    L.NOT_LEADER = "Nur der Gruppenleiter kann den Guide schicken."
    L.NOT_IN_GROUP = "Du bist in keiner Gruppe."
    L.NO_GUIDE = "Du hast keinen Guide geladen."
    L.STATUS_HEAD = "Gruppen-Guide: |cffffd100%s|r"
    L.STATUS_NONE = "Gruppen-Guide: noch keiner"
    L.STATUS_SAME = "gleicher Guide"
    L.STATUS_OTHER = "anderer Guide: %s"
    L.STATUS_UNKNOWN = "kein Syncline"
    L.STATUS_LEADER = "Leiter"
    L.STATUS_OLD = "alte Syncline-Version, bitte updaten"
    L.STATUS_NEWER = "neuere Syncline-Version, bitte deine updaten"
    L.ON = "Sync an."
    L.OFF = "Sync aus: du behältst deinen eigenen Guide."
    L.MODE_AUTO = "Automatisch wechseln, wenn der Leiter einen Guide wählt."
    L.MODE_ASK = "Vor dem Wechseln fragen."
    L.CMD_OPTIONS = "optionen"
    L.CMD_SKIP, L.CMD_PULL = "skippen", "herholen"
    L.CMD_ROUTE = "route"
    L.CMD_MISSING = "fehlend"
    L.CMD_AUTOSHARE, L.CMD_SHARE, L.CMD_WHY = "autoteilen", "teilen", "warum"
    L.BLOCK_PREREQ = "erst |cffffd100%s|r abgeben"
    L.BLOCK_PREREQ_AT = "erst |cffffd100%s|r abgeben (Schritt %d)"
    L.BLOCK_LEVEL = "braucht Stufe %d (du bist %d)"
    L.BLOCK_LEVEL_OTHER = "braucht Stufe %d"
    L.BLOCK_OVER = "nur unter Stufe %d: überlevelt, RestedXP überspringt ihn"
    L.BLOCK_GREY = "|cffffd100%s|r ist grau: kaum noch EP"
    L.BLOCK_ALREADY = "|cffffd100%s|r ist schon abgegeben"
    L.BLOCK_LOGFULL = "Questlog voll (%d)"
    L.BLOCK_NOTINLOG = "|cffffd100%s|r ist nicht im Questlog"
    L.BLOCK_NOTDONE = "|cffffd100%s|r: Ziele noch offen"
    L.BLOCK_NOTDONE_AT = "|cffffd100%s|r: %s"
    L.BLOCK_NONE = "Nichts im Weg: Der Schritt ist machbar."
    L.SHARED = "|cffffd100%s|r mit der Gruppe geteilt (für %s)."
    L.SHARE_NOTHING = "Gerade braucht niemand eine Quest aus deinem Log."
    L.AUTOSHARE_ON = "Autoteilen an: Quests, die den anderen fehlen, werden von selbst geteilt."
    L.AUTOSHARE_OFF = "Autoteilen aus."
    L.ALL_DONE = "Alle sind fertig mit %s – ab zur Abgabe!"
    L.ACCEPT_FORGOT = "Du hast %s nicht angenommen (Schritt %d)! Dein Guide braucht sie noch."
    L.ACCEPT_FORGOT_OTHER = "%s hat %s nicht angenommen."
    L.ACCEPT_FORGOT_SHORT = "%s (bei Schritt %d nicht angenommen)"
    L.MISSING_TURNIN = "Abgabe"
    L.MISSING_COMPLETE = "Ziele"
    L.MISSING_ENTRY = "%s (%s bei Schritt %d)"
    L.MISSING_AT = "%s bei Schritt %d"
    L.MISSING_NEW = "Dein Guide braucht später noch |cffffd100%s|r, die Quest ist aber nicht mehr in deinem Log."
    L.MISSING_NONE = "Keine fehlenden Quests: Dein Log hat alles, was dein Guide noch braucht."
    L.MISSING_HEAD = "%d Quest(s), die dein Guide noch braucht, fehlen im Log:"
    L.MISSING_TIP_HEAD = "%s fehlen"
    L.MISSING_TIP_HINT = "Der Guide will diese später noch. Neu annehmen oder von jemandem teilen lassen."
    L.ABANDON_WARN = "Achtung: Dein RestedXP-Guide braucht\n\n%s\n\nspäter noch (%s). Wenn du sie abbrichst, fehlt sie dir dort."
    L.RISK_NONE = "keine Quest darin: sicher zu skippen"
    L.RISK_SAFE = "sicher zu skippen: keine Folgequests"
    L.RISK_FOLLOWUPS = "%d Folgequest(s): %s"
    L.RISK_QUESTS = "Quests in diesem Schritt: %s"
    L.RISK_LATER = "%d spätere Schritte hängen daran"
    L.RISK_CONFIRM = "%s für alle überspringen?\n\n%s\n\nDie fielen für die ganze Gruppe weg."
    L.ROUTE_TAKEN = "RestedXP-Routeneinstellungen von %s übernommen: %s."
    L.ROUTE_ASK = "%s (Gruppenleiter) hat andere RestedXP-Routeneinstellungen:\n\n%s\n\nÜbernehmen, damit alle die gleichen Schritte haben?"
    L.ROUTE_SENT = "Deine RestedXP-Routeneinstellungen an die Gruppe geschickt."
    L.ROUTE_DIFFERS = "andere Einstellungen: %s"
    L.STEP_N = "Schritt %d"
    L.STEP_WITH_TEXT = "Schritt %d (%s)"
    L.STEP_OF = "Schritt %d/%d"
    L.SKIPPED_SENT = "%s für die Gruppe übersprungen."
    L.PULL_SENT = "Alle in deinem Guide gehen zu %s."
    L.SKIP_REQUEST_SENT = "Beim Leiter angefragt, %s zu überspringen."
    L.SKIPPED_ELSEWHERE = "%s hat %s für die Gruppe übersprungen, du bist bei Schritt %d: nichts zu tun."
    L.SKIPPED_BY_LEADER = "%s hat %s für die Gruppe übersprungen."
    L.PULLED_BY_LEADER = "%s holt die Gruppe zu %s."
    L.OK_QUESTION = "Mitgehen?"
    L.YES_STEP = "OK"
    L.SKIP_FOR_GROUP = "Für alle überspringen"
    L.SKIP_REQUEST_INFO = "%s fragt beim Leiter an, %s zu überspringen."
    L.SKIP_REQUEST_ASK = "%s möchte\n\n%s\n\nüberspringen. Für die ganze Gruppe überspringen?"
    L.SKIP_DECLINED = "%s (Leiter) überspringt den Schritt nicht."
    L.HELP = {
        "|cffffd100/sl|r  Gruppenfenster: wer ist in welchem Guide",
        "|cffffd100/sl status|r  das Gleiche im Chat",
        "|cffffd100/sl optionen|r  Einstellungen",
        "|cffffd100/sl minimap|r  Minimap-Knopf zeigen oder verstecken",
        "|cffffd100/sl senden|r  (Leiter) meinen Guide nochmal an alle schicken",
        "|cffffd100/sl holen|r  den Guide des Leiters laden",
        "|cffffd100/sl vorschlagen|r  meinen Guide dem Leiter vorschlagen",
        "|cffffd100/sl skippen|r  Leiter: Schritt für alle überspringen, sonst: beim Leiter anfragen",
        "|cffffd100/sl herholen|r  Leiter: alle im Guide zu meinem Schritt holen",
        "|cffffd100/sl route|r  Leiter: meine RestedXP-Routeneinstellungen (Dungeons, ...) nochmal senden",
        "|cffffd100/sl fehlend|r  Quests, die dein Guide noch braucht, die aber nicht im Log sind",
        "|cffffd100/sl warum|r  warum der aktuelle Schritt noch nicht geht",
        "|cffffd100/sl teilen|r  Quests teilen, die den anderen fehlen",
        "|cffffd100/sl autoteilen|r  automatisch teilen (an/aus)",
        "|cffffd100/sl auto|r / |cffffd100fragen|r  selbst wechseln / vorher fragen",
        "|cffffd100/sl an|r / |cffffd100aus|r  Sync an oder aus",
    }
    L.CMD_SEND, L.CMD_GET, L.CMD_AUTO, L.CMD_ASK, L.CMD_ON, L.CMD_OFF, L.CMD_HELP =
        "senden", "holen", "auto", "fragen", "an", "aus", "hilfe"
    L.CMD_SUGGEST = "vorschlagen"
    L.SUGGEST = "Vorschlagen"
    L.TAKE = "Übernehmen"
    L.SUGGEST_SENT = "Dem Leiter vorgeschlagen: |cffffd100%s|r"
    L.SUGGEST_ASK = "%s schlägt den Guide\n\n%s\n\nvor. Für die ganze Gruppe übernehmen?"
    L.SUGGESTED_INFO = "%s schlägt dem Leiter |cffffd100%s|r vor."
    L.OFFER_ASK = "Du hast\n\n%s\n\ngewählt. Dem Gruppenleiter vorschlagen?"
    L.TAKEN = "Vorschlag von %s übernommen: |cffffd100%s|r."
    L.TAKE_LATER = "Vorschlag von %s (|cffffd100%s|r) wird nach dem Kampf übernommen."
    L.DECLINED = "%s (Leiter) bleibt beim aktuellen Guide."

    -- windows (English text is the key)
    local de = {
        ["Settings"] = "Einstellungen",
        ["Group"] = "Gruppe",
        ["Group guide"] = "Gruppen-Guide",
        ["Who is in which guide"] = "Wer ist in welchem Guide",
        ["none yet"] = "noch keiner",
        ["no guide loaded"] = "kein Guide geladen",
        ["and %d more, /sl status lists everyone"] = "und %d weitere, /sl status zeigt alle",
        ["You're not in a group. As soon as you are, the leader's guide is synced here."] =
            "Du bist in keiner Gruppe. Sobald du in einer bist, wird hier der Guide des Leiters gesynct.",
        ["Send guide again"] = "Guide nochmal senden",
        ["Sends your guide to the whole group once more, e.g. when someone switched away."] =
            "Schickt deinen Guide nochmal an die ganze Gruppe, z. B. wenn jemand gewechselt hat.",
        ["Get leader's guide"] = "Guide des Leiters holen",
        ["Loads the guide the group leader has picked."] = "Lädt den Guide, den der Gruppenleiter gewählt hat.",
        ["Suggest my guide"] = "Meinen Guide vorschlagen",
        ["Suggests the guide you have loaded right now to the group leader. They decide whether the group takes it."] =
            "Schlägt dem Gruppenleiter den Guide vor, den du gerade geladen hast. Er entscheidet, ob die Gruppe ihn übernimmt.",
        ["Sync"] = "Sync",
        ["Follow the group leader's guide"] = "Dem Guide des Gruppenleiters folgen",
        ["When the leader picks a guide"] = "Wenn der Leiter einen Guide wählt",
        ["Switch right away"] = "Sofort wechseln",
        ["Ask me first"] = "Vorher fragen",
        ["Offer to suggest a guide I pick myself"] = "Selbst gewählten Guide zum Vorschlagen anbieten",
        ["Suggest"] = "Vorschlagen",
        ["When you load another guide yourself while in a group, a popup asks whether to suggest it to the leader."] =
            "Wenn du in einer Gruppe selbst einen anderen Guide lädst, fragt ein Popup, ob du ihn dem Leiter vorschlagen willst.",
        ["Group window"] = "Gruppenfenster",
        ["Size"] = "Größe",
        ["Lock windows (no dragging)"] = "Fenster sperren (nicht verschiebbar)",
        ["Reset window positions"] = "Fensterpositionen zurücksetzen",
        ["General"] = "Allgemein",
        ["Minimap button"] = "Minimap-Knopf",
        ["RestedXP Guides: %s"] = "RestedXP Guides: %s",
        ["found"] = "gefunden",
        ["not found"] = "nicht gefunden",
        ["In it"] = "Darin",
        ["Left-click: group window"] = "Linksklick: Gruppenfenster",
        ["Right-click: settings"] = "Rechtsklick: Einstellungen",
        ["Drag: move this button"] = "Ziehen: Knopf verschieben",
        ["The group leader picks a RestedXP guide, everyone in the group follows. All settings are in Syncline's own window."] =
            "Der Gruppenleiter wählt einen RestedXP-Guide, alle in der Gruppe ziehen mit. Alle Einstellungen stehen in Synclines eigenem Fenster.",
        ["Open settings"] = "Einstellungen öffnen",
        ["Leader's step"] = "Schritt des Leiters",
        ["Skip step"] = "Schritt skippen",
        ["Skips the leader's current step for everyone who is at it."] =
            "Überspringt deinen aktuellen Schritt für alle, die gerade bei ihm sind.",
        ["Pull to my step"] = "Alle zu mir",
        ["Everyone in the group guide jumps to your step."] = "Alle im Gruppen-Guide springen zu deinem Schritt.",
        ["Send guide"] = "Guide senden",
        ["Get guide"] = "Guide holen",
        ["Suggest guide"] = "Vorschlagen",
        ["Request skip"] = "Skip anfragen",
        ["Asks the leader to skip your current step for the whole group."] =
            "Fragt beim Leiter an, deinen aktuellen Schritt für die ganze Gruppe zu überspringen.",
        ["Let the leader skip steps and pull me to his step"] = "Leiter darf Schritte überspringen und mich herholen",
        ["When the leader skips a step or pulls the group to his step, you go along (or get asked, see above)."] =
            "Wenn der Leiter einen Schritt überspringt oder die Gruppe zu seinem Schritt holt, gehst du mit (oder wirst gefragt, siehe oben).",
        ["same step"] = "gleicher Schritt",
        ["%d behind"] = "%d zurück",
        ["%d ahead"] = "%d voraus",
        ["Skip step (leader) / request skip"] = "Schritt skippen (Leiter) / Skip anfragen",
        ["EXP rate"] = "EXP-Rate",
        ["Skip overleveled steps"] = "Überlevelte Schritte überspringen",
        ["Group quests"] = "Gruppenquests",
        ["Solo Self Found"] = "Solo Self Found",
        ["Loremaster"] = "Loremaster",
        ["Dungeons"] = "Dungeons",
        ["settings differ"] = "Einstellungen anders",
        ["RestedXP route settings"] = "RestedXP-Routeneinstellungen",
        ["Take the leader's RestedXP route settings"] = "RestedXP-Routeneinstellungen des Leiters übernehmen",
        ["Dungeons, skip overleveled steps, group quests, Solo Self Found and EXP rate decide which steps a guide has. With the leader's settings everyone has the same steps."] =
            "Dungeons, überlevelte Schritte, Gruppenquests, Solo Self Found und EXP-Rate bestimmen, welche Schritte ein Guide hat. Mit den Einstellungen des Leiters haben alle die gleichen Schritte.",
        ["As leader: send my route settings to the group"] = "Als Leiter: meine Routeneinstellungen an die Gruppe senden",
        ["Different from the leader:"] = "Anders als beim Leiter:",
        ["Skip check"] = "Skip-Check",
        ["Slack meter"] = "Bummel-Meter",
        ["Experience"] = "Erfahrung",
        ["Level"] = "Stufe",
        ["Missing"] = "Fehlt",
        ["Rested"] = "Ruhe-EP",
        ["Ready to turn in"] = "Abgabebereit",
        ["All quests in the log"] = "Alle Quests im Log",
        ["Per hour"] = "Pro Stunde",
        ["measuring ..."] = "wird gemessen …",
        ["no experience in the last 30 min"] = "keine EP in den letzten 30 Min.",
        ["Turning in the ready quests is enough for the level-up!"] = "Die abgabebereiten Quests reichen für den Level-Up!",
        ["Level-up in"] = "Level-Up in",
        ["After turning in"] = "Nach den Abgaben",
        ["%s missing"] = "fehlt %s",
        ["/h"] = "/h",
        ["turn in!"] = "abgeben!",
        ["max level"] = "Höchststufe",
        ["Nobody sent experience yet (everyone needs Syncline)."] = "Noch keine EP-Daten (alle brauchen Syncline).",
        ["Experience overview of the group"] = "EP-Übersicht der Gruppe",
        ["Missing quests"] = "Fehlende Quests",
        ["Why the step can't be done yet"] = "Warum der Schritt noch nicht geht",
        ["stuck"] = "hängt",
        ["You"] = "Du",
        ["Share quests"] = "Quests teilen",
        ["Share all"] = "Alle teilen",
        ["Share"] = "Teilen",
        ["for %s"] = "für %s",
        ["auto"] = "automatisch",
        ["Show why a step can't be done yet"] = "Zeigen, warum ein Schritt noch nicht geht",
        ["Show quests I can share"] = "Quests zeigen, die ich teilen kann",
        ["Share them automatically (/sl autoshare)"] = "Automatisch teilen (/sl autoteilen)",
        ["not accepted"] = "nicht angenommen",
        ["Quest progress"] = "Questfortschritt",
        ["Group step"] = "Gruppenschritt",
        ["everyone has the quest and is close"] = "alle haben die Quest und sind in der Nähe",
        ["lacks %s"] = "fehlt %s",
        ["not in range"] = "nicht in Reichweite",
        ["done"] = "fertig",
        ["Hearthstone and flight paths"] = "Ruhestein und Flugpunkte",
        ["ready"] = "bereit",
        ["%d min"] = "%d Min.",
        ["Hearth"] = "Ruhestein",
        ["set to %s"] = "steht auf %s",
        ["lacks flight path %s"] = "Flugpunkt fehlt: %s",
        ["all set"] = "alles bereit",
        ["Quest helpers"] = "Quest-Helfer",
        ["Quest progress of the group"] = "Questfortschritt der Gruppe",
        ["Everyone's progress on the quests of the step, and a word when everyone is done."] =
            "Fortschritt aller bei den Quests des Schritts, und eine Meldung, wenn alle fertig sind.",
        ["Group steps: who lacks the quest, who is far"] = "Gruppenschritte: wem die Quest fehlt, wer weit weg ist",
        ["For steps RestedXP marks for groups: who doesn't have the quest yet and who isn't in range."] =
            "Bei Schritten, die RestedXP für Gruppen markiert: wer die Quest noch nicht hat und wer nicht in Reichweite ist.",
        ["Missing quests, not accepted, abandon warning"] = "Fehlende und nicht angenommene Quests, Abbruch-Warnung",
        ["When the guide hearths soon: everyone's hearthstone cooldown and whether it's set where the guide expects. Flight paths the guide flies to soon that someone hasn't got."] =
            "Wenn der Guide bald den Ruhestein nutzt: Abklingzeit bei allen und ob er dort steht, wo der Guide ihn erwartet. Dazu Flugpunkte, die der Guide bald anfliegt und jemandem fehlen.",
        ["Missing quests and abandon warning"] = "Fehlende Quests und Warnung beim Abbrechen",
        ["Shows quests your RestedXP guide still wants you to complete or turn in later, but that are no longer in your quest log, and warns before you abandon one the guide still needs."] =
            "Zeigt Quests, die dein RestedXP-Guide später noch erledigen oder abgeben will, die aber nicht mehr in deinem Questlog sind, und warnt, bevor du eine abbrichst, die der Guide noch braucht.",
        ["Snail of the session"] = "Schnecke der Session",
        ["Tourist"] = "Tourist",
        ["Flower picker"] = "Blumenpflücker",
        ["Syncline slack meter (time the group waited):"] = "Syncline Bummel-Meter (so lange hat die Gruppe gewartet):",
        ["Nobody kept the group waiting yet."] = "Bisher musste die Gruppe auf niemanden warten.",
        ["Post"] = "Posten",
        ["Posts the ranking in the group chat."] = "Postet die Rangliste in den Gruppenchat.",
        ["Reset"] = "Reset",
        ["Ø %s/step"] = "Ø %s/Schritt",
        ["Slack meter (only you see it, as leader)"] = "Bummel-Meter (nur du siehst es, als Leiter)",
        ["In the group window: how long the group waited for whom – time someone was behind your step. Doesn't count while you're in combat or away, or while they're offline."] =
            "Im Gruppenfenster: wie lange die Gruppe auf wen gewartet hat, also die Zeit, die jemand hinter deinem Schritt war. Zählt nicht, solange du im Kampf oder AFK bist oder jemand offline ist.",
        ["Group at a glance"] = "Gruppe auf einen Blick",
        ["At the RestedXP window"] = "Am RestedXP-Fenster",
        ["Show a Syncline strip at the RestedXP window"] = "Syncline-Leiste am RestedXP-Fenster zeigen",
        ["A strip right under the RestedXP guide window with the group, quest progress, quests not accepted, hearthstone and buttons. It moves and hides with RestedXP, or stands on its own as a window. It takes the look of your skin (EllesmereUI, ElvUI, RestedXP's theme). Which lines it shows: the cog on the strip."] =
            "Eine Leiste direkt am RestedXP-Guidefenster mit Gruppe, Questfortschritt, nicht angenommenen Quests, Ruhestein und Knöpfen. Sie wandert und verschwindet mit RestedXP oder steht als eigenes Fenster. Sie übernimmt den Look deines Skins (EllesmereUI, ElvUI, RestedXP-Theme). Welche Zeilen sie zeigt: Zahnrad auf der Leiste.",
        ["Mode"] = "Modus",
        ["Docked"] = "Angedockt",
        ["Own window"] = "Eigenes Fenster",
        ["Width (own window)"] = "Breite (eigenes Fenster)",
        ["Opens the group window. As a window of its own: drag it here."] = "Öffnet das Gruppenfenster. Als eigenes Fenster: hier ziehen zum Verschieben.",
        ["Which lines show: the cog on the strip."] = "Welche Zeilen sie zeigt: Zahnrad auf der Leiste.",
        ["Position"] = "Position",
        ["Auto"] = "Auto",
        ["Below"] = "Unten",
        ["Above"] = "Oben",
        ["Lines"] = "Zeilen",
        ["Look"] = "Aussehen",
        ["Which lines the strip shows, and where it sits."] = "Welche Zeilen die Leiste zeigt und wo sie sitzt.",
        ["Missing and not accepted quests"] = "Fehlende und nicht angenommene Quests",
        ["Buttons"] = "Knöpfe",
        ["Opens the group window."] = "Öffnet das Gruppenfenster.",
        ["Lists them in the chat."] = "Listet sie im Chat auf.",
        ["Click to share it with the group."] = "Klicken, um sie mit der Gruppe zu teilen.",
        ["XP to level"] = "EP bis Stufe",
        ["Skip"] = "Skip",
        ["To me"] = "Zu mir",
        ["Send"] = "Senden",
        ["Member list"] = "Mitgliederliste",
        ["Full"] = "Komplett",
        ["Quests"] = "Quests",
        ["Compact"] = "Kompakt",
        ["Custom"] = "Eigene",
        ["View: %s"] = "Ansicht: %s",
        ["View"] = "Ansicht",
        ["Sections"] = "Abschnitte",
        ["View as leader"] = "Ansicht als Leiter",
        ["View as member"] = "Ansicht als Mitglied",
        ["Click to fold"] = "Klicken zum Einklappen",
        ["Click to unfold"] = "Klicken zum Aufklappen",
        ["Click a card's title to fold it."] = "Ein Klick auf den Titel einer Karte klappt sie ein.",
        ["What the window shows: Full, Quests, Compact, or your own mix. Set separately for leading and for being a member."] =
            "Was das Fenster zeigt: Komplett, Quests, Kompakt oder deine eigene Auswahl. Getrennt einstellbar, wenn du führst und wenn du Mitglied bist.",
        ["offline"] = "offline",
        ["You're in another guide – Get guide brings you back"] = "Du bist in einem anderen Guide, „Guide holen“ bringt dich zurück",
        ["you're %d step(s) behind the leader"] = "du bist %d Schritt(e) hinter dem Leiter",
        ["%d step(s) behind"] = "%d Schritt(e) zurück",
        ["in the guide"] = "im Guide",
        ["Everyone is in the guide and with you"] = "Alle sind im Guide und bei dir",
        ["You're with the group"] = "Du bist bei der Gruppe",
        ["and %d more"] = "und %d weitere",
        ["You lead"] = "Du führst",
        ["Member"] = "Mitglied",
        ["Solo"] = "Solo",
        ["Where everyone is"] = "Wo alle stehen",
        ["Name"] = "Name",
        ["Step"] = "Schritt",
        ["Status"] = "Status",
    }
    for k, v in pairs(de) do L[k] = v end
end
