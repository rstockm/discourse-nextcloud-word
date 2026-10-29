# Design

## Context

Siehe [Proposal](proposal.md) für Ziele, Funktionserhalt und Nicht-Ziele;
[research.md](research.md) dokumentiert die aktuelle offizielle Quellenprüfung.
Der Nutzer hat ein vollständiges Plugin gewählt. Es gibt bisher keine produktiven
Specs oder Testplattform; der Harness-Change ist fertig, aber noch nicht archiviert.

## Goals / Non-Goals

**Goals:** ein installierbarer Plugin-Bestand, sicherer gleich-originiger
Serververtrag, kleine fachliche Bausteine, echte Tests vor Entfernung des Altcodes.

**Non-Goals:** Weiterbetrieb zweier produktiver Schreibwege, alte PHP-API
emulieren, zusätzliche SPA/Queue-Plattform, Topic-ACL oder nachträgliche
Änderung alter Dokumente/Posts. Synthetische Testumgebung statt Produktionszugriff.

## Decisions

### Verbindliche KISS-Vereinfachung (2026-10-29)

Vom Nutzer zur Umsetzung freigegeben: kleines Journal und Abgleich vor Wiederholung bleiben, aber
Abgleich erfolgt bei erneuter Anfrage/Statusabfrage. Kein periodischer
Remote-Job, keine automatische entfernte Löschung, kein `cleanup_pending`.
Unvollständige Fälle bleiben für gezielte Betreiberbereinigung sichtbar;
nur abgeschlossene lokale Journaldaten werden nach Frist entfernt.

Transport nur für interne relative API-Pfade und explizite Query-Parameter;
kein generischer URL-Resolver oder Blacklist-Framework. JSON explizit anfordern,
kein spekulativer XML-Fallback. Erfolgsantwort als Hash, Share-URL-Prüfung einmal
im OCS-Adapter statt zusätzlicher DTO-Klasse. Echte Gesamtdauergrenze und
besitzgebundene Parallelitäts-Leases; private Ziele nur nach expliziter Freigabe.
ZIP-Sicherheitsprüfungen bleiben; vor Erweiterung des rohen Verzeichnislesers
Bibliotheksmöglichkeiten prüfen. Vertrag zentral im Serververtrag dokumentieren.

### 1. Plugin und aktuelles Skeleton

Pluginname zunächst `discourse-nextcloud-office`, Ruby-Namespace
`DiscourseNextcloudOffice`, Plugin an der Repository-Wurzel. Namenswahl ist eine
Planungsannahme; GitHub-Repository wird nicht ungefragt umbenannt.

Aktuelles offizielles Plugin-Skeleton statt Theme-Skeleton verwenden. Gemeinsame
Frontend-Werkzeuge bleiben gleich, Pfade/CI/i18n folgen den Plugin-Konventionen:

```text
plugin.rb
lib/discourse_nextcloud_office/engine.rb
lib/discourse_nextcloud_office/       # Nextcloud-Client, Validierung, Orchestrierung
app/controllers/discourse_nextcloud_office/
app/models/discourse_nextcloud_office/
assets/javascripts/discourse/        # Initializer, Service, Glimmer-Dialog
assets/stylesheets/common/
config/routes.rb
config/settings.yml
config/locales/{client,server}.{en,de}.yml
db/migrate/
templates/                          # synthetische makrofreie Office-Vorlagen, kein Alt-HBS
spec/{requests,lib,models,system}/
test/javascripts/
.github/workflows/discourse-plugin.yml
```

Vor Umsetzung Quellen erneut prüfen; initiale Core-Testbaseline ist
`adf7244270b88a5485b32c7e815217e35c68b4e4`. Keine alte Mindestversion 2.8 übernehmen.
Skeleton-Versionen inklusive ausdrücklich markierter TypeScript-Vorabversion
laut Recherche zunächst als zusammenhängendes Setup übernehmen, mit Lockfiles
und tatsächlicher Typprüfung. Keine pauschalen Lint-/Typ-Unterdrückungen.

Architekturrichtung: [ADR 0002](../../../docs/adr/0002-middleware-runtime.md).
Vorgangsspeicherung: [ADR 0003](../../../docs/adr/0003-office-operation-journal.md).
Beide bleiben bis zur menschlichen Zustimmung `proposed`.

