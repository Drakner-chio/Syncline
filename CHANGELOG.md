# Syncline

## 0.17.0
- Die Leiste erkennt RestedXP-Skins allgemein: Macht ein Skin das RestedXP-Fenster unsichtbar und zeichnet ein eigenes, dockt sie an dessen Fenster. Bekannt: EUI-RestedXP, FUI-RestedXP, BeautifulRestedXP; dazu jeder Skin, dessen Fenster an RestedXP hängt (so arbeitet auch LiteTweaks). Hängt das Skin-Fenster an seiner Unterkante, sitzt die Leiste oben. Skins, die das RestedXP-Fenster nur umfärben (ElvUI-Art), brauchen nichts.
- Eigenes Fenster: Im Zahnrad-Menü bzw. den Einstellungen „Modus: Eigenes Fenster“. Die Leiste steht dann frei, ist am Kopf verschiebbar und in der Breite einstellbar. Ohne RestedXP-Fenster wird sie automatisch zum eigenen Fenster.
- Look folgt dem Skin, angedockt wie frei: EllesmereUI (mit den Kartenwerten von EUI-RestedXP), ElvUI (Schrift, Hintergrund, Rand, Wertefarbe), sonst das aktive RestedXP-Theme (Hintergrund, Akzent, Schrift; auch Themes, die Skin-Addons bei RestedXP anmelden). „Aussehen: Syncline“ schaltet auf den eigenen Look.

## 0.16.0
- Leiste am RestedXP-Fenster arbeitet mit EUI-RestedXP zusammen: Ist dessen Umbau aktiv (Frameless, Timeline, Compact, Zygor, 8-Bit, Rail), dockt sie an das EUI-Fenster statt an das unsichtbare RestedXP-Fenster darunter. Sie erbt Skalierung und Ausblenden bei Inaktivität und sitzt unter den Ziel- und Item-Boxen, die EUI unter sein Fenster klebt. Wächst EUI nach oben, sitzt sie oben.
- EllesmereUI-Look, sobald EllesmereUI läuft: dessen Schrift mit Kontur, die dunkle Schrittkarte mit hauchdünnem Rand (Deckkraft aus deinen EUI-Einstellungen), „SYNCLINE“ in der Farbe von „STEP 1“, Knöpfe in der EUI-Akzentfarbe. Im Zahnrad-Menü unter „Aussehen“ auf „Syncline“ umstellbar.

## 0.15.0
- Syncline-Leiste am RestedXP-Fenster: hängt direkt unter (oder über) dem Guidefenster, genauso breit, wandert, skaliert und verschwindet mit ihm. Funktioniert mit dem klassischen RestedXP-Fenster und der neuen V2-Oberfläche.
- Zeilen: Gruppe auf einen Blick (mit den wichtigsten Problemen), Gruppenschritt, Questfortschritt, nicht angenommene und fehlende Quests, Ruhestein und Flugpunkte, Quests teilen (Klick teilt), Erfahrung, Bummel-Meter, dazu kleine Knöpfe (Skip / Zu mir bzw. Skip anfragen / Guide holen). Jede Zeile erscheint nur, wenn sie etwas zu sagen hat.
- Welche Zeilen sie zeigt, stellt das Zahnrad auf der Leiste ein, dazu Position Auto/Unten/Oben. Auto setzt die Leiste nach oben, wenn RestedXP nach oben wächst. An- und abschalten in den Einstellungen unter „Am RestedXP-Fenster“. Ein Klick auf den Kopf öffnet das Gruppenfenster.

