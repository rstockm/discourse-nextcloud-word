# Spec Delta

## Purpose

Das Plugin wird reproduzierbar entwickelt, kontrolliert aktiviert und ohne
unbemerkte Doppelverarbeitung oder Verlust bestehender Dokumentlinks eingeführt.

## ADDED Requirements

### Requirement: Vollständiges ausschaltbares Plugin
Die Integration SHALL als ein Backend-Plugin mit eigener Composer-Oberfläche
installierbar sein und weder zusätzliche Theme Component noch PHP-Dienst benötigen.
Deaktivierung MUST neue Operationen und UI-Einstiege unterbinden, ohne bestehende
Nextcloud-Dokumente oder Share-Links zu löschen.

#### Scenario: Plugin deaktiviert oder nicht konfiguriert
- **WHEN** das Plugin deaktiviert ist oder notwendige Konfiguration fehlt
- **THEN** starten keine Office-Mutationen und erscheinen keine funktionsfähigen Erstellungseinstiege
- **AND** bleibt Discourse ansonsten benutzbar

### Requirement: Reproduzierbare aktuelle Entwicklung
Das Projekt MUST vor Umsetzung den aktuellen offiziellen Plugin-/Frontend-
Vorlagenstand prüfen, geprüfte Versionen festhalten und native Lint-, Typ-,
Backend-, Frontend- und Systemtests mit einem gemeinsamen Prüfeinstieg anbieten.
Fehlende Voraussetzungen SHALL nicht als erfolgreiche Prüfung gelten.

#### Scenario: Qualitätsprüfung
- **WHEN** der dokumentierte gemeinsame Check in der eingerichteten Testumgebung läuft
- **THEN** werden die relevanten Tests und strikte Spec-Validierung tatsächlich ausgeführt
- **AND** führen Fehler oder fehlende notwendige Voraussetzungen zu einem Nicht-Erfolgsstatus

### Requirement: Nachgewiesene Zielkompatibilität
Freigabe und Kompatibilitätsmetadaten MUST auf dokumentierten Zielständen und
ausgeführten Tests beruhen. Ein aktueller Entwicklungs-Commit SHALL nicht als
Beleg für beliebige ältere Discourse-/Nextcloud-/Collabora-Versionen gelten.

#### Scenario: Produktiver Zielstand weicht ab
- **WHEN** der Zielstand außerhalb der getesteten Kombination liegt
- **THEN** bleibt der Rollout bis zu passender Verifikation blockiert

### Requirement: Kontrollierter Cutover und Rückweg
Die Migration MUST alte Theme-/PHP-Verarbeitung vor Aktivierung des neuen
Schreibwegs ausschalten, bestehende Dokumente/Links erhalten und einen erprobten
Rückweg ohne automatische Reaktivierung bekannter Schwachstellen dokumentieren.

#### Scenario: Erfolgreicher Umstieg
- **WHEN** das Plugin nach Testfreigabe aktiviert wird
- **THEN** gibt es genau einen aktiven Erstellungs-/Übertragungsweg
- **AND** vorhandene Postings/Share-URLs bleiben unverändert erreichbar
- **AND** der alte öffentliche PHP-Endpoint ist gesperrt

#### Scenario: Rücknahme der Aktivierung
- **WHEN** der Rollout abgebrochen wird
- **THEN** können neue Plugin-Operationen gestoppt werden, ohne bereits erstellte Dokumente zu löschen
- **AND** wird der unsichere alte Endpoint nicht ungeprüft wieder geöffnet