### 2. Serververtrag statt Browser-Secret

Eine isolierte Rails-Engine mit zwei mutierenden Endpoints und einem lesenden
Statusendpoint; alle erfordern Sitzung, zulässiges aktives Konto und aktiviertes,
konfiguriertes Plugin. CSRF nicht deaktivieren. Keine zusätzliche Phase-2-ACL.

| Endpoint, geplant | Eingabe | Ergebnis |
| --- | --- | --- |
| `POST /nextcloud-office/documents` | JSON: `file_name`, `file_type`, optional `share_password`, `operation_key` | Vorlagendatei plus Share |
| `POST /nextcloud-office/transfers` | Multipart: `file`, `file_name`, `file_type`, `operation_key` | bestehende Datei plus Share |
| `GET /nextcloud-office/operations/:operation_key` | keine mutierende Nutzlast | nur eigener Status / eigener Erfolgslink |

Erfolg: `success`, `operation_key`, `url`, `file_name`, `file_type`, `has_password`;
Status-/Erfolgsantworten `Cache-Control: no-store`. Sicherer Fehler: `error_code`,
lokalisierbarer Text, Korrelationskennung, gegebenenfalls `retry_after`.
Keine Rohantworten, Passwörter oder Accountdetails in Fehlerantworten.
Geplante Fehlerklassen: 400 ungültig, 403 nicht berechtigt/CSRF, 404 fremder
Vorgang, 409 Schlüsselkonflikt/in Bearbeitung, 413 zu groß, 415 ungültiges Format,
429 Rate-Limit, 502/504 Nextcloud-Fehler/Timeout. Auth-Details an Core angleichen.

Admin-Settings: Plugin aktiviert (default false), Nextcloud-HTTPS-Basis-URL,
Servicekonto/App-Passwort, Zielordner, Formatauswahl und begrenzte Limits.
Zugangsdaten server-only, Passwort als `secret: true`, niemals `client: true`.
Keine Verschlüsselungsgarantie aus `secret` ableiten; Admin-/DB-/Backup-Schutz
dokumentieren. Nur notwendige UI-Settings und Formatauswahl zum Client geben.

### 3. Uploadquelle: validierte Bytes, keine Download-URL

Native Discourse-Uploads bleiben zuerst bestehen. Der Browser lädt ausschließlich
die vom nativen Upload gelieferten erlaubten Downloadpfade mit den vorgesehenen
Sitzungs-/Signed-URL-Mechanismen und sendet Bytes an den gleich-originigen
Multipart-Endpoint. Cookies nur an die eigene Origin; keine fremden URLs aus
Nutzereingaben. CDN/S3 nur entsprechend tatsächlicher Discourse-Konfiguration.

Bewusster Trade-off: eine zusätzliche Byte-Übertragung wie bisher, dafür keine
neue Upload-ID-Zugriffsprüfung mit Deduplizierungs-/Ownership-Fallen. Der Server
behauptet **nicht**, ein Multipart-Request sei beweisbar zuvor durch Discourse
gelaufen, sondern erzwingt selbst dieselben relevanten Typ-/Größenbeschränkungen
und zusätzliche Office-Prüfung. Direkte Plugin-Anfragen umgehen keine Validierung.
`downloadUrl`/beliebige externe URL-Fallbacks werden nicht übernommen.

### 4. Bausteine und Grenzen

- **Controller:** Sitzung, Pluginzustand, Parameter-/Body-Limits, Rate-Limits und
  sichere Antwort; keine WebDAV-Logik im Controller.
- **Validator:** Unicode-sichere Namen, Byte-/Paketbudgets und formatspezifische
  OOXML-/ODF-Strukturprüfung; keine Office-Ausführung oder Konvertierung.
- **Nextcloud-Client:** Upload mit Vorbedingung, Share anlegen/abfragen/löschen,
  sichere Antwortinterpretation. Kleine Schnittstelle statt generischem SDK.
- **Operationsdienst/-modell:** Zustandsübergänge, Parallelitäts-/Wiederholschutz,
  Abgleich und nachweislich sichere Bereinigung.
- **Frontend-Service/Dialog:** nativer Composer-/Modal-Service, API-Aufrufe,
  Entwurfsbindung und nutzerfreundliche Zustände.

