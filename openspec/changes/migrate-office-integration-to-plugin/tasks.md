# Tasks

Status: **Implementierung vom Nutzer freigegeben** am 2026-10-28, zunächst lokal
mit erfolgreichen Tests; erst danach neuer Branch auf GitHub. Checkboxen bleiben
offen, bis die jeweilige Einheit umgesetzt und geprüft wurde. Definition of Done
ist in den [vier Specs](proposal.md#capabilities) festgelegt, Details in [design.md](design.md).

## 1. Reproduzierbare Plugin-Basis

- [x] 1.1 Plugin-Skeleton/Core-/CI-Stände aus research.md erneut vergleichen, exakte lokale Core-Testbaseline festhalten und dokumentieren; Versions-/API-Abweichungen und TypeScript-Vorabversion ausdrücklich reviewen, vor inkompatibler Umsetzung stoppen.
- [x] 1.2 Isolierte Discourse-Testumgebung für die festgelegte Baseline einrichten und Bedienung dokumentieren; Discourse bootet, Testdatenbank und Browser-Runner laufen ohne Produktionszugriff. Fehlende lokale Voraussetzungen als Blocker melden.
- [x] 1.3 Plugin-Engine, deaktivierte Aktivierung, Skeleton-Tooling und Plugin-CI additiv anlegen, Altcode noch erhalten; Boot-, Deaktivierungs- und native Core-Feature-Smoke-Tests sowie Lint/Typcheck müssen bestehen, Lockfiles werden reproduzierbar installiert.

## 2. Servergrenze und Dateisicherheit

- [x] 2.1 Server-/Client-Settings und beide POST-/Statusrouten mit Pluginzustand, Session, Kontostatus und CSRF implementieren; Requesttests für anonym, gesperrt, deaktiviert, falschen Origin/Alt-Key und CSRF ohne entfernte Seiteneffekte; Settings-/Auth-Vertrag dokumentieren.
- [x] 2.2 Sichere Parameter-/Dateinamenbehandlung und Antwortformate implementieren; Regressionstests für Arrays statt Strings, Unicode-Grenzen, Traversal, doppelte Endungen und Link-/HTML-Escaping; Fehlercodes und Normalisierung dokumentieren.
- [x] 2.3 Gültige synthetische DOCX/XLSX/PPTX-Vorlagen und sechs Uploadformat-Fixtures mit Herkunft/Hashes bereitstellen; Typ-/Strukturprüfungen akzeptieren diese, lehnen leere, generische ZIP-, getarnte Makro- und verschlüsselte Pakete ab; Fixture-Herkunft dokumentieren.
- [x] 2.4 Archivbudgets und sichere XML-/ZIP-Verarbeitung umsetzen; Tests für Traversal, Symlinks, doppelte Einträge, beschädigte Pakete, XML-Entitäten, Eintrags-/Byte-/Zeitbudget und Tempfile-Cleanup; Grenzen und fehlende Virenscan-Garantie dokumentieren.
- [x] 2.5 Datei-/Bodylimits, Discourse-Formatbeschränkungen sowie Nutzer-/Instanz-Frequenz und Parallelität erzwingen; Grenzwert-/Paralleltests mit 413/429, keine ausgehende Mutation bei Ablehnung; erforderliche Proxy-/Rack-Konfiguration im Runbook beschreiben.
- [x] 2.6 Nextcloud-Secrets, Share-Passwort und Nutzdaten aus Client-Settings, Parametern-/HTTP-/Job-/Browser-Logs und Fehlerdumps fernhalten; Canary-Tests mit künstlichen Secrets sowie Response-/Statuszugriffstests bestehen; verbleibende Admin-/Backup-Vertrauensgrenze dokumentieren.

## 3. Nextcloud-Adapter und Vorgangsmodell

- [x] KISS-Review 2026-10-29 umsetzen: relative API-Pfade, Gesamtdauergrenze, explizite private Netzfreigabe, besitzgebundene Slots, Erfolgs-Hashes; ZIP-Bibliotheksmöglichkeiten prüfen und Test-/Logaussagen korrigieren. Vom Nutzer freigegeben.

- [x] 3.1 Begrenzten Nextcloud-HTTP-Adapter für feste HTTPS-Origin implementieren; Tests für TLS-/Verbindungsfehler, Redirects, fremde Share-URL, Antwort-/Zeitlimits und abgewiesene downloadUrl-Parameter; explizite private Netzfreigabe dokumentieren, keine globale SSRF-Ausnahme.
- [x] 3.2 Kollisionssichere Pfade und bedingte WebDAV-Erstellung implementieren; Tests für gleiche Anzeigenamen, parallele PUTs, If-None-Match, 412/204 und unbekannten PUT-Ausgang zeigen keine Überschreibung; Zielpfadstrategie dokumentieren.
- [x] 3.3 OCS-Share-Erstellung/-Abfrage mit permissions=3 und optionalem Passwort implementieren; JSON explizit anfordern, HTTP-/OCS-Fehler-, Passwortpolicy- und URL-/Rechteprüfungen bestehen, kein ungeschützter Passwort-Fallback. Keine automatische Share-Löschung; API-Vertrag dokumentieren.
- [x] 3.4 Vorgangstabelle mit Unique-Index, sicherem Payload-Fingerprint, Zuständen und eigentümergebundenem Statuszugriff anlegen; Migrations-, Konflikt-, Parallelitäts- und No-store-/IDOR-Tests bestehen, keine Passwort-/Dateipayload persistiert; Schema/Aufbewahrung gemäß ADR 0003 dokumentieren.

## 4. Sichere Office-Operationen

- [x] 4.1 Vorlagen- und Multipart-Orchestrierung mit dauerhafter Operation-Key-Zuordnung implementieren; Tests für drei Vorlagen/sechs Uploadformate, fehlende Datei, ungültige Nutzlast, Mehrfachklicks und wiederholte/geänderte Requests bestehen; kein Uploadfehler-Template-Fallback.
- [x] 4.2 Wiederanlauf nach PUT-/Share-Timeout und Prozessabbruch implementieren; Fault-Injection-Tests zeigen Abgleich vor Mutation und höchstens ein Ergebnis pro Vorgang, Share-Passwort wird nicht in Jobs persistiert; Wiederholungsfenster und Nutzerwiederanlauf dokumentieren.
- [x] 4.3 Anfragegebundenen Abgleich und lokale Journal-Aufbewahrung implementieren; keine automatische entfernte Löschung oder periodischen Remote-Jobs. Tests für Recovery, TTL, ungelöste Fälle und gezielten Betreiber-Reparaturweg; fertige/fremde Dokumente erhalten.

## 5. Modernes Composer-Frontend

- [x] 5.1 Funktionale Plugin-API-Menüactions, Glimmer-Dialog und Frontend-Service mit Plugin-i18n en/de, Dateinamenvorschlag und optionalem Passwort implementieren; QUnit-/Komponententests für Submit/Cancel/Fehler/Fokus/Doppelklick bestehen; kein DOM-String-Dialog/globales I18n.
- [x] 5.2 Asynchronen nativen Upload-Resolver mit erlaubtem Byte-Download, Multipart-Aufruf und Erfolg-/Original-Markdown implementieren; Tests für sechs Formate, Formatsetting, fehlenden Download/Nextcloud-Fehler und weitere Resolver bestehen, kein RegEx-/Append-Ersatz; Browser-/Storage-Voraussetzungen dokumentieren.
- [x] 5.3 Entwurfs-/Uploadidentität, Abbruch, verspätete Antworten und sichere Wiederauffindbarkeit eigener Ergebnisse umsetzen; Integrationstests für Entwurfswechsel, gelöschte Platzhalter, Editorwechsel und gleichnamige parallele Uploads zeigen keine fremde Änderung/Doppel-Links.
- [x] 5.4 Systemtests für beide Editoren und alle zentralen Erfolgs-/Fehlerabläufe en/de sowie Tastatur/Fokus ergänzen; reale Geometrieprüfungen bei 1440×1000, 1024×900, 768×1024 und 320×800 bestehen, Nachweise nur git-ignoriert; UI-/A11y-Abnahme dokumentieren.

## 6. Vollständige Integration und Migrationsreife

- [x] 6.1 Gemeinsamen make-check-Einstieg und offiziellen Plugin-CI-Workflow vervollständigen; tatsächlich Lint, Typen, Backend-, QUnit-, System-/Geometriechecks und strikte OpenSpec-Validierung ausführen, Fehlervoraussetzungen sind nicht grün; Befehle in AGENTS.md/Entwicklungsdocs aktualisieren.
- [x] 6.2 Funktions-/Sicherheitsmatrix gegen alle vier Specs reviewen und auf der isolierten Baseline ausführen; Ergebnisse für 3 Vorlagen, 6 Uploadformate, Passwort, Kollisionen, Grenzen, Logs, Retry/Cleanup und beide Editoren mit realen Check-Ausgaben dokumentieren.
- [ ] 6.3 Ersatz verifizieren und alten aktiven Theme-/PHP-/Legacy-Modal-Code gezielt entfernen, keine Nutzerdateien; Plugin ohne Theme/PHP bootet und alle Tests bleiben grün, Legacy-Referenz/Update-Stopp dokumentiert; Diff und unveränderte Guidelines reviewen.
- [ ] 6.4 Installations-/Konfigurations-, Cutover-, Incident- und Rollback-Runbook erstellen und im Testbetrieb durchspielen; genau ein Schreiber, PHP gesperrt, alte Post-/Share-Links unverändert, Plugin-Deaktivierung löscht nichts und öffnet keinen unsicheren Altweg; Kompatibilitätsmetadaten nur nach Tests setzen.

## Workflow follow-up

- Implementierung erst nach Planfreigabe starten; ADRs nicht automatisch als accepted markieren.
- Produktiven Rollout separat freigeben. Vorher tatsächliche Discourse-/Nextcloud-/Collabora-Versionen, Storage/Netzgrenzen und eine ausdrücklich genehmigte synthetische E2E-Testinstanz nachweisen. Fehlende Nachweise blockieren den Rollout.
- Keine ungefragten Commits, Tags, Legacy-Branches, Pushes, Secret-/Linkrotationen oder Deployments.
- Archivierung braucht eigene Freigabe. Phase 2 bleibt ein gesonderter zukünftiger Change.

## Stand der Umsetzung

Aktuell (2026-10-29): Entwicklungs-MVP für Erstellen und Übertragen steht –
Composer-Menü/Dialog, nativer Upload-Handler, WebDAV-/OCS-Adapter, Journal mit
Wiederanlauf und eigentümergebundenem Status. 218 Plugin-Specs (192 ohne Systemtests) inklusive
Chromium-Systemtests grün, 7 QUnit-Tests grün, `pnpm lint` und Rubocop grün,
Change strikt validiert. `OfficeResult` entfernt; Erfolgs-Hash und vollständige
Share-URL-Prüfung liegen im OCS-Adapter. Keine automatischen Remote-Jobs und
keine automatischen Löschungen. ZIP-Leser nach Prüfung von Rubyzip 3.7.0 beibehalten (EntrySet
dedupliziert); kein neuer ZIP-Stack.

Die folgenden Einträge sind historische Zwischenstände, keine zusätzlichen
Sicherheitsgarantien. Insbesondere beweisen Canary-Tests nur erfasste Rails-
Meldungen, nicht sämtliche Logster-/Proxy-/Browser-Dumps. ADR 0003 bleibt
`proposed`. 5.4, 6.1 und 6.2 sind abgeschlossen. Offen sind 6.3 (Legacy-
Entfernung, braucht Freigabe) und 6.4 (Runbook liegt vor, Durchspielen auf einer
echten Testinstanz fehlt), außerdem die GitHub-CI, die noch nie lief.

Aufgabe 1.2 abgeschlossen: Datenbankaufbau, 6 Backend-Requesttests, Core-Build
und 1 Chromium-Systemtest bestanden. Native Prozesse nur auf Loopback, keine
dauerhaften Dienste. Nachweise und Befehle in docs/development/local-tests.md.

Aufgabe 1.3 abgeschlossen: Plugin-Gerüst (Engine, Routes, Setting, Locales,
Skeleton-Tooling, Lockfiles, Plugin-CI) additiv angelegt; Altcode unverändert.
Geprüft: `pnpm install --frozen-lockfile`, `pnpm lint` (ESLint/Stylelint/
Prettier/Typen), Rubocop ohne Verstoß, Plugin-Boot/-Deaktivierung 3/3,
native Core-Features mit aktivem Plugin 19/19 (Chromium). Der CI-Workflow wurde
lokal nicht ausgeführt. GitHub-Veröffentlichung weiterhin erst nach
erfolgreichen Plugin-Tests; als Nächstes Abschnitt 2 (Servergrenze).

Aufgabe 2.1 abgeschlossen: Settings (`config/settings.yml`, en/de-Locales),
validierte `Configuration`, Guard-Kette und die drei Design-Routen implementiert.
Noch ohne Dateiverarbeitung: `POST /documents` und `/transfers` enden nach allen
Guards mit `501 not_implemented`, `GET /operations/:key` mit `404`. Geprüft:
23 fokussierte Config-/Request-Specs grün, vollständige Plugin-Suite 45/45
inklusive Chromium-Systemtest, Rubocop 11 Dateien ohne Verstoß, `pnpm lint`
grün. Vertrag in `docs/development/server-contract.md` dokumentiert. CSRF-Test
nutzt echtes `allow_forgery_protection`; API-Keys werden vor jeder Action als
`session_required` abgelehnt. Als Nächstes 2.2 (Parameter-/Dateinamen und
Antwortformate).

Aufgabe 2.2 abgeschlossen: strikte Payload-Klassen (`DocumentPayload`,
`TransferPayload`) akzeptieren nur skalare Strings, prüfen Formatlisten,
Operation-Key und Share-Passwort. `FileName` normalisiert NFC/UTF-8, entfernt
Pfad-/Steuer-/Bidi-Zeichen, begrenzt auf 200 Bytes und setzt genau eine passende
Endung; `OfficeResult` liefert das dokumentierte Erfolgsformat und weist
Nicht-HTTPS-/Credential-URLs zurück. Geprüft: 48 fokussierte Specs grün
(Unicode, Traversal, doppelte/fremde Endungen, Arrays, HTML-Escaping),
Rubocop 19 Dateien ohne Verstoß. Vertrag und Fehlercodetabelle in
`docs/development/server-contract.md` erweitert. Als Nächstes 2.3 (synthetische
Office-Fixtures und Paketstrukturprüfung).

Aufgabe 2.3 abgeschlossen: neun synthetische Fixtures (drei Vorlagen, sechs
Uploadformate) mit festem ZIP-Zeitstempel, Generator und SHA-256-Liste in
`spec/fixtures/office/`; `PackageValidator` prüft OOXML/ODF-Struktur, Hauptteile,
MIME/Manifest, Makro-/Verschlüsselungsmarker, Traversal, Duplikate, DTD/Entities
und XML-Gültigkeit, ohne zu extrahieren. Transfer-Endpoint validiert die Bytes
vor der weiteren Verarbeitung. Geprüft: 80 Plugin-Specs grün inklusive
Chromium-Systemtest, Rubocop 22 Dateien ohne Verstoß; echte Office-/LibreOffice-
Öffnung lokal nicht möglich und als Grenze dokumentiert.

Aufgabe 2.4 abgeschlossen: `PackageValidator` liest die Eintragsliste aus dem
rohen zentralen Verzeichnis (Duplikate, Symlink-Modi, inkonsistente EOCD-Zähler),
zählt entpackte Bytes beim Streamen (64 MiB je Eintrag, 250 MiB gesamt), prüft
Eintragszahl (10.000), zentrale Verzeichnisgröße (8 MiB) und Zeitbudget (5 s),
parst XML strikt ohne DTD/Entities und schließt Archive/Deskriptoren in `ensure`.
Geprüft: 18 Validator-Specs inklusive Traversal, Symlink, Duplikat, beschädigtem
ZIP, XML-Entities, Budgets, Handle-Leak; gesamte Plugin-Suite 89/89 grün,
Rubocop 22 Dateien ohne Verstoß, `pnpm lint` grün. Grenzen und fehlende
Virenscan-Garantie in `docs/development/server-contract.md` dokumentiert.

Aufgabe 2.5 abgeschlossen: `Limits` erzwingt Body-Caps (16 KiB JSON, Dateilimit
plus 64 KiB Multipart-Overhead), das wirksame Dateilimit
`min(nextcloud_office_max_file_size_mb, max_attachment_size_kb)` sowie die
Discourse-Upload-Policy (`authorized_extensions`, Staff-Liste, `*`). `RateLimits`
setzt 5 Mutationen/Minute/Nutzer und 30/Instanz (Status 30/120, auch für Staff)
über den Core-`RateLimiter` und 2/8 parallele Mutationen über atomare
Redis-Slots mit 2-Minuten-TTL durch; Ablehnungen erfolgen vor Dateiverarbeitung
und Nextcloud. Geprüft: 118 Plugin-Specs grün (413-Body/-Datei,
Formatpolicy-415, 429 per Nutzerbudget und belegte Slots, Slot-Freigabe,
getrenntes Statusbudget, Staff-Limit, Instanzbudget), Rubocop 26 Dateien ohne
Verstoß, `pnpm lint` grün. Grenzen sowie nginx-/Rack-Vorgaben in
`docs/development/server-contract.md`; das Betriebs-Runbook (6.4) übernimmt und
verifiziert diese Proxy-Werte.

Aufgabe 2.6 abgeschlossen: Nur `nextcloud_office_enabled` ist client-sichtbar;
`plugin.rb` filtert `share_password` und `nextcloud_office_app_password`
zusätzlich in `filter_parameters`. Canary-Specs prüfen Client-Settings-JSON,
HTML-Preload, Erfolgs-/Fehler-/Statusantworten (exakte Feldliste), gefilterte
Parameter (auch verschachtelt/als Array) sowie Rails-/Logster-Meldungen mit
künstlichen Secrets; `Configuration`-Summary und `RequestError`-Meldung bleiben
geheimnisfrei. Geprüft: 132 Plugin-Specs grün, Rubocop 28 Dateien ohne Verstoß.
Client-, Antwort-, Log- und Job-Regeln sowie die verbleibende Admin-/DB-/
Backup-Vertrauensgrenze sind in `docs/development/server-contract.md`
dokumentiert.

Aufgabe 3.1 abgeschlossen: `NextcloudClient` und `NextcloudError` als einziger
Ausgangspunkt nach draußen – gleicher Origin aus den Admin-Settings, TLS ≥ 1.2
mit `VERIFY_PEER`, keine Redirects, Basic-Auth nur dorthin, 5 s/30 s Timeouts,
1 MiB Antwortlimit, Abweisung von `downloadUrl`/`url`/`redirect`/`target`/
`callback` und absoluten Fremd-URLs. Geprüft: 14 Client-Specs (gleicher/ fremder
Origin, Redirect ohne Folge-Request, Query-Kodierung, downloadUrl-Varianten,
TLS-, Timeout-, Verbindungsfehler, Größenlimit, `inspect` ohne Passwort),
gesamte Plugin-Suite grün, Rubocop ohne Verstoß. Private-Netz-Freigabe ohne
globale SSRF-Ausnahme ist in `docs/development/server-contract.md` dokumentiert.

Aufgabe 3.2 abgeschlossen: `Webdav` leitet den Zielpfad aus konfiguriertem Ordner
plus `SecureRandom.uuid`-Präfix und normalisiertem Anzeigenamen ab; PUT nutzt
`If-None-Match: *`, nur 201 gilt als Neuerstellung, 412 als Konflikt, 204/Timeout
als unklarer Ausgang ohne Retry. Geprüft: 9 WebDAV-Specs (gleiche Namen,
paralleler PUT, Konflikt, 204/500, Timeout, Unicode-/Reserved-Kodierung,
Traversal, HEAD) sowie Request-Tests für gleichnamige Uploads.

Aufgabe 3.3 abgeschlossen: `Shares` erstellt/liest OCS-Shares als JSON
(`format=json`, `OCS-APIRequest: true`), Share-Typ 3 und exakt permissions=3,
optionales Passwort ohne Downgrade. HTTP-/OCS-Metadaten, Pfad, Eigentümer,
Dateityp, Passwortmarker und HTTPS-Share-URL am konfigurierten Origin werden
validiert; XML-Fallback und automatische Löschung fehlen bewusst. Geprüft:
11 Share-Specs (Erfolg, Passwort, Policy-Fehler, falsche Felder, unsichere URLs,
`index.php`, Fehlerformate, Wiederauffindung, Log-Hygiene).

Aufgabe 3.4 abgeschlossen: `nextcloud_office_operations` mit Unique-Indizes je
Nutzer/Key und Zielpfad, HMAC-Fingerprint ohne Klartextpasswort, Zuständen
`pending`/`file_created`/`completed`/`failed`/`unknown`, verschlüsseltem
Ergebnislink und eigentümergebundenem Status. Geprüft: Modell-Specs (Replay,
Konflikt, DB-Unique, Fingerprintbindung, Verschlüsselung, Purge) und
Request-Specs (No-store, IDOR, Status). Keine Dateipayload im Journal.

Aufgaben 4.1–4.3 abgeschlossen: `OperationRunner` verbindet Vorlage/Upload,
Journal, WebDAV und OCS unter 90-s-Budget und Core-`DistributedMutex`; vor PUT
wird `unknown` persistiert, Wiederanlauf prüft den Streaming-SHA256 der
vorhandenen Datei und erzeugt nur bei Abwesenheit neu, Shares werden vor
Erstellung am exklusiven Pfad gesucht. Fault-Injection-Tests decken verlorene
PUT-/Share-Antworten, fremd geänderte Dateien, unklare Vorgänge und
`purge_completed!` ab; keine automatische Remote-Löschung. Geprüft: Modell-
und Request-Specs für diesen Bereich, gesamte Suite damals 189/189.

Aufgaben 5.1–5.3 abgeschlossen: Glimmer-Dialog mit FormKit, Plugin-i18n en/de,
Fokus, Submit-/Doppelklick-Schutz, optionalem Passwort, Entwurfswechsel-Schutz
und letztem Ergebnis; nativer `addComposerUploadHandler` sendet die Bytes aus
dem Composer als Multipart (kein Server-Download) und fügt den Link über
`composer:insert-text` ein. QUnit: 7 Tests für Erfolg, Abbruch, Fehler/Retry mit
stabilem Key, Doppelklick, Fokus, Entwurfswechsel und sechs Formate. Systemtest:
Erstellen und ODS-Upload in beiden Editoren, Geometrie
1440×1000/1024×900/768×1024/320×800.

Aufgabe 5.4 abgeschlossen: zusätzlich Systemtests für den deutschen Dialog
(Titel, Labels, Hinweis), Tastaturbedienung (Fokus im Namensfeld, Tab zum
Passwort, Escape schließt ohne Mutation, Enter sendet), den deutschen
Fehlerfluss mit erhaltenen Eingaben und den Wiederanlauf nach unbestätigtem
Share-Ergebnis (genau eine Datei, ein Share). Fehlertexte im Dialog und im
Upload-Hinweis werden jetzt aus dem Fehlercode in der UI-Sprache übersetzt
(`lib/office-errors.js`), mit Servertext als Fallback, damit sie nicht von der
Server-Locale abhängen. `file_name` in der Erfolgsantwort ist der bereinigte
Anzeigename ohne UUID-Präfix; der Speicherpfad bleibt im Journal.

Aufgabe 6.1 abgeschlossen: `script/check` ist der gemeinsame Einstieg (Lint/
Typen, Rubocop, OpenSpec strikt, Whitespace, Plugin-Assets, Plugin-Specs,
Chromium-Systemtests, QUnit); jeder Schritt meldet sich bei Fehlschlag namentlich
und beendet mit Exit 1, `--fast` überspringt DB/Browser. Befehle in `AGENTS.md`,
`docs/development/verification.md` und `local-tests.md` aktualisiert. Ausgeführt
am 2026-10-29: kompletter Lauf Exit 0, 192 Plugin-Specs ohne Systemtests,
26 Systemtests, 7 QUnit-Tests, `pnpm lint`, Rubocop (40 Dateien), OpenSpec 2/2.
Der GitHub-CI-Workflow bleibt unausgeführt (kein Push).

Aufgabe 6.2 abgeschlossen: `docs/development/acceptance-matrix.md` ordnet jedes
Szenario der vier Specs einem Nachweis zu. Alle automatisierten Zeilen sind
grün (Stub gegen WebDAV/OCS). Nicht abgedeckt bleiben echter
Nextcloud-/Collabora-Roundtrip, Reverse Proxy, Logster-Persistenz, eine
hilfsmittelgestützte WCAG-Prüfung und der CI-Lauf auf GitHub.

Aufgabe 6.4 begonnen: `docs/development/operations.md` beschreibt
Installation (inkl. Cloudron-Weg), Abnahmeliste mit 16 Prüfungen, Incident-
Vorgehen, Rollback und Cutover. Das Durchspielen auf einer echten Testinstanz
steht aus und ist der nächste Schritt.
