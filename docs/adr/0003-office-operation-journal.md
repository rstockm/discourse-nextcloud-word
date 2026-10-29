# 0003: Begrenztes Journal für sichere Office-Operationen

- Status: proposed
- Datum: 2026-10-28
- Entscheidungsträger: noch nicht bestätigt
- Freigabegrenze: ADR weiterhin Vorschlag; Implementierungsfreigabe über den Change, nicht durch diesen Status

## Kontext und Problem

Datei-PUT und Share-Erstellung sind entfernte Mutationen ohne gemeinsame
Transaktion mit Discourse. Doppelklicks, verlorene Antworten oder Prozessabbrüche
dürfen weder vorhandene Dokumente überschreiben noch unkontrolliert weitere
Dateien/Shares erzeugen. Eine bloße Sprachmigration behebt diese Fenster nicht.

## Betrachtete Optionen

- Kein Zustand, bei Fehler erneut senden: minimal, aber keine verlässliche
  Deduplizierung oder sichere Bereinigung nach Prozessabbrüchen.
- Ausschließlich Cache/Lock oder PluginStore: weniger Schemaarbeit, aber TTL/
  Locks allein reichen nicht; Unique-Constraints, Statussuche und Reparaturfälle
  wären schwerer nachvollziehbar oder müssten zusätzlich modelliert werden.
- Kleine ActiveRecord-Tabelle: klare Constraints und nachvollziehbare Zustände,
  benötigt jedoch Migration, Aufbewahrung und Datenschutzbetrachtung.

## Entscheidung und Begründung

Vorschlag: ein kleines serverseitiges Vorgangsjournal mit Unique-Index auf
Nutzer/Operation-Key, Payload-Fingerprint, exklusivem Zielpfad, Dateinachweis,
Share-ID, Ergebnis und sicheren Status-/Zeitangaben. Keine Dateiinhalte oder
Klartext-Passwörter speichern; Passwortvergleich nur über serverseitig keyed HMAC.

Ein vorhandener verteilter Core-Lock ergänzt den Datenbank-Constraint, ersetzt
ihn nicht. Netzaufrufe laufen außerhalb langer DB-Transaktionen. Unklare
Remote-Ergebnisse werden vor einer Wiederholung abgeglichen. Das ist keine
behauptete verteilte Exactly-once-Transaktion.

## Konsequenzen

- Positiv: Wiederholungen über Prozesse/Neustarts hinweg nachvollziehbar;
  Statuszugriff nur für den auslösenden Nutzer, sichere gezielte Bereinigung.
- Negativ: zusätzliche lokale Daten und Migration. Share-Ergebnisse sind
  zugriffsgewährend und verlangen serverseitigen Zugriffs-/Backup-Schutz.
- Wiederholungsfenster sieben Tage; fertige Journaldaten anschließend begrenzt
  aufbewahren/purgen, ungelöste Fälle bis zur kontrollierten Auflösung erhalten.
  Journalbereinigung löscht keine fertigen Nextcloud-Dokumente.
- Keine Verknüpfung mit Topic-/Gruppenrechten oder späterem Rechtewiderruf;
  dies ist Betriebszustand für Phase 1, keine vorgezogene Phase-2-ACL.

## Überprüfung

Vereinfachung vom 2026-10-29, vom Nutzer zur Umsetzung freigegeben (ADR weiterhin
`proposed`): Abgleich nur bei erneuter Anfrage/Statusabfrage. Keine periodischen
Remote-Jobs oder automatischen Nextcloud-Löschungen. Unvollständige Fälle bleiben
für gezielte Betreiberbereinigung sichtbar; nur abgeschlossene lokale
Journaldaten werden nach Frist entfernt. Weniger Betriebs-/Datenverlustrisiko,
dafür bleiben verwaiste Dateien bis zum manuellen Eingriff bestehen.

Migrations-/Unique-Index-, Parallelitäts-, Payload-Konflikt-, Statuszugriffs-,
Timeout-/Crash-Recovery- und Cleanup-/TTL-Tests. Sicherstellen, dass fehlendes
Passwort im Hintergrund niemals zu einem ungeschützten Share führt und fremde
oder erfolgreich erstellte Ressourcen nie automatisch gelöscht werden.

## Verknüpfungen

- [Migrations-Change](../../openspec/changes/migrate-office-integration-to-plugin/proposal.md)
- [Operations-Spec](../../openspec/changes/migrate-office-integration-to-plugin/specs/office-storage-operations/spec.md)
- [Sicherheits-Spec](../../openspec/changes/migrate-office-integration-to-plugin/specs/office-request-security/spec.md)
