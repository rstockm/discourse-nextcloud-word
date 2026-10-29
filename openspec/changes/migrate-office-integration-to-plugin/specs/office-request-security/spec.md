# Spec Delta

## Purpose

Office-Anfragen erhalten eine vertrauenswürdige Discourse-Servergrenze mit
unabhängiger Dateiprüfung, begrenztem Ressourcenverbrauch und geheimnisfreien Diagnosen.

## ADDED Requirements

### Requirement: Vertrauenswürdige Endpoint-Authentifizierung
Mutierende Office-Anfragen MUST eine gültige Discourse-Nutzersitzung, den
regulären CSRF-Schutz und die grundlegende Nutzungsberechtigung verlangen.
Anonyme, gesperrte oder deaktivierte Konten SHALL keine Office-Operation starten.

#### Scenario: Gefälschter Origin und alter Browser-Key
- **WHEN** ohne berechtigte Sitzung ein Request mit passendem Origin oder altem Theme-Key ankommt
- **THEN** wird er abgelehnt, bevor Nextcloud oder aufwendige Dateiverarbeitung angesprochen wird

#### Scenario: Fehlender CSRF-Nachweis
- **WHEN** eine sitzungsbasierte mutierende Anfrage den CSRF-Schutz nicht erfüllt
- **THEN** wird sie ohne entfernte Seiteneffekte abgewiesen

### Requirement: Secrets und Ergebnisse nicht offenlegen
Nextcloud-Secrets MUST ausschließlich serverseitig verfügbar sein. Passwörter,
Authentifizierungsheader, Dokumentinhalte und zugriffsgewährende Share-URLs SHALL
weder in Logs noch in öffentlichen Settings, Dumps oder unberechtigten Statusantworten erscheinen.

#### Scenario: Nextcloud antwortet mit sensiblen Fehlerdaten
- **WHEN** eine Fehlerantwort Secrets oder Share-Daten enthält
- **THEN** erhält der Nutzer nur sicheren Fehlercode, lokalisierten Text und Korrelationskennung
- **AND** enthalten Rails-/Proxy-/Job-/Browser-Diagnosen keine sensiblen Nutzdaten

#### Scenario: Fremdes Operationsergebnis
- **WHEN** ein anderer Nutzer eine Operation abfragt
- **THEN** erhält er weder Share-Link noch Vorgangsdetails

### Requirement: Office-Inhalte unabhängig validieren
Das Plugin MUST Format, Endung und tatsächliche Paketstruktur unabhängig vom
Browser und vom vorherigen Discourse-Upload prüfen. Beliebige ZIP-/Binärdateien,
getarnte Makroformate, beschädigte oder verschlüsselte Pakete SHALL nicht als
gültige Office-Dateien akzeptiert werden.

#### Scenario: ZIP als docx getarnt
- **WHEN** ein ZIP nur die passende Endung oder einen generischen MIME-Typ besitzt
- **THEN** wird es ohne gültige formattypische Struktur abgelehnt

#### Scenario: Gefährliche Paketstruktur
- **WHEN** ein Paket Traversal, Symlinks, doppelte Einträge, aktive Makros oder externe XML-Entitäten enthält
- **THEN** wird es ohne Extraktion in frei wählbare Pfade oder externe Netzabrufe abgelehnt

### Requirement: Begrenzter Ressourcenverbrauch
Anfragen MUST Datei-/Entpackgrößen, Eintragszahlen, Verarbeitungszeit,
Anfragefrequenz und Parallelität begrenzen. Discourse-Dateityp-/Größenbeschränkungen
SHALL nicht durch den Plugin-Endpoint umgangen werden.

#### Scenario: Größe oder Archivbudget überschritten
- **WHEN** Transportgröße oder tatsächlicher Entpackverbrauch das konfigurierte Limit überschreitet
- **THEN** endet die Operation begrenzt und ohne Nextcloud-Datei

#### Scenario: Anfragelimit überschritten
- **WHEN** ein Nutzer oder die Instanz das konfigurierte Frequenz-/Parallelitätslimit erreicht
- **THEN** wird weitere Arbeit mit sicherem Überlastungshinweis abgelehnt statt unbegrenzt gestartet

### Requirement: Keine frei wählbaren Netzwerkziele
Anfragen SHALL keine vom Nutzer vorgegebenen Download-, WebDAV- oder Share-Ziele
abrufen. Netzwerkzugriffe MUST auf die administrativ konfigurierte Nextcloud-
Verbindung mit geprüfter TLS-Verbindung und begrenzten Antworten beschränkt bleiben.

#### Scenario: Manipulierte URL oder Redirect
- **WHEN** ein Request eine Download-URL enthält oder Nextcloud auf einen anderen Host umleitet
- **THEN** erfolgt kein solcher Abruf und keine Weitergabe von Zugangsdaten