## 0.14.0
- Neues Gruppenfenster: großer Guide-Name, Fortschrittsbalken mit einer Markierung pro Spieler (Leiter weiß, alle anderen in Klassenfarbe; Maus drüber zeigt, wer wo steht), Rolle oben rechts.
- Ansichten, getrennt für Leiter und Mitglied: Komplett, Quests, Kompakt und Eigene. Umschalten über „Ansicht“ im Fensterkopf oder in den Einstellungen. Einen einzelnen Abschnitt an- oder ausschalten macht daraus die eigene Ansicht. Standard: Leiter Komplett, Mitglieder Kompakt.
- „Gruppe auf einen Blick“ statt der vollen Liste in Quests und Kompakt: ein Punkt pro Spieler und nur das, was Aufmerksamkeit braucht (anderer Guide, hängt fest, Schritte zurück, andere Einstellungen, kein Syncline). Der Leiter sieht alle, ein Mitglied nur sich selbst.
- Karten klappen mit einem Klick auf den Titel ein und bleiben so.
- Mitgliederliste mit Spaltenköpfen, Klassenfarben-Streifen, Krone für den Leiter, eigene Zeile hervorgehoben, offline sichtbar.
- Knöpfe passend zur Lage: in Kompakt/Quests als Mitglied nur „Skip anfragen“ oder „Guide holen“, als Leiter „Guide senden“ nur, wenn jemand in einem anderen Guide ist.

## 0.13.0
- Questfortschritt der Gruppe: Für die Quests im aktuellen Schritt zeigt das Gruppenfenster den Fortschritt aller, z. B. „Bob 8/8 · Dani 6/8 · Fluffy 3/8“. Sind alle fertig, meldet Syncline „Alle sind fertig mit … – ab zur Abgabe!“ mit Ton.
- Annahme-Check: Wer eine Quest nicht angenommen hat, die der Guide vor kurzem (bis 15 Schritte zurück) annehmen ließ, bekommt sofort einen roten Hinweis mit Ton. Der Leiter erfährt es einmal im Chat, im Fenster steht „nicht angenommen: …“ in Rot.
- Ruhestein und Flugpunkte: Kommt im Guide bald ein Ruhestein-Schritt, zeigt das Fenster die Ruhestein-Abklingzeit aller und ob der Ruhestein dort steht, wo der Guide ihn erwartet. Dazu Flugpunkte, die der Guide bald anfliegt und die jemandem fehlen. Abgeglichen über RestedXPs Ruhestein-Ort und Flugpunkt-IDs, also sprachunabhängig.
- Gruppenschritte: Bei Schritten, die RestedXP für Gruppen markiert, zeigt das Fenster, wem die Quest noch fehlt und wer nicht in Reichweite ist.
- Einstellungen in zwei Spalten, mit eigenem Bereich „Quest-Helfer“. Jede Funktion ist einzeln abschaltbar.

## 0.12.1
- Fix: Gekaufte Guides mit Kapitelnummer statt Levelbereich (z. B. „11. The Drowned Capitals“ / „11. Die Ertrunkenen Hauptstädte“) wurden bei gemischten Sprachen als „anderer Guide“ angezeigt und nicht übernommen. Der Fingerabdruck nimmt jetzt auch die Kapitelnummer, und ohne Nummer allein die Quests.
- EP pro Stunde zeigt „–“ statt „0/h“, solange in den letzten 30 Minuten keine EP dazukamen.
- Versionsanzeige: „v0.12.1“ statt „vv0.12.1“ in Release-Builds.

## 0.12.0
- Warum geht der Schritt nicht? Syncline prüft den aktuellen Schritt und nennt den Grund:
  - Vorquest noch nicht abgegeben (mit Schritt)
  - Stufe zu niedrig, überlevelt bzw. grau
  - schon abgegeben
  - Questlog voll
  - Quest nicht im Log
  - Ziele noch offen (mit Fortschritt, z. B. „Räuber getötet: 3/8“)

  Dein eigener Grund steht im Gruppenfenster unter dem Gruppen-Guide. Bei Mitgliedern steht „hängt: …“, der Tooltip zeigt alles. `/sl warum` listet die Gründe im Chat.
