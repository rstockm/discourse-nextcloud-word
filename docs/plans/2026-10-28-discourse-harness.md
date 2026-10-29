# Discourse-Entwicklungs-Harness und Middleware-Perspektive

- Stand: 2026-10-28
- Status: Harness und OpenSpec am 2026-10-28 vom Nutzer zur Umsetzung freigegeben;
  keine Freigabe für Runtime-Migration, Tooling-/CI-Aufbau oder Archivierung
- Ausgangspunkt: Repository `2ac19e8`, Theme Component 2.1.0

## Ziel und Abgrenzung

Das bestehende Projekt erhält einen schlanken, Discourse-spezifischen Harness mit
offiziellem OpenSpec-Core-Workflow, nachvollziehbaren ADRs und überprüfbaren
Entwicklungsregeln. `guidelines/` bleibt als unveränderte Ausgangsbasis erhalten.
Keine ungefragten Commits, Pushes, Produktionszugriffe oder Runtime-Migrationen.

Die erste Umsetzung richtet Dokumentation und Planungsintegration ein. Der
Aufbau ausführbarer Theme-Tests, CI und die Modernisierung des Bestandscodes
werden als Folge-Change konkret geplant und separat freigegeben. Ein vorhandenes
Dokument oder grüner OpenSpec-Validator beweist keine funktionierende Anwendung.

## Übernahme und projektspezifische Abweichungen

- Übernehmen: kleine prüfbare Einheiten, menschliche Planfreigabe, Review,
  Retry-Cap, Geheimnisschutz, synthetische Testdaten, deutsche Prozessdokumentation
  und englischen Code.
- Eigenes Profil **Discourse Theme Component** statt Static App oder Service App.
  Kein Vite, Tailwind, React, Django oder Datenbankzwang im Theme. Discourse stellt
  die Laufzeit, UI-Komponenten, Übersetzungen und Design-Tokens bereit.
- DATA-GUIDELINES nur bei tatsächlich betroffenen Daten-/Importgrenzen anwenden;
  Datei-Validierung und Ressourcenlimits sind relevant, Analytics-Stack nicht.
- ADR-Pfad: `docs/adr/` entsprechend den eingebrachten Guidelines. Das weicht von
  der globalen Ausgangsvorlage `docs/decisions/` ab und wird ausdrücklich
  dokumentiert; es gibt keinen parallelen zweiten ADR-Bestand.
- OpenSpec ersetzt zusätzliche parallele Implementierungspläne: proposal,
  specs, design und tasks im Schema `spec-driven`. Dieses Dokument ist der
  einmalige Bootstrap-Plan vor Einrichtung von OpenSpec.

## Geplante Struktur

```text
AGENTS.md                         # Kurzer Projekteinstieg und verbindliche Regeln
docs/development/
  README.md                       # Entwicklungsablauf und reale Voraussetzungen
  discourse-standards.md          # Aktuelle APIs, UI-, Editor- und i18n-Regeln
  upstream-sources.md             # Offizielle Quellen, SHA/Version, Prüfdatum
  verification.md                 # Prüfmatrix, ausführbar vs. geplant/blockiert
docs/adr/
  README.md                       # Index und Statusregeln
  adr-template.md                 # Schlanke MADR-inspirierte Vorlage
  0001-discourse-native-development.md  # Vorschlag für das Entwicklungsprofil
  0002-middleware-runtime.md       # Optionen und offene Betriebsentscheidung
openspec/
  config.yaml                     # Projektkontext, core / spec-driven
  specs/                          # Freigegebenes Soll, nicht Wunschliste
  changes/                        # Aktive Changes und spätere Archive
.opencode/                        # Ausschließlich offizielle generierte OPSX-Dateien
```

Keine eigenen Agentenketten, OpenSpec-Schemas, Plugins oder automatische
Einbindung fremder Webinhalte als privilegierte Agentenanweisung. Eine zusätzliche
`opencode.json` wird nur angelegt, wenn sie neben automatisch erkanntem AGENTS.md
einen konkreten Zweck erfüllt; keine redundante Kopie aus `guidelines/`.

## Aktualität als verbindlicher Arbeitsablauf

