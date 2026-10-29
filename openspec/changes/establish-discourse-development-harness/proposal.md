# Proposal

## Why

Das bestehende PoC benötigt einen nachvollziehbaren Entwicklungsprozess statt
veralteter Discourse-Muster und unbewiesener Sicherheits-/Kompatibilitätszusagen.
Der Nutzer hat den [Bootstrap-Plan](../../../docs/plans/2026-10-28-discourse-harness.md)
am 2026-10-28 für Harness und OpenSpec ausdrücklich freigegeben.

## What Changes

- Offizielle OpenSpec-OpenCode-Integration mit Core-Profil und exakter CLI-Version.
- Verbindlicher Projekteinstieg, Aktualitätsprüfung offizieller Discourse-Quellen,
  Freigabegrenzen und ehrliche Nachweise für Prüfungen.
- Eigenes Discourse-Profil auf Basis der unveränderten `guidelines/`.
- ADR-Vorlage und zwei Architekturvorschläge, keine vorweggenommene Akzeptanz.
- Plugin-Fähigkeit und Phase-2-Abgrenzung für Discourse-Dateirechte dokumentieren.

Nicht-Ziele: Produktcode, API-Verhalten, PHP-Ablösung, Plugin-Implementierung,
Testplattform-/CI-Aufbau, Deployment oder Archivierung ändern.

## Capabilities

### New Capabilities

- `development-workflow`: beobachtbarer Projektworkflow für Quellenprüfung,
  Change-Freigabe, ADR-Lebenszyklus und überprüfbare Abschlussnachweise. Dies ist
  ein neuer Entwicklungsvertrag, keine Spezifikation neuer Office-Funktionen.

### Modified Capabilities

Keine; das Projekt besitzt noch keine bestehenden OpenSpec-Specs.

## Impact

Neue Projekt-/Prozessdateien unter `docs/`, `openspec/`, `.opencode/` und eine
Root-`AGENTS.md`; ein Einstiegshinweis in der README. Bestehende Theme- und
Middleware-Dateien sowie `guidelines/` bleiben unverändert. OpenSpec wird exakt
als 1.15.0 aufgerufen, ohne globale Installation zu ersetzen.

Risiken: Agentenregeln erzwingen keine CI-Gates, Quellen veralten, vorhandene
Sicherheitsmängel bestehen fort. Die Dokumentation muss Grenzen und nicht
ausgeführte Tests sichtbar halten. Bestehende öffentliche Links bleiben weiterhin
öffentliche Zugriffsberechtigungen, keine Discourse-ACL.