- Quests teilen: Jeder schickt, welche Quests sein Guide ab jetzt noch braucht und die ihm fehlen. Im Gruppenfenster erscheint „Quests teilen“ mit den Quests aus deinem Log, die anderen fehlen, und für wen. Ein Klick auf „Teilen“ oder „Alle teilen“ genügt, oder `/sl teilen`.
- Autoteilen: `/sl autoteilen` (oder `/sl autoshare`) teilt solche Quests von selbst, nicht im Kampf und dieselbe Quest höchstens einmal pro Minute.
- Alles sprachunabhängig über Quest-IDs, in den Einstellungen einzeln abschaltbar.

## 0.11.0
- Fehlende Quests: Syncline geht deinen RestedXP-Guide ab dem aktuellen Schritt durch und findet Quests, die der Guide später noch erledigen oder abgeben will, die aber nicht mehr in deinem Questlog sind (nicht abgegeben und vorher im Guide auch nicht neu angenommen). Jede neue fehlende Quest wird einmal im Chat gemeldet, `/sl fehlend` listet alle mit Schritt.
- Warnung beim Abbrechen: Bricht man eine Quest ab, die der Guide später noch braucht, kommt ein Hinweis mit dem Schritt, an dem sie fehlen würde. Sagt der Guide gerade selbst „abbrechen“ oder nimmt er die Quest vorher neu an, kommt keine Warnung.
- Für die Gruppe: Jeder schickt seine fehlenden Quests mit. Im Gruppenfenster erscheint „Fehlende Quests“ mit allen, denen etwas fehlt, z. B. zum Teilen.
- In den Einstellungen abschaltbar („Fehlende Quests und Warnung beim Abbrechen“).

## 0.10.0
- EP-Übersicht der Gruppe im Gruppenfenster, für alle: pro Mitglied Stufe, ein Balken mit EP (blau), Ruhe-EP (hellblau) und den EP der abgabebereiten Quests (grün), wie viel fehlt, EP pro Stunde und die Zeit bis zum Level-Up. Reichen die abgabebereiten Quests für den Level-Up, steht dort „abgeben!“.
- Im Tooltip jeder Zeile: EP, fehlende EP, Ruhe-EP, EP abgabebereiter Quests und aller Quests im Log, EP pro Stunde, Level-Up in … und nach den Abgaben.
- Jeder misst seine eigenen EP (das Spiel verrät fremde nicht) und schickt sie höchstens alle 10 Sekunden. EP pro Stunde über die letzten 30 Minuten, auch über einen Level-Up hinweg. In den Einstellungen abschaltbar.

## 0.9.0
- Bummel-Meter (nur für den Leiter): Im Gruppenfenster steht, wie lange die Gruppe auf wen gewartet hat, also die Zeit, die jemand hinter dem Schritt des Leiters war. Dazu die Zeit pro Schritt.
  - Rangliste mit Balken, Titel für den Spitzenreiter: Blumenpflücker (ab 2 Min.), Tourist (ab 10 Min.), Schnecke der Session (ab 30 Min.).
  - Zählt nicht, solange der Leiter im Kampf oder AFK ist, nicht im Gruppen-Guide ist oder das Mitglied offline ist.
  - „Posten“ schreibt die Rangliste in den Gruppenchat, „Reset“ fängt neu an. Wer eine Minute keiner Gruppe angehört, startet automatisch eine neue Session.
  - Mitglieder schicken dafür nichts zusätzlich, der Leiter rechnet aus den Schritten, die er ohnehin bekommt. In den Einstellungen abschaltbar.