1. Vor Einrichtung und jeder relevanten API-/Tooling-Änderung aktuelle offizielle
   Theme-Skeleton-, Discourse-Core-, Theme-CLI- und Developer-Guide-Quellen prüfen.
   Bei API-Nutzung die Signatur und Deprecations am Ziel-Core-Stand nachlesen.
2. Quellen mit Prüfdatum und nach Möglichkeit Commit-SHA beziehungsweise
   Release-Version festhalten. Bei Nichterreichbarkeit keine Aktualität behaupten;
   relevante Umsetzung bis zur Klärung blockieren.
3. Geprüfte Versionen und Lockfiles sichern. Updates erfolgen als überprüfte
   Changes, nicht bei jedem Build über ungebundenes `latest`.
4. Neue UI als moderne Glimmer-Komponenten mit `.gjs`/`.gts` und nativen
   Discourse-Komponenten/Modal-Service planen. Keine neu eingeführten klassischen
   Controller-Modals, Widget-Muster oder HTML-String-Dialoge.
5. Öffentliche Plugin-APIs, Outlets und Transformer bevorzugen. `modifyClass` ist
   nicht pauschal verboten oder pauschal deprecated; jeder konkrete Einsatz
   braucht einen belegten Grund und Prüfung der aktuellen Schnittstelle.
6. Aktuelle `discourse-i18n`-Imports statt globalem `I18n` für neuen Code;
   lokalisierbare Settings-Beschreibungen und native Tokens verwenden.
7. Markdown- und Rich-Text-Composer ausdrücklich prüfen. Keine unbewiesenen
   Kompatibilitätszusagen aus `minimum_discourse_version: 2.8.0` übernehmen.
8. Vorabversionen aus dem offiziellen Skeleton ausdrücklich markieren und ihre
   Übernahme begründen. Nicht stillschweigend durch ältere eigene Vorlagen ersetzen.

## Kleine Umsetzungseinheiten nach Freigabe

### 1. Offizielle OpenSpec-Integration

- Zum Ausführungszeitpunkt aktuelle stabile OpenSpec-Version erneut prüfen;
  aktuell lokal 1.14.1, npm `latest` 1.15.0.
- Exakt versionierten CLI-Aufruf für das Projekt verwenden, keine globale
  Installation oder globale Konfiguration ungefragt ändern.
- Mit offiziellem `init --tools opencode --profile core --no-animation`
  initialisieren und die erzeugten Commands/Skills vor Nutzung lesen.
- Bootstrap-Change `establish-discourse-development-harness` über offiziellen
  Workflow mit proposal/specs/design/tasks erstellen; auf diesen Plan verweisen.
- Prüfung: CLI-Version, generierte Dateien, `openspec list --json`, Artefaktstatus.

### 2. Projektharness und überprüfbare Standards

- Die oben genannten Entwicklungsdokumente und kurze Root-AGENTS.md erstellen.
- Aktuelle Quellen und Abweichungen erfassen; Bestandsmängel als solche benennen.
- Prüfmatrix für Formatierung, Lint, Typen, Unit-/Integration-/Systemtests,
  responsive UI, Accessibility und Deployment dokumentieren.
- Keine erfundenen Befehle als erfolgreich verifiziert ausgeben. Ein zukünftiges
  `make check` soll vorhandene echte Prüfungen bündeln, keine fehlenden Tests
  durch erfolgreiche Platzhalter kaschieren.
- Prüfung: Pfade, Links, Quellenbelege, Konsistenz und Scope-Review.

### 3. Architekturentscheidungen als Vorschläge

- ADR-Vorlage und Index einrichten, Entwicklungsprofil als `proposed` begründen.
- Middleware-Optionen samt Sicherheits- und Betriebsgrenzen im zweiten ADR
  festhalten. Keine Sprache auswählen, solange relevante Betriebsfragen offen sind.
- Aktuelle öffentliche Shares nicht als Discourse-ACL ausgeben. Browser-Key und
  Origin nicht als vertrauenswürdige Benutzer-Authentifizierung modellieren.
- Prüfung: Status bleibt ohne ausdrückliche Zustimmung `proposed`, keine
  erfundenen Entscheidungsträger, Verlinkung mit dem Change.

### 4. Validieren und Folgearbeit abgrenzen

