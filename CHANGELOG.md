# Syncline

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