## 0.8.0
- Skip-Check: Syncline zeigt, ob ein Schritt sicher übersprungen werden kann. Es liest aus dem Guide, welche Quests der Schritt betrifft und welche Folgequests daran hängen (Bedingungen wie „nur wenn Quest X abgegeben“ und Quests, die bei der Abgabe angenommen werden, mehrere Ebenen tief).
  - Grün „sicher zu skippen“: keine Folgequests. Orange: 1–2 Folgequests. Rot: eine längere Kette.
  - Steht im Gruppenfenster unter dem Schritt des Leiters, im Tooltip von „Schritt skippen“ (mit allen Folgequests) und im Skip-Anfrage-Popup.
  - Hängen Folgequests am Schritt, fragt Syncline den Leiter vor dem Skip für alle noch einmal nach.

## 0.7.1
- Schritte werden über ihre Zeile im Guide abgeglichen statt über ihre Nummer. RestedXP lässt Schritte für andere Klassen und Rassen weg, darum hat jede Klasse eine andere Zählung (z. B. 58/157 und 58/156). Skip, „Alle zu mir“, Skip-Anfragen und die Abstandsanzeige stimmen jetzt auch bei gemischten Klassen.
- Fehlt jemandem der Schritt (andere Klasse), landet er beim nächsten Schritt, den er hat.
- Mit einer älteren Syncline-Version und unterschiedlicher Schrittzahl wird kein Abstand mehr geraten.
- Schritt-Text ohne RestedXP-Rohcode („Morg::256891“).

## 0.7.0
- RestedXP-Routeneinstellungen abgleichen: Dungeons, überlevelte Schritte überspringen, Gruppenquests, Solo Self Found und EXP-Rate bestimmen, welche Schritte ein Guide hat. Der Leiter schickt seine Einstellungen mit dem Guide mit, und auch dann, wenn er sie ändert. Mitglieder übernehmen sie (oder werden gefragt), RestedXP lädt den Guide einmal neu.
- Im Gruppenfenster steht „Einstellungen anders“ bei Mitgliedern mit abweichenden Einstellungen. Mit der Maus darüber sieht man welche, `/sl status` zeigt es auch.
- Neue Einstellungen: „RestedXP-Routeneinstellungen des Leiters übernehmen“ und „Als Leiter: meine Routeneinstellungen an die Gruppe senden“ (beide an). Neuer Befehl `/sl route`.
- Berufe bleiben bei jedem, wie sie sind. Eine automatische EXP-Rate wird nicht verglichen, die ist pro Spieler.

## 0.6.2
- „Guide an die Gruppe geschickt“ steht beim Leiter nur noch im Chat, wenn er einen neuen Guide wählt oder per Hand sendet. Fragt ein Mitglied nach dem Guide (Login, Reload, Ladebildschirm), antwortet Syncline still.
- Fragen mehrerer Mitglieder kurz nacheinander werden mit einer Antwort erledigt.
- Ladebildschirme, bei denen die Gruppe kurz „weg“ ist, lösen keine neue Frage an den Leiter mehr aus.

## 0.6.1
- RestedXPs kostenpflichtige Forever-Guides (z. B. „43-44 Flusslande II“) werden jetzt über Client-Sprachen hinweg erkannt. Jeder importiert sie in seiner Sprache, und die Namen unterscheiden sich („43-44 Riverglades II“). Syncline erkennt sie am Levelbereich im Namen und an den Quests in den Schritten.
- Fix: Spielernamen in der Form „Name Realm“ (mit Leerzeichen) werden richtig erkannt.
- „Den Guide gibt es bei dir nicht“ kommt nur noch einmal statt mehrfach.

## 0.6.0
- Neuer Name: aus GuideSync wird **Syncline**. Befehl jetzt `/sl` (oder `/syncline`).
- Alle in der Gruppe brauchen Syncline: GuideSync und Syncline sehen sich gegenseitig nicht.
- Einstellungen werden neu angelegt (Standardwerte), GuideSync kann danach gelöscht werden.

