# Proposal

## Why

Die bisherige Theme/PHP-Lösung benötigt eine sichere serverseitige Grenze und
aktuelle Discourse-Integration, ohne neue Office-Funktionen oder Phase-2-Rechte
einzuführen. Der Nutzer beauftragt die Planung und hat ein vollständiges Plugin
statt Plugin plus separater Theme Component ausdrücklich gewählt.

## What Changes

- Ein Ruby-Plugin mit eigenem modernem Composer-Frontend ersetzt Theme und PHP.
  Grundlage ist das aktuelle offizielle **Plugin-Skeleton**, dessen Frontend-
  Tooling mit dem Theme-Skeleton übereinstimmt; keine zweite Theme-Laufzeit.
- Funktionserhalt: Word/Excel/PowerPoint aus Vorlagen, Dateinamen-Vorschlag aus
  Topic-Titel/Datum, optionales Share-Passwort; einmalige Übertragung nativer
  Discourse-Uploads für docx/xlsx/pptx/odt/ods/odp und bearbeitbare Nextcloud-Links.
- Sicherheit: Discourse-Sitzung/CSRF, serverseitige Secrets, begrenzte Ressourcen,
  sichere Dateistrukturprüfung, kollisionssichere Erstellung, idempotente
  Wiederholungen, bereinigte Logs/Fehler und kontrollierte Teilfehler.
- Moderne Glimmer-UI, native Dialoge, Plugin-i18n, öffentliche Composer-APIs und
  native Upload-Platzhalter statt nachträglichem RegEx-/Append-Fallback.
- Ausführbares Plugin-Tooling, Tests und CI gehören zu diesem Migrations-Change;
  sie ersetzen den ursprünglich separat angedachten Theme-Tooling-Change.
- **BREAKING:** Installation als Backend-Plugin statt Theme-Installation;
  neue gleich-originige Plugin-Endpoints/Settings, keine PHP-API-Kompatibilität.
  Alte Theme-Settings/API-Keys entfallen beim expliziten Cutover.
- **BREAKING / Sicherheitskorrektur:** keine Namensüberschreibung, keine beliebigen
  Download-URLs, kein Template-Ersatz bei Uploadfehlern, keine generische ZIP-
  Freigabe. Ungültige/verschlüsselte oder als Makroformat getarnte Dateien werden abgelehnt.

Nicht-Ziele: Topic-/Gruppen-ACL für Dokumente, SSO, Keycloak, Rechtewiderruf für
Shares, eingebetteter Collabora-Client, Versions-/Bidirektionalsynchronisation,
Migration bestehender Dateien/Posts, neue Formate oder neue Passwortdialoge für
Hybrid-Uploads. Öffentliche Bearbeitungslinks bleiben bewusst öffentlich;
Mitgliedschaftsentzug entzieht weiterhin keinen Linkzugriff.

## Capabilities

### New Capabilities

- `office-composer`: Vorlagen-/Uploadabläufe in beiden Editoren mit sicherer
  Entwurfsbindung und verständlichem Fehlerverhalten.
- `office-request-security`: Authentifizierung, Secrets, Dateivalidierung,
  Ressourcen- und Netzwerkgrenzen.
- `office-storage-operations`: sichere Dateierstellung, Shares, Wiederholungen
  und Wiederherstellung bei Teilfehlern.
- `office-plugin-lifecycle`: ausschaltbare Installation, Konfiguration,
  nachgewiesene Kompatibilität und verlustarmer Cutover/Rollback.

### Modified Capabilities

Keine bestehenden Haupt-Specs. Der abgeschlossene, noch nicht archivierte
Harness-Change betrifft `development-workflow` und wird nicht verändert/dupliziert.

## Impact

Geplant ist ein Plugin in dieser Repository-Wurzel; bisherige Theme-Struktur
und PHP werden nach verifiziertem Ersatz aus dem aktiven Produkt entfernt,
nicht schon während der Planung. Git-Historie und ein dokumentierter Legacy-
Referenzstand erhalten den Rückblick. Bestehende Theme-Installationen dürfen
nicht unkontrolliert auf eine Plugin-Revision aktualisieren.

Betroffen: Discourse-Serverinstallation, Frontend-Assets, serverseitige Settings,
eine kleine lokale Vorgangstabelle, Nextcloud-Servicekonto und Deploymentablauf.
Produktive Endpunkte, Logs, Secrets und Altdaten werden in dieser Planung nicht
angefasst. ADRs bleiben Vorschläge; Implementierung und Deployment brauchen
eigene Freigaben.

Planungsstand: 2026-10-28, Quellen in [research.md](research.md), technische
Umsetzung und Sicherheitsmatrix in [design.md](design.md), Einheiten in
[tasks.md](tasks.md). Es wurden noch keine Produkttests ausgeführt.
