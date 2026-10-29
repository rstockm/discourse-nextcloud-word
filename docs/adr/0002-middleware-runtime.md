# 0002: PHP-Ablösung und mögliche Discourse-Plugin-Richtung

- Status: proposed
- Datum: 2026-10-28
- Entscheidungsträger: noch nicht bestätigt
- Freigabegrenze: Optionen dokumentieren, keine Migration implementieren

## Kontext und Problem

PHP vermittelt derzeit Datei-Erstellung/-Übertragung und Share-Erstellung über
Nextcloud WebDAV/OCS. Ein Sprachwechsel ist technisch möglich. Der öffentliche
Browser-Key ist jedoch kein vertrauenswürdiger Nutzerbeleg, und öffentliche
Bearbeitungslinks bleiben unabhängig von Discourse-Mitgliedschaften nutzbar.

Bestätigte Nutzerfestlegungen: Backend-Plugins sind installierbar; ein Plugin
wird als potenziell robuster bei aufwendigerem Testen gesehen. Eine Ableitung
von Discourse-Dateirechten ist ausdrücklich **Phase 2**. Ob zusätzlich Node-/
Python-Dienste/Container betrieben werden können, bleibt offen.

## Betrachtete Optionen

| Option | Vorteile | Nachteile |
| --- | --- | --- |
| PHP behalten und absichern | Kleinster Umstieg, vorhandener LAMP-Betrieb | Zusätzlicher Dienst/Sprachstack bleibt; Sicherheits- und Fehlerbehandlung muss verbessert werden |
| TypeScript/Node-Dienst | Gemeinsames Sprachökosystem, testbarer typisierter HTTP-Vertrag | Separater Betrieb und eigene vertrauenswürdige Authentifizierungsstrategie nötig; Hosting noch ungeklärt |
| Python-Dienst | Anschluss an Python/uv-Guidelines, gute Testwerkzeuge | Zweite Sprache bleibt; Django für kleinen Endpoint potenziell zu schwer, schlankeres Framework wäre begründete Abweichung |
| Discourse-Ruby-Plugin | PHP und separater Dienst können entfallen; serverseitige Secrets und Discourse-Sitzung nutzbar | Serverinstallation/-Updates statt reiner Theme-Installation; Discourse-Testumgebung erforderlich, enger an Core gekoppelt |
| Nur Theme/Browser | Kein eigener Serverprozess | Für dieses Modell ungeeignet: Nextcloud-Service-Secrets dürften nicht in den Browser gelangen |

## Entscheidung und Begründung

Vorschlag: als nächsten Architektur-Change ein **Discourse-Ruby-Plugin** vorrangig
auf Machbarkeit prüfen, statt zunächst einen neuen externen Dienst zu bauen.
Backend-Plugins sind möglich; damit lässt sich nicht nur die Sprache, sondern
auch die unnötige externe Vertrauensgrenze reduzieren. Eine vollständige
Plugin-Umsetzung oder Repository-Aufteilung ist damit noch nicht beschlossen.

Die Alternative bleibt, PHP gezielt abzusichern, wenn Plugin-Betrieb/Testaufwand
den Nutzen nicht rechtfertigt. Ein externer TypeScript-Dienst wird erst mit
bestätigtem Hosting und geklärter Authentifizierung konkret bewertet.

### Phasengrenze

- **Mögliche Phase 1, separat zu planen:** vorhandene Erstellungs-/Uploadfunktion
  serverseitig im Plugin abbilden, Nextcloud-Secrets aus dem Browser fernhalten,
  Basisprüfung angemeldeter Ersteller und CSRF-/Ressourcenschutz ausdrücklich
  spezifizieren. Öffentliche Nextcloud-Shares können zunächst bestehen bleiben.
  Diese grundlegende Endpoint-Absicherung ist nicht gleichbedeutend mit einer
  Ableitung aller Topic-/Gruppenrechte.
- **Phase 2:** Anforderungen an Discourse-Dateirechte, Rechteänderungen/Widerruf,
  bestehende Shares und Nextcloud-/Collabora-Zugriff neu spezifizieren.
  Ein Ruby-Endpoint allein macht einen öffentlichen Share nicht privat; das
  Zugriffsmodell muss dafür gegebenenfalls grundlegend geändert werden.

## Konsequenzen

- Positiv: PHP kann entfallen; keine zusätzliche Node-/Python-Runtime nötig;
  Discourse-nahe Backend-Tests und Geheimnisspeicherung werden möglich.
- Negativ: kein reines Theme-Deployment mehr, höhere lokale Einrichtungskosten,
  Core-/Plugin-Kompatibilität und Wartung werden verbindlich.
- Bestehende Fehler (Kollisionen, Logging, Dateiprüfung, Upload-Fallback) werden
  nicht durch Übersetzung in Ruby gelöst. Der Folge-Change muss sie explizit behandeln.
- Weder Plugin noch Harness rechtfertigen aktuell eine ACL- oder Sicherheitszusage.

## Überprüfung

Vor einer Implementierungsfreigabe: aktuelle offizielle Plugin-Vorlage und APIs,
Ziel-Core und Testinstanz prüfen; Erstellungs-/Upload-/Fehlerverträge mit gemocktem
WebDAV/OCS belegen. Beide Composer-Modi, sichere Logs, Limits, Kollisionen,
Wiederholungen und Abbrüche testen. Vor Cutover bestehende Dateien/Share-URLs,
Rollout und Rückweg sichern; alte/neue Schreiber nicht unkontrolliert parallel betreiben.

## Verknüpfungen

- Konkretisierung am 2026-10-28: Der Nutzer beauftragt den Phase-1-Plan und wählt
  ein vollständiges Plugin inklusive Oberfläche statt Plugin plus Theme Component.
  [Migrations-Change](../../openspec/changes/migrate-office-integration-to-plugin/proposal.md)
  nutzt das offizielle Plugin-Skeleton und erhält öffentliche Shares. Dies ist
  eine Planungsfestlegung, keine Implementierungsfreigabe oder ADR-Akzeptanz.
- [Harness-Change](../../openspec/changes/establish-discourse-development-harness/proposal.md)
- [Workflow-Spec-Delta](../../openspec/changes/establish-discourse-development-harness/specs/development-workflow/spec.md)
- [Prüfmatrix](../development/verification.md)