Bestehende Core-/Ruby-Abhängigkeiten für HTTP, sichere XML- und ZIP-Verarbeitung
nutzen. Fehlt etwas, erst konkreten Bedarf und Lizenz im Change begründen;
kein neues Office-SDK, kein LibreOffice-Server und kein separates Backend-Framework.

### 5. Dateivalidierung und Ressourcenbudgets

Vor jeder entfernten Mutation: Eingaben typisieren, unzulässige Steuerzeichen/
Pfadbestandteile entfernen, Unicode nicht byteweise zerstören, Länge in UTF-8-
Bytes sicher begrenzen. Endung genau einmal und konsistent zum Format anwenden.
Dateinamen und Linklabels kontextgerecht escapen; keine HTML-/Markdown-Injektion.

OOXML: Paket-/Content-Type-/Relationship-Struktur und zugehörige Hauptteile
prüfen (`word/document.xml`, `xl/workbook.xml`, `ppt/presentation.xml`). ODF:
passenden `mimetype`, Manifest und `content.xml` plausibilisieren. Nur ZIP/MIME
zu erkennen genügt nicht. Verschlüsselung, getarnte Makrotypen, Traversal,
Symlinks, doppelte Einträge und gefährliche XML-Deklarationen abweisen. Niemals
frei extrahieren, Makros ausführen oder externe Relationships/Entitäten abrufen.
Das ist kein vollständiger Virenscan und wird nicht als solcher beworben.

Geplante Startwerte (adminseitig innerhalb sicherer Schranken konfigurierbar):

| Grenze | Startwert |
| --- | --- |
| komprimierte Datei | min(25 MiB, Discourse-Anhangslimit); dazu begrenzter Multipart-Overhead |
| entpacktes Gesamtbudget / Einzeleintrag | 250 MiB / 64 MiB, tatsächliche Streaming-Bytes zählen |
| Archiveinträge / Entpackzeit | 10.000 / 5 Sekunden |
| neue Mutationen | 5/Minute/Nutzer und 30/Minute/Instanz; auch Status-/Replayanfragen begrenzen |
| gleichzeitige neue Mutationen | 2/Nutzer und 8/Instanz, instanzübergreifend wirksam |
| Nextcloud-Verbindung / Gesamtdauer | 5 Sekunden Aufbau, 30 Sekunden pro Remote-Aufruf, 90 Sekunden pro Operation |
| Antwortkörper | 1 MiB pro Remote-Antwort |

Keine Persistierung von Datei-/Passwortpayloads für spätere Jobs. Temporärdateien
in `ensure` freigeben. Proxy-/Rack-Bodylimits müssen ebenfalls gesetzt werden:
Controller-Prüfungen allein verhindern keine vorab gepufferte Großdatei.

### 6. Überschreibschutz und Idempotenz

Je Operation ein zufälliger serverseitiger Ziel-Unterordner oder eindeutiger
Dateiname mit erhaltenem bereinigtem Anzeigenamen; keine Account-/Topic-ACL-
Struktur daraus ableiten. Zielpfad einmal im Vorgang festhalten.
WebDAV `PUT` mit `If-None-Match: *`, bei Kollision kein `204` als Neuerstellung
akzeptieren. Auch Verzeichnisanlage und Antwortverlust abgleichen; bloßes HEAD
vor PUT ist nicht race-sicher. Keine bestehenden Dateien für Rollbacks anfassen.

Kleine ActiveRecord-Vorgangstabelle mit Unique-Index auf Nutzer/Operation-Key:
Zustand, Payload-Fingerprint, erzeugter Zielpfad, Dateinachweis/ETag, Share-ID,
geschütztes Ergebnis, Zeitpunkte, sichere Fehlerklasse. Keine Dateiinhalte oder
Klartext-Passwörter. Passwortbestandteil des Fingerprints als serverseitiges HMAC
statt offline erratbarem Klartext-Hash. Status ausschließlich für Eigentümer.

Parallele gleiche Anfragen durch Unique-Index plus Core-geeigneten Lock
serialisieren, keine DB-Transaktion während langer Netzaufrufe halten. Vor einer
erneuten Mutation `unknown`-Zustände gegen Nextcloud abgleichen.
Wiederholungsfenster: sieben Tage; Client versucht danach nicht automatisch
denselben Vorgang erneut. Erfolgreiche Journaldaten danach datensparsam entfernen;
unklare/Bereinigungsfälle bleiben bis zur Auflösung sichtbar. Ein Journal-Purge
darf nie erfolgreich erstellte Dokumente löschen.

