# Syncline

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