- `openspec validate establish-discourse-development-harness --strict --no-interactive`.
- Alle vorhandenen Specs/Changes ebenfalls strikt validieren; Diff und Status prüfen.
- Keine automatische Archivierung; dafür ist eine eigene ausdrückliche Freigabe nötig.
- Folge-Change für offizielles Skeleton-Tooling und Tests vorbereiten, sofern gewünscht.
  Legacy-Lint-/Typfehler transparent erfassen, nicht pauschal unterdrücken.

## Verifikationsziel für den Folge-Change

- pnpm und offizielle `@discourse/lint-configs` nach aktuellem Skeleton;
  kompatible exakte Toolversionen und projektbezogene Lockfiles.
- QUnit-/Ember-Tests unter `test/`, Systemtests unter `spec/system/` im echten
  Discourse-Kontext; offizieller wiederverwendbarer Theme-CI-Workflow.
- Native Tests statt einer zusätzlichen unabhängigen Vitest-/Vite-Anwendung.
- Typprüfung entsprechend geprüftem Skeleton und Discourse-Typen, nicht als
  Ersatz für Tests oder als vermeintliche vollständige Prüfung alten JavaScripts.
- Middleware-Vertragstests mit gemocktem WebDAV/OCS; keine Produktionszugriffe.
- Szenarien: Dateikollisionen, Uploadfehler, Sharefehler, Passwortschutz und
  logfreie Geheimnisse, Dateivalidierung, Größenlimits, Wiederholungen,
  Entwurfswechsel, Markdown und Rich Text.
- UI: Tastatur, Fokusführung, verständliche Lade-/Fehlerzustände, WCAG 2.2 AA;
  tatsächliche Geometrieprüfung auf Überlauf, Überlappung und Abschneiden bei
  1440×1000, 1024×900, 768×1024 und einem Smartphone-Viewport ab 320 CSS-Pixel.
  In die gewählte native Testumgebung integrieren, keine zweite Plattform ohne Bedarf.
- Ziel-Core-Version, Nextcloud- und Collabora-Versionen und Testumgebung vor
  Kompatibilitätszusagen festlegen. Lokale Voraussetzungen sind noch nicht verifiziert.

## Können wir PHP entfernen?

Ja. Die Middleware erledigt im Wesentlichen HTTP-Eingang, Dateiprüfung, WebDAV-PUT
und OCS-Share-Erstellung. Diese Aufgaben benötigen PHP nicht. Ein Rewrite ist
aber kein Ersatz für Authentifizierung, Überschreibschutz oder sichere Logs.

| Option | Vorteile | Nachteile / Bedingungen |
| --- | --- | --- |
| PHP behalten und absichern | Kleinster Eingriff, bestehendes LAMP-Deployment bleibt nutzbar | Zweite Sprache bleibt; aktuelle Sicherheits- und Fehlerrisiken müssen trotzdem behoben werden |
| Separater TypeScript-Dienst auf Node.js | Gleiche Sprachfamilie wie das Theme, typisierter API-Vertrag, gute HTTP-Testbarkeit | Eigener Prozess/Container, Reverse Proxy, Limits und Betrieb nötig; Theme und Server bleiben getrennte Sicherheitsdomänen |
| Python-Dienst | Anschluss an die eingebrachten Python/uv-Guidelines, gute Testbarkeit | Zusätzliche Sprache bleibt; Django kann für den kleinen Endpoint überdimensioniert sein, ein schlankeres Framework wäre begründungspflichtige Abweichung |
| Backend in einem Discourse-Ruby-Plugin | Discourse-Sitzung, Autorisierung und serverseitige Secrets direkt integrierbar; separater Middleware-Dienst kann entfallen | Nicht mehr als reine Theme Component installierbar; Server-/Plugin-Deployment und Betriebsfreigabe nötig |
| Nur Browser, kein Backend | Kein eigener Dienst | Für das vorhandene Modell mit Nextcloud-Service-Zugangsdaten ungeeignet: Secrets wären öffentlich; kein tragfähiger Ersatz |