### 7. Shares, Teilfehler und Geheimnisschutz

`shareType=3`, `permissions=3`; Passwort nur im Vorlagenablauf wie bisher.
Kein Downgrade ohne Passwort, falls Nextcloud eine Policy verletzt sieht.
HTTP-Status **und** OCS-Metadaten samt Share-ID, URL, Typ/Rechten und gefordertem
Passwortschutz prüfen. JSON explizit anfordern, kein XML-Fallback.
Antwort-URL nur von der konfigurierten Nextcloud-
Origin akzeptieren; Zugangsdaten nie über Redirects weitergeben.

Fester adminseitiger HTTPS-Endpunkt, TLS-Verifikation aktiv, keine User-URL und
keine Redirect-Folge. Core-Netzwerkschutz verwenden; private Nextcloud-Ziele
nur über explizite operatorseitige Freigabe, nie globale SSRF-Sperren abschalten.

Zustände: `pending`, `file_created`, `completed`, `failed`, `unknown`.
Nach Share-Timeout zunächst Shares am exklusiven Pfad abfragen;
gefundenen passenden Share übernehmen, keine zweite Mutation auf Verdacht.
Bei fehlendem Passwort im Wiederanlauf keine Share-Erstellung im Hintergrund;
derselbe Request muss erneut sicher eingereicht werden. Definitiv abgelehnte
oder unvollständige Vorgänge bleiben für gezielte Betreiberbereinigung sichtbar.

Abgleich erfolgt begrenzt bei erneuter Anfrage oder Statusabfrage. Keine
periodischen Remote-Jobs oder automatischen entfernten Löschungen. Dateien und
Shares werden weder durch TTL noch durch Deaktivierung/Rücknahme gelöscht.
Die URL ist zugriffsgewährendes Ergebnis: ausschließlich serverseitig geschützt
speichern und nur an den authentifizierten Eigentümer zurückgeben; DB-/Backup-
Administratoren bleiben Teil der bestehenden Vertrauensgrenze.

Rails-Parameterfilter, Proxy-/Accesslog-Konfiguration, HTTP-/Job-/Browser-Logging
und Errortracking gemeinsam prüfen. Nur Operation-ID, sichere Fehlerklasse und
Dauer loggen; keine Rohpayloads, Namen/Inhalte, Passwörter oder Share-URLs.

### 8. Modernes Frontend und echte Tests

Plugin-i18n unter `config/locales/client.*`, keine Theme-Präfixe im Plugin.
Glimmer-Dialog über Modal-Service, native Buttons/Inputs und Tokens. Namen aus
Composer-/Topic-Modell statt DOM-Selektoren gewinnen; Kalenderdatum dokumentieren.

Upload-Resolver liefert ein Promise auf Nextcloud-Markdown, bei Fehlern auf
nativen Upload-Markdown. Der Core setzt den Platzhalter in beiden Editoren.
Kein nachträgliches globales RegEx-Replace oder blindes Append. Vor dem ersten
`await` Modell-/Entwurfsidentität erfassen, Lebenszyklus/Editorwechsel/Entfernung
des Platzhalters beachten. Wird der Entwurf verlassen, kein fremdes Modell
ändern; vorhandenes Serverergebnis bleibt per Operation-Key kontrolliert abrufbar.
Zusammenspiel mit weiteren Resolvern und nativen Upload-Abbrüchen durch echte
Integrationstests belegen; bei Core-Lücke stoppen statt heimlich alten Fallback nutzen.

Backend-Request-/Service-/Modelltests mit HTTP-Stubs, QUnit-/Ember-Frontendtests,
Systemtests im echten Discourse-Kontext, offizieller Plugin-CI-Workflow.
Gemeinsamer `make check` führt reale Checks aus oder bricht bei fehlendem
Test-Checkout/Tools ab; Shellwrapper nur wenn erforderlich, keine grüne Attrappe.