## 0.5.0
- Schritte: Im Gruppenfenster steht bei jedem Spieler, bei welchem Schritt er ist, und wie weit vor oder hinter dem Leiter (grün „=“, orange zurück, blau voraus). Oben steht der Schritt des Leiters mit seinem Text.
- Leiter: „Schritt skippen“ überspringt seinen aktuellen Schritt für alle, die gerade bei diesem Schritt sind. „Alle zu mir“ holt alle im Gruppen-Guide auf seinen Schritt.
- Mitglieder: „Skip anfragen“ fragt beim Leiter an, den eigenen Schritt für alle zu überspringen. Der Leiter bekommt ein Popup mit dem Schritt-Text.
- Neue Befehle `/sl skippen` und `/sl herholen`, Tastenbelegungen für Skip und Gruppenfenster.
- Neue Einstellung: „Leiter darf Schritte überspringen und mich herholen“. Mit „Vorher fragen“ kommt auch hier erst ein Popup.
- Funktioniert mit 0.4.0 zusammen, nur die Schritt-Funktionen brauchen 0.5.0 bei allen.

## 0.4.0
- Logo (auch in der Addon-Liste und im Chat).
- Gruppenfenster (`/sl` oder Linksklick auf den Minimap-Knopf): Gruppen-Guide, wer in welchem Guide ist, Knöpfe zum Senden, Holen und Vorschlagen.
- Einstellungen (`/sl optionen`, Rechtsklick auf den Minimap-Knopf, oder Esc → Optionen → AddOns → Syncline): Sync an/aus, sofort wechseln oder vorher fragen, Vorschlagen anbieten, Fenstergröße, Fenster sperren, Minimap-Knopf.
- Minimap-Knopf (verschiebbar, mit Tooltip: Gruppen-Guide und wie viele drin sind) und Eintrag im Addon-Menü an der Minimap.
- `/sl` öffnet jetzt das Fenster, die Liste im Chat gibt es mit `/sl status`.

## 0.3.1
- Fix (seit 0.2.1): Mitglieder bekamen den Guide des Leiters nicht mehr. Die Leiter-Erkennung hat Namen aus der Gruppenliste gelesen, und die gibt der Forever/Midnight-Client teils als geheime Werte heraus. Der Leiter wird jetzt direkt über den Absender erkannt.
- Fehler beim Verarbeiten einer Nachricht gehen nicht mehr still verloren (mit `/sl debug` im Chat sichtbar).

## 0.3.0
- Guide vorschlagen: Mitglieder schlagen dem Leiter ihren Guide vor (`/sl vorschlagen`). Der Leiter bekommt ein Popup, und mit „Übernehmen“ ziehen alle mit.
- Wer selbst einen anderen Guide wählt, wird gefragt, ob er ihn dem Leiter vorschlagen will.
- Lehnt der Leiter ab, bekommt der Vorschlagende eine Nachricht.

## 0.2.1
- Fix: `/sl` zeigte Mitspieler mit Syncline als „kein Syncline“, wenn der Client Namen mit Realm liefert. Gleiches Problem hätte den Leiter auf anderen Realms nicht erkannt.
- `/sl` zeigt jetzt „alte Syncline-Version“, wenn jemand eine andere Version hat.
- `/sl debug` zeigt jede empfangene Nachricht, `/sl version` die eigene Version.

## 0.2.0
- Deutscher und englischer Client in einer Gruppe: RestedXP benennt die WoW-Forever-Guides je nach Sprache anders. Syncline erkennt jetzt denselben Guide in allen Sprachen (Deutsch, Englisch, Französisch, Spanisch, Portugiesisch, Chinesisch).
- Guides, die Syncline nicht kennt, werden über Gruppe und Namen gesucht, notfalls nur über den Namen.
- Neues Nachrichtenformat: alle in der Gruppe brauchen 0.2.0.

## 0.1.0
- Erste Version: der Gruppenleiter wählt einen RestedXP-Guide, alle in der Gruppe laden ihn mit.
- Wartet im Kampf und lädt danach, fragt auf Wunsch vorher (`/sl fragen`).
- `/sl` zeigt, wer in welchem Guide ist.