Vorläufige Empfehlung: Soll die Lösung per Theme-Installation auf Discourse nutzbar
bleiben und ist ein eigener Dienst betreibbar, ist ein kleiner TypeScript-Dienst
der naheliegende PHP-Ersatz. Sind verbindliche Discourse-Berechtigungen wichtiger
und Plugins installierbar, ist ein Ruby-Plugin die ernsthaftere Architektur-Option.
Bei ausschließlich vorhandenem LAMP-Hosting kann PHP kurzfristig die sinnvollste
Wahl bleiben. Keine dieser Optionen wird mit der Harness-Freigabe implementiert.

Jede spätere Migration braucht einen expliziten API-Vertrag, Fehlersemantik,
serverseitige Authentifizierungsstrategie, kollisionssichere Pfade, Timeouts,
Ressourcenlimits, Bereinigung verwaister Dateien und einen Rückweg. Existierende
Share-URLs und Dateien sollen durch einen Sprachwechsel nicht verloren gehen.

## Freigabe und verbleibende Betriebsfragen

- Harness und OpenSpec sind freigegeben. Umsetzung und Nachweis werden im Change
  [establish-discourse-development-harness](../../openspec/changes/establish-discourse-development-harness/proposal.md)
  geführt; dieser Bootstrap-Plan wird nicht als zweiter Task-Bestand weitergeführt.
- Backend-Plugins sind auf der Zielinstallation möglich. Der Nutzer nennt sie
  als potenziell robustere Alternative bei aufwendigerem Testen. Das ist keine
  Freigabe einer konkreten Plugin-Migration.
- Eine Ableitung des Discourse-Rechtesystems ist ausdrücklich erst Phase 2.
  Die knappe Antwort zur dritten Frage wird durch diese ausdrückliche
  Phaseneinordnung konkretisiert; keine sofortige ACL-Umsetzung ableiten.
- Ob zusätzlich Node-/Python-Dienste oder Container betrieben werden können,
  bleibt offen; für den Harness ist das kein Blocker.

## Quellen und geprüfter Stand

Am 2026-10-28 abgerufen; bei Umsetzung erneut prüfen. Verlinkte `main`-Branches
sind veränderlich, der Skeleton-SHA dokumentiert den konkreten Recherche-Stand.

- Eingebrachte `guidelines/AGENTS.md`, `GUIDELINES.md`, `DATA-GUIDELINES.md`, `opencode.json`.
- [Offizielles Theme-Skeleton](https://github.com/discourse/discourse-theme-skeleton),
  Commit `ddf372574ecf94f7062659f3498df403a4036907` vom 2026-10-19.
  Geprüft: package.json, tsconfig.json, Repository-Struktur und Theme-CI-Einstieg.
  Derzeit Node >=22, pnpm 12.11.2 und TypeScript 7.1.0-dev.20260930.4.
- [Offizieller Einstieg Theme-Entwicklung](https://meta.discourse.org/t/developing-discourse-themes-theme-components/93648).
  Der überarbeitete erste Beitrag verweist auf das moderne Tutorial; alte
  Diskussionen/Codebeispiele darunter sind nicht automatisch aktuelle Anleitungen.
- [Aktuelle Quick Reference](https://meta.discourse.org/t/theme-developer-quick-reference-guide/110448).
- [Plugin-API im Core](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/plugin-api.gjs).
  Geprüft u. a. funktionale Composer-Menü-Actions, Outlets, Transformer und die
  differenzierte Deprecation von modifyClass für Model-Typen.
- [Theme CLI](https://github.com/discourse/discourse_theme): lokale Entwicklung
  und `discourse_theme rspec PATH` mit Discourse-Checkout oder Docker.
- [Offizieller Theme-CI-Workflow](https://github.com/discourse/.github/blob/main/.github/workflows/discourse-theme.yml).
- [OpenSpec CLI](https://github.com/Fission-AI/OpenSpec/blob/main/docs/cli.md)
  und [npm latest](https://registry.npmjs.org/@fission-ai/openspec/latest): 1.15.0.
  Optionen sind vor Verwendung gegen die tatsächlich gewählte CLI-Version zu prüfen.
- [OpenCode V2 Instructions](https://opencode.ai/v2/docs/instructions): Root-AGENTS.md
  wird automatisch geladen; keine redundante `instructions: ["AGENTS.md"]` nötig.