Browserprüfung: Markdown/Rich Text, Fokus/Tastatur, deutsch/englisch,
1440×1000, 1024×900, 768×1024, 320×800. Geometrie auf Überlauf/Abschneiden/
unbeabsichtigte Überschneidung messen, Funde schlagen fehl. Nachweise in
git-ignoriertem Artefaktordner. Core-Feature-Smoke aus dem Skeleton erhalten.

## Risks / Trade-offs

- [Plugin-Betrieb ist schwerer] → zuerst isoliertes Core-Checkout/Testumgebung
  und CI einrichten; keine Behauptung alter Mindestversion-Kompatibilität.
- [Öffentliche Links bleiben weitergebbar] → ausdrücklich unverändertes Modell;
  vertrauliche Daten/Rechtewiderruf bleiben außerhalb dieser Phase.
- [Sicherheitskorrekturen lehnen früher tolerierte Dateien ab] → Fixtures und
  verständliche Fehlermeldungen, keine ungeprüfte Format-/Makro-Freigabe.
- [Idempotenz braucht lokale Zustandsdaten] → kleines Journal, klare Aufbewahrung,
  keine Datei-/Passwortspeicherung, Migration/Backup und Unique-Index testen.
- [Nextcloud-Crash-/Netzwerkfenster] → beobachtbarer unklarer Zustand statt
  vermeintlicher verteilter Transaktion; Wiederanlauf und Cleanup gezielt testen.
- [Alte Loglecks bleiben historisch] → Betreiber auf Log-Audit und mögliche
  Passwort-/Linkrotation hinweisen; keine automatische Rotation bestehender Links.

## Migration Plan

1. Vor Produktänderung Nutzermaterial/aktuellen Diff erhalten; Legacy-Revision
   dokumentieren. Keine Commits/Tags/Branches/Pushes ohne eigene Zustimmung.
   Für bestehende Theme-Bezieher einen bewusst gewählten Legacy-Ref bzw.
   Update-Stopp vereinbaren, bevor Plugin-Revisionen ihre Theme-Quelle erreichen.
2. Plugin zunächst deaktiviert im Testsystem aufbauen. Makrofreie synthetische
   Vorlagen mit Herkunft/Hashes bereitstellen; leere Dateien öffnen/testen.
3. Vertragstests und alle Sicherheitsregressionen müssen vor produktivem Cutover
   grün sein. Danach synthetischer End-to-End-Test gegen ausdrücklich freigegebene
   Nextcloud-/Collabora-Testinstanz, inklusive lokalem bzw. tatsächlichem Storage.
4. Bestehenden Altcode erst nach verifiziertem Ersatz aus dem aktiven Plugin-
   Bestand entfernen; weder Nutzerdateien noch `guidelines/` löschen.
5. Operatorrunbook: Plugin installieren/rebuilden, serverseitige Settings und
   Least-Privilege-Servicekonto setzen, Body-/Netzlimits prüfen; deaktiviert lassen.
6. Alte Theme Component deaktivieren, laufende Vorgänge beenden/abgleichen,
   PHP-Endpoint serverseitig sperren; keine Übergangsphase mit zwei Schreibern.
   Dann Plugin aktivieren und Smoke-Test durchführen. Alten Browser-Key entfernen,
   offen zugängliche Altlogs prüfen. Produktionsschritte brauchen eigene Freigabe.
7. Bestehende Nextcloud-Dateien, Share-URLs und Postings nicht umschreiben.
   Ausrollfreigabe erst mit dokumentierter tatsächlicher Versionenkombination.
8. Rückweg: Plugin zunächst deaktivieren, neue Vorgänge stoppen und unklare
   Zustände abgleichen; Journal/Dateien erhalten. Schema-Rollback darf keine
   Dokumentlöschung auslösen. Alten unsicheren PHP-Weg nicht automatisch öffnen;
   Wiederherstellung eines Legacy-Schreibwegs erfordert separate Absicherung/Freigabe.

## Open Questions

Für den isolierten Entwicklungsstand wird der recherchierte Core-Commit genutzt.
Tatsächliche Discourse-/Nextcloud-/Collabora-Versionen, Storage, Netzwerk und
Testinstanzzugang sind Rollout-Gates, keine Erlaubnis für Produktionszugriff.
Bei Nicht-Kompatibilität ist der betroffene Umsetzungsteil vor Fortsetzung neu
abzustimmen; es gibt keine pauschale Unterstützung älterer Versionen.
