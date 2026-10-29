# Spec Delta

## Purpose

Die Composer-Integration erhält die bisherigen Office-Abläufe in Markdown und
Rich Text, ohne Entwürfe zu verwechseln oder fehlgeschlagene Übertragungen zu kaschieren.

## ADDED Requirements

### Requirement: Vorlagenablauf erhalten
Das Plugin SHALL Word-, Excel- und PowerPoint-Dokumente aus gültigen Vorlagen
erzeugen lassen, einen Dateinamen aus Topic-Titel/Datum vorschlagen und ein
optionales Share-Passwort entgegennehmen.

#### Scenario: Neue Datei in beiden Editoren
- **WHEN** ein angemeldeter Nutzer docx, xlsx oder pptx bestätigt
- **THEN** entsteht das gewählte leere Format in Nextcloud
- **AND** der bearbeitbare Link wird im auslösenden Entwurf eingefügt
- **AND** ein angegebenes Passwort schützt den Share, ein leeres Feld erzwingt keines

#### Scenario: Abbrechen oder Fehler
- **WHEN** der Nutzer den Dialog abbricht oder die Erstellung fehlschlägt
- **THEN** wird kein falscher Erfolgslink eingefügt
- **AND** Fehler und Ladezustand sind verständlich, ohne Passwort oder internen Response-Dump

### Requirement: Nativen Upload übertragen
Das Plugin SHALL nach erfolgreichem nativem Discourse-Upload erlaubte Office-
Dateien einmalig zu Nextcloud übertragen und den Anhang bei Erfolg durch den
bearbeitbaren Link ersetzen. Standardformate sind docx/xlsx/pptx/odt/ods/odp;
die konfigurierbare Auswahl MUST auf serverseitig unterstützte Formate begrenzt bleiben.

#### Scenario: Erfolgreiche Übertragung
- **WHEN** ein konfiguriertes Office-Format erfolgreich übertragen wurde
- **THEN** erscheint genau ein Nextcloud-Link anstelle des betreffenden Anhangs
- **AND** dies funktioniert im Markdown- und Rich-Text-Editor
- **AND** andere Anhänge und selbst eingegebener Text bleiben unverändert

#### Scenario: Download oder Übertragung fehlgeschlagen
- **WHEN** Datei-Download, Validierung, Upload oder Share-Erstellung fehlschlägt
- **THEN** bleibt der native Discourse-Anhang erhalten
- **AND** wird kein leeres Vorlagendokument als Ersatz erstellt
- **AND** erhält der Nutzer einen lokalisierten Hinweis

### Requirement: Entwurf und Operation eindeutig binden
Die Integration MUST Ergebnisse dem auslösenden Entwurf und Upload zuordnen.
Mehrfachklicks, gleichnamige Dateien und verspätete Antworten SHALL keine
Doppel-Links oder Änderungen an einem anderen Entwurf auslösen.

#### Scenario: Entwurfswechsel während einer Anfrage
- **WHEN** vor der Antwort der Composer geschlossen oder ein anderer Entwurf geöffnet wird
- **THEN** wird dessen Inhalt nicht verändert
- **AND** kann eine bereits serverseitig fertige Operation kontrolliert wiedergefunden werden

#### Scenario: Zwei Dateien mit gleichem Namen
- **WHEN** zwei gleichnamige Office-Dateien parallel übertragen werden
- **THEN** wird jeder Link ausschließlich seinem ursprünglichen Anhang zugeordnet

### Requirement: Native lokalisierte und zugängliche Oberfläche
Die Oberfläche SHALL Discourse-native Dialog-/Formularkonventionen sowie
deutsche und englische Übersetzungen bieten. Zentrale Abläufe MUST per Tastatur
und ab 320 CSS-Pixeln ohne Funktionsverlust bedienbar sein.

#### Scenario: Dialog per Tastatur
- **WHEN** der Nutzer öffnet, bestätigt oder schließt den Dialog per Tastatur
- **THEN** sind Labels, sichtbarer Fokus, Lade-/Fehlerzustände und Fokusrückgabe vorhanden
- **AND** verdecken oder beschneiden sich zentrale Bedienelemente in den Pflicht-Viewports nicht
