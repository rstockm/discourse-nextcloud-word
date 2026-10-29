# Design

## Context

Siehe [Proposal](proposal.md). Es gibt bisher kein Testtooling und keine Specs;
das Theme installiert keinen Servercode. `guidelines/` ist Nutzermaterial und
bleibt unverändert. Die Freigabe betrifft ausschließlich den Bootstrap-Plan.

## Goals / Non-Goals

**Goals:** Root-Einstieg und kleine verlinkte Entwicklungsdokumente; offizielle
generierte OpenSpec-Integration; testbarer Prozessvertrag; zwei Architekturvorschläge.

**Non-Goals:** Kopieren des gesamten Guidelines-Stacks, neuer Agenten-Workflow,
Produkt-Refactor oder ein grünes Qualitätsgate ohne vorhandene Tests.

## Decisions

- OpenSpec 1.15.0 exakt über `npx --yes @fission-ai/openspec@1.15.0` aufrufen.
  Das vermeidet eine globale Änderung und das Einführen einer Theme-package.json
  allein für Prozesswerkzeuge. Nachfolgende CLI-Aufrufe verwenden denselben Stand.
- Core-Integration unverändert generieren. Nur die dafür vorgesehene
  `openspec/config.yaml` enthält projektspezifischen Kontext; keine manuellen
  Änderungen an generierten Commands/Skills und kein eigenes Schema.
- Entwicklungsregeln über Root-AGENTS.md und `docs/development/` gliedern.
  Langfristige Profilbegründung ausschließlich in
  [ADR 0001](../../../docs/adr/0001-discourse-native-development.md),
  Runtime-Optionen in [ADR 0002](../../../docs/adr/0002-middleware-runtime.md).
  Beide bleiben gemäß freigegebenem Plan `proposed`.
- Neue Capability betrifft den Entwicklungsvertrag, nicht Office-Funktionen.
  Delta bleibt bis zur separat freizugebenden Archivierung im aktiven Change.
- Prüfmatrix und Quellenregister statt vorzeitigem Makefile, CI oder Lockfile.
  Ausführbares Produkttooling erhält einen eigenen Change; nicht ungefragt aufbauen.

## Risks / Trade-offs

- [Regeln sind keine technischen Gates] → Grenzen sichtbar dokumentieren;
  reale CI als eigenständige Folgearbeit planen.
- [Offizielle Quellen bewegen sich] → Prüfdatum/SHA festhalten und vor
  relevanten Änderungen erneut vergleichen; kein blindes Skeleton-Update.
- [PHP-Sicherheitsmängel bleiben] → im Entwicklungsindex benennen, keine
  Sicherheitsverbesserung durch diesen Dokumentations-Change behaupten.
- [ADR-Status wird als Freigabe missverstanden] → Status, Nutzerfestlegungen und
  noch offene Entscheidungen getrennt führen; Phase 2 ausdrücklich abgrenzen.

## Migration Plan

Nur additive Prozessintegration und README-Verweis; weder Daten-/API-Migration
noch Deployment. Ein Rückbau wäre auf die hier neu erstellten Harness-Dateien
begrenzt und würde gesondert abgestimmt; `guidelines/` und Produktcode bleiben
erhalten. Keine Archivierung oder Übernahme von Deltas nach `openspec/specs/`
ohne weitere ausdrückliche Freigabe.

## Open Questions

Ziel-Core-/Nextcloud-/Collabora-Versionen und lokale Testumgebung sind für den
Tooling-Folge-Change zu klären. Zusätzliches Node-/Python-Hosting bleibt offen;
eine Middleware-/Plugin-Migration braucht unabhängig davon einen eigenen Change.
