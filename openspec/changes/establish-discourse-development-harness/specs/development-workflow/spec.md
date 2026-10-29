# Spec Delta

## Purpose

Der Entwicklungsworkflow macht Entscheidungen, Quellenstand und Prüfergebnisse
für Mitwirkende nachvollziehbar, ohne Produktfreigaben oder erfolgreiche Tests vorzutäuschen.

## ADDED Requirements

### Requirement: Eindeutiger Projekteinstieg
Der Harness SHALL Mitwirkenden einen Root-Einstieg mit Projektprofil, wichtigen
Pfaden, real verfügbaren Checks und Grenzen des freigegebenen Arbeitsumfangs anbieten.

#### Scenario: Einstieg in das bestehende Projekt
- **WHEN** eine Person oder ein Agent den Projekteinstieg liest
- **THEN** sind aktuelle Theme/PHP-Architektur und separate Zukunftsoptionen unterscheidbar
- **AND** unveränderte Referenz-Guidelines und projektspezifische Abweichungen auffindbar

### Requirement: Belegte Aktualität
Der Workflow SHALL vor relevanten Discourse-API- oder Tooling-Änderungen eine
Prüfung aktueller offizieller Quellen mit Datum und identifizierbarem Stand verlangen.
Vorabversionen MUST ausdrücklich als solche begründet werden.

#### Scenario: Neue Discourse-Schnittstelle
- **WHEN** eine Änderung eine Discourse-API oder Entwicklungsvorlage verwendet
- **THEN** dokumentiert der Change offizielle Quelle, Prüfdatum und Zielstand
- **AND** ältere Beispiele ersetzen nicht ungeprüft die aktuellen Vorgaben

#### Scenario: Quelle nicht überprüfbar
- **WHEN** die für eine relevante Entscheidung notwendige Quelle nicht verfügbar ist
- **THEN** wird diese Änderung bis zur Klärung blockiert statt Aktualität zu behaupten

### Requirement: Menschliche Freigabegrenzen
Der Workflow SHALL nicht triviale Umsetzung und Archivierung an getrennte
ausdrückliche Freigaben binden. Vorhandene Plan-Dateien MUST von einer tatsächlichen
Zustimmung unterschieden werden.

#### Scenario: Freigegebener Harness ohne Runtime-Freigabe
- **WHEN** der Nutzer nur Harness und OpenSpec freigibt
- **THEN** werden weder Middleware noch Theme-Verhalten migriert
- **AND** der Change wird ohne weitere Freigabe nicht archiviert

### Requirement: Nachvollziehbarer ADR-Lebenszyklus
Neue ADRs SHALL als `proposed` geführt werden. Eine Übernahme als `accepted` MUST
auf ausdrücklicher Zustimmung mit Datum und bestätigten Entscheidungsträgern beruhen.

#### Scenario: Architektur als Zukunftsoption
- **WHEN** ein Plugin als mögliche Richtung diskutiert wird
- **THEN** dokumentiert das ADR Optionen und offene Entscheidungen ohne erfundene Akzeptanz

### Requirement: Ehrliche Verifikation
Der Abschluss SHALL ausgeführte Checks, Ergebnisse und fehlende Prüfungen
unterscheiden. Strukturvalidierung MUST von Produkt-, Browser- und Sicherheitstests
getrennt ausgewiesen werden.

#### Scenario: Tests noch nicht eingerichtet
- **WHEN** lediglich Harness-Dokumente und OpenSpec-Dateien geprüft wurden
- **THEN** werden weder funktionierende Office-Abläufe noch CI- oder UI-Testabdeckung behauptet

### Requirement: Sicherheits- und Phasengrenzen
Der Harness SHALL öffentliche Shares und Browser-Keys von vertraulicher
Discourse-Autorisierung unterscheiden. Eine Übernahme von Discourse-Dateirechten
MUST als gesondert zu planende Phase 2 ausgewiesen werden.

#### Scenario: Plugin-Betrieb ist möglich
- **WHEN** die Zielinstallation Backend-Plugins erlaubt
- **THEN** wird dies als Architektur-Randbedingung dokumentiert, nicht als Migrationsfreigabe
- **AND** bestehende Share-Links werden nicht als Discourse-ACL bezeichnet
