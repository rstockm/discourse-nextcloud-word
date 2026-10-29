# Offizielle Quellen und geprüfter Stand

Zuletzt geprüft: **2026-10-28**. Dieses Register belegt die Einrichtung,
nicht eine dauerhaft garantierte Aktualität. Zielversionen des betriebenen
Discourse/Nextcloud/Collabora sind noch nicht bekannt.

## Referenzen

| Quelle | Geprüfter Stand | Verwendung |
| --- | --- | --- |
| [Theme-Skeleton](https://github.com/discourse/discourse-theme-skeleton) | `ddf372574ecf94f7062659f3498df403a4036907`, 2026-10-19; HEAD am Prüfdatum bestätigt | Struktur, package.json, tsconfig.json, CI-Einstieg |
| [Discourse Core](https://github.com/discourse/discourse) | `ed9ca7fd7542c862ab64b1a71b8b267e03a2ad74`, 2026-10-28 | Offizieller Theme-Einstieg, Quick Reference und konkrete Plugin-API |
| [Theme CLI](https://github.com/discourse/discourse_theme) | `cdc18da0174c2b70989424d5546749063698aed8`; HEAD am Prüfdatum bestätigt | README: watch/upload und rspec mit Checkout oder Docker |
| [Gemeinsamer Theme-CI-Workflow](https://github.com/discourse/.github/blob/main/.github/workflows/discourse-theme.yml) | Repository-HEAD `83e5990bc53a4e0eddabda672558e29382072bd6`, 2026-10-26 | Lint, Typen, Frontend-, Backend- und Systemtest-Erkennung; noch nicht installiert |
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | npm `latest` = `1.15.0`, lokaler exakt versionierter Aufruf bestätigt | Offizielles Core-Profil und OpenCode-Integration, Schema `spec-driven` |
| [OpenCode V2 Instructions](https://opencode.ai/v2/docs/instructions) | Am Prüfdatum abgerufen, nicht versionierter Webstand | Root-AGENTS.md wird automatisch erkannt |

Konkrete Core-Quellen:

- [Theme-Einstieg](https://github.com/discourse/discourse/blob/ed9ca7fd7542c862ab64b1a71b8b267e03a2ad74/docs/developer-guides/docs/05-themes-components/01-developing-themes.md).
- [Quick Reference](https://github.com/discourse/discourse/blob/ed9ca7fd7542c862ab64b1a71b8b267e03a2ad74/docs/developer-guides/docs/05-themes-components/02-quick-reference.md).
- [Plugin-API](https://github.com/discourse/discourse/blob/ed9ca7fd7542c862ab64b1a71b8b267e03a2ad74/frontend/discourse/app/lib/plugin-api.gjs):
  funktionale Composer-Menü-Actions, Outlets, Transformer und differenzierte
  `modifyClass`-Deprecation. Kein pauschaler Beleg für alle weiteren API-Nutzungen.
- [Moderner Tutorial-Einstieg](https://meta.discourse.org/t/theme-developer-tutorial-1-introduction/357796)
  wird vom offiziellen Einstieg empfohlen; vor Übernahme einzelner Tutorial-Muster erneut lesen.

## Beobachtete Skeleton-Werkzeuge, nicht installierte Projektabhängigkeiten

`package.json` des geprüften Skeleton: Node >=22, pnpm 12.11.2,
`@discourse/lint-configs` 3.8.2, ESLint 10.6.0, Prettier 3.8.1,
Stylelint 17.5.0, `@discourse/types` 2026.10.0-a5125163 und
TypeScript **7.1.0-dev.20260930.4** mit `ember-content-mapper`.
Diese Liste ist ein Recherchebeleg, keine unbesehene Installationsanweisung.

Die TypeScript-Version ist eine Vorabversion. Ein Tooling-Change muss vorab
begründen, ob er das offizielle Setup übernimmt oder eine kompatible Abweichung
vorschlägt; nicht stillschweigend eine alte Vorlage bevorzugen.

## Aktualisierung

1. Vor relevanten Änderungen aktuellen offiziellen Stand und betroffene
   Ziel-Core-Schnittstelle abrufen; bei widersprüchlichen Quellen Konflikt offenlegen.
2. Prüfdatum, Version/SHA und entscheidungsrelevante Unterschiede im Change
   beziehungsweise diesem Register festhalten. Keine Aktualität bei Abruffehlern behaupten.
3. Versionsupdates als expliziten überprüften Diff ausführen, Lockfiles/Tests
   berücksichtigen. Generierte Ergebnisse bei Konflikten nicht überschreiben.
4. OpenSpec-Updates ebenfalls bewusst versionieren und dann offizielle Integration
   erneuern. Keine eigenen Änderungen an generierten Commands/Skills pflegen.

Die ursprünglichen `guidelines/` wurden gelesen, aber nicht verändert. Ihr
Vite-/Tailwind- bzw. Django-Referenzstack wird durch das Discourse-Profil ersetzt;
Prozess, Sicherheit und passende Datei-Validierungsregeln werden übernommen.
