# Architekturentscheidungen

Eine langlebige Entscheidung pro nummerierter Datei, schlank nach
[Vorlage](adr-template.md). Nächste freie Nummer verwenden. Dieser Ordner folgt
den eingebrachten Guidelines; kein paralleler Bestand unter `docs/decisions/`.

| ADR | Status | Gegenstand |
| --- | --- | --- |
| [0001](0001-discourse-native-development.md) | proposed | Discourse-natives Entwicklungsprofil |
| [0002](0002-middleware-runtime.md) | proposed | PHP-Ablösung und mögliche Plugin-Richtung |
| [0003](0003-office-operation-journal.md) | proposed | Journal für Wiederholungen und entfernte Teilfehler |

## Lebenszyklus

- `proposed`: begründeter Vorschlag, noch keine bestätigte Architekturentscheidung.
- `accepted`: erst nach ausdrücklicher menschlicher Zustimmung; Datum und
  bestätigte Entscheidungsträger dokumentieren. Harness-Freigabe ist nicht
  automatisch Akzeptanz aller Architekturvorschläge oder Migrationsfreigabe.
- `rejected`: abgelehnter Vorschlag bleibt nachvollziehbar.
- `superseded`: neues ADR ersetzt eine akzeptierte Entscheidung; altes ADR nur
  um Status und Nachfolger-Link ergänzen, historische Begründung erhalten.

ADRs erklären Warum und Alternativen. Specs definieren beobachtbares Verhalten,
Changes planen die Umsetzung; keine unabhängig gepflegten Kopien derselben
Begründung. Relevante Specs/Changes gegenseitig verlinken und bei ausdrücklich
freigegebener Archivierung Links aktualisieren.
