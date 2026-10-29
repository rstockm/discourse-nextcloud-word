# Entwicklung

Dieses Projekt besitzt einen Discourse-spezifischen Harness. Er dokumentiert
Regeln und Nachweise, ersetzt aber keine Tests und keine CI-Gates.

## Orientierung

- [Discourse-Standards](discourse-standards.md): verbindliche Vorgaben für neue Arbeit.
- [Quellenregister](upstream-sources.md): geprüfter offizieller Stand und Aktualisierung.
- [Verifikation](verification.md): verfügbare Checks, Lücken und zukünftige Abnahme.
- [Serververtrag](server-contract.md): Endpoints, Settings, Auth- und Fehlerformat.
- [Abnahmematrix](acceptance-matrix.md): Spec-Szenarien und ihre Nachweise.
- [Betrieb](operations.md): Installation, Abnahme auf Testinstanz, Incident, Rollback.
- [Architekturvorschläge und Status](../adr/README.md).
- Ursprung und Freigabe: [Bootstrap-Plan](../plans/2026-10-28-discourse-harness.md).
- Aktueller Change:
  [establish-discourse-development-harness](../../openspec/changes/establish-discourse-development-harness/proposal.md).

## Zielpfad: Plugin

```text
Discourse-Composer (Plugin) → Plugin-Endpoint → Nextcloud WebDAV + OCS → Share-Link
                                                                         ↓
                                                             Collabora über Nextcloud
```

Das Plugin (`discourse-nextcloud-office`) ersetzt die alte Theme-Component plus
PHP-Middleware. Es bietet Vorlagenerstellung, optionales Share-Passwort und die
einmalige Übertragung von sechs Office-Formaten aus dem Composer. Kein
dauerhafter Dateiabgleich und keine Bindung der Shares an Discourse-Gruppen-/
Topic-Rechte (Phase 2). Zielversionen von Discourse/Nextcloud/Collabora sind in
[operations.md](operations.md) festgehalten; ein Abnahmelauf gegen eine echte
Instanz fehlt noch.

Der Legacy-Code (`javascripts/`, `common/`, `locales/`, `settings.yml`,
`about.json`, `create-office-file.php`) liegt noch im Repository, ist aber nicht
mehr Teil des Ladepfads und wird nicht mehr aktualisiert. Entfernung erst nach
Freigabe (Aufgabe 6.3).

## Arbeitsablauf

1. Anforderung klären; relevante Quellen, Specs, aktive Changes und ADRs lesen.
2. Aktuelle offizielle Discourse-Quellen prüfen und den Stand festhalten.
3. Optional `/opsx-explore`, dann `/opsx-propose <idee>` für relevante Änderungen.
   Proposal, Specs, Design und kleine prüfbare Tasks beschreiben genau einen Scope.
4. Plan vor Umsetzung ausdrücklich freigeben lassen. Kleine risikoarme Fixes
   benötigen keine Pflicht-Spec; Sicherheits-/Datenverlustrisiken bleiben explizit.
5. `/opsx-apply <change>`: unitweise umsetzen, prüfen und erst dann Tasks abhaken.
   Scope-Abweichungen erneut abstimmen; nach drei Fehlversuchen derselben Einheit stoppen.
6. Review und strikte OpenSpec-Validierung plus passende echte Produktchecks.
7. Nur nach weiterer ausdrücklicher Freigabe `/opsx-archive <change>`.
   Das aktualisiert Soll-Specs und archiviert; keine vorzeitige manuelle Kopie.

Offiziell generiert sind außerdem `/opsx-update` und `/opsx-sync`. Änderungen am
Vertrag gehören weiterhin zur abgestimmten Planung; Sync ist keine Umgehung der
Review-/Freigabegrenzen. Die generierten Commands und Skills bleiben unverändert.

OpenSpec-CLI-Aufrufe dieses Projekts nutzen die exakte Version:

```sh
npx --yes @fission-ai/openspec@1.15.0 list --json
npx --yes @fission-ai/openspec@1.15.0 validate --all --strict --no-interactive
```

Node.js/npm und Registry-Zugriff beziehungsweise ein vorhandener npm-Cache sind
dafür nötig. Die Einrichtung wurde mit Node 24.16.0 ausgeführt. Der globale
OpenSpec-Stand 1.14.1 wurde nicht ersetzt; generierte Anweisungen mit `openspec`
sind bei CLI-Ausführung auf den obigen exakt versionierten Aufruf abzubilden.

## Entwicklungsumgebung und Prüfeinstieg

Lokale, isolierte Testumgebung: [local-tests.md](local-tests.md).
Gesamteinstieg für alle Checks: `bash script/check` (siehe
[verification.md](verification.md)); `--fast` überspringt Datenbank und Browser.
Ein Abnahmelauf gegen eine echte Testinstanz ist in [operations.md](operations.md)
beschrieben und weiterhin offen.

Nie Produktionszugänge oder echte Dokumente als Fixtures verwenden. Ein Betrieb
auf einer Testinstanz nur mit synthetischen Dokumenten und ausdrücklich
freigegebenen Zugängen.

Die im alten Theme-/PHP-Weg bekannten Risiken (Überschreiben gleicher Pfade,
öffentlicher Browser-Key, Passwortdaten im Share-Fehlerlog, permissive
MIME-Prüfung, Uploadfehler-Fallback, Entwurfswechsel während asynchroner
Übertragung) adressiert das Plugin. Der Legacy-Code selbst ist unverändert und
wird nicht mehr gepflegt; die alte `MIDDLEWARE.md` beschreibt diesen Altweg.
