# Discourse-Standards

Gilt für neue und gezielt modernisierte Bereiche, nicht als Behauptung, der
Altbestand sei bereits konform. Referenz ist das [Quellenregister](upstream-sources.md).

## Aktualität und Kompatibilität

- Vor jeder relevanten API-/UI-/Tooling-Änderung aktuelle offizielle Developer
  Guides, Skeleton und betroffene Core-Schnittstelle prüfen. Im Change Quelle,
  Prüfdatum und Ziel-Commit/Release dokumentieren; keinen alten Chat als Beleg nutzen.
- Dokumentationsdatum allein beweist keine Aktualität. Bearbeiteten ersten
  Guide-Beitrag und Core-Implementierung von alten Diskussionsantworten unterscheiden.
- Bei fehlender entscheidungsrelevanter Quelle Umsetzung anhalten und Unsicherheit
  berichten. Ein archivierter Stand erklärt Geschichte, nicht zwingend heutiges Soll.
- Geprüften Stand reproduzierbar pinnen, Lockfiles für tatsächlich eingerichtete
  Werkzeuge einchecken. Keine automatischen ungebundenen `latest`-Updates.
- Offizielle Skeleton-Updates erst als Diff prüfen; kein blindes Überschreiben
  des Bestands durch Generatoren, Codemods oder `update-skeleton`.
- Vorabversionen ausdrücklich benennen und Übernahme begründen. Das Skeleton
  verwendet aktuell TypeScript 7.1.0-dev; der Harness installiert es nicht.
- Ziel-Core und unterstützte Release-Spanne anhand echter Tests festlegen.
  `minimum_discourse_version: 2.8.0` ist Bestandsmetadatum, kein Testnachweis.

## Integration und Komponenten

- Discourse stellt Laufzeit und Build bereit: keine eigenständige SPA und keine
  zusätzliche Vite-/Tailwind-Schicht ohne abgestimmte neue Architekturentscheidung.
- Registrierung über aktuelle `apiInitializer`-/Plugin-API-Schnittstellen.
  Outlets und öffentliche Transformer vor DOM-Eingriffen und Klassenänderungen bevorzugen.
- UI als Glimmer-Komponente in `.gjs`/`.gts`, mit expliziten Imports und klaren
  Verantwortlichkeiten. Native Buttons, Inputs und Modal-Service nach Ziel-Core nutzen.
- Keine neuen `Controller.extend`-Modalpaare, Legacy-Widgets, globalen
  HTML-String-Overlays oder nativen `alert`/`confirm`-Dialoge als Produkt-UI.
- `modifyClass` nur mit dokumentierter Notwendigkeit und aktueller Signatur.
  Nicht pauschal als entfernt darstellen: im geprüften Core sind insbesondere
  `model:`-Modifikationen deprecated; andere Resolver brauchen Einzelprüfung.
- Keine internen Controller-/DOM-Details als dauerhaften API-Vertrag behandeln.
  Lifecycle, Cleanup, Abbruch und Navigation/Entwurfswechsel berücksichtigen.

## Composer und asynchrone Abläufe

- Markdown- und Rich-Text-Editor sind eigene Testfälle. Ein Markdown-RegEx oder
  Text-Append ist kein Nachweis einer erfolgreichen Rich-Text-Ersetzung.
- Neue Actions und Upload-Hooks anhand der konkreten Core-Signatur prüfen;
  keine alten String-Actions aus dem Bestand ungeprüft fortschreiben.
- Asynchrone Ergebnisse dem auslösenden Entwurf zuordnen; Doppelaktionen,
  Fehler und Wiederholungen sichtbar und kontrolliert behandeln.
- Discourse-Originalanhang erst nach bestätigtem Erfolg verändern; ein Fehler
  darf weder fremden Entwurf ändern noch unerwartet ein leeres Dokument erzeugen.

## Übersetzungen und Gestaltung

- Neuer Code importiert `i18n` aus `discourse-i18n`, verwendet Theme-Präfixe
  und vollständige englische/deutsche Texte statt globalem `I18n` oder Hardcoding.
- Settings-Beschreibungen in den Locale-Metadaten pflegen, nicht neue einsprachige
  Beschreibungen direkt in `settings.yml` einführen.
- Discourse-Design-Tokens/CSS-Custom-Properties und native UI-Konventionen nutzen.
- Semantische Labels, Tastaturbedienung, sichtbarer Fokus, Fokusführung/-rückgabe,
  Lade-/Fehlerzustände und WCAG 2.2 AA für zentrale Abläufe.
- Responsive Prüfung ab 320 CSS-Pixeln sowie Tablet/Desktop, einschließlich
  realer Browser-Geometrieprüfung gemäß [Prüfmatrix](verification.md).

## Sicherheit und Architekturgrenzen

- Theme-Settings und Browser-Builds sind kein Secret-Speicher. Origin/CORS ist
  kein Ersatz für Nutzer-Authentifizierung; Uploads bleiben nicht vertrauenswürdig.
- Externe Dateigrenzen prüfen: Endung, Formatstruktur/MIME-Plausibilität, Größe,
  sichere Pfade, Timeouts, Ressourcenlimits, Fehlerbereinigung und Wiederholungen.
- Keine Passwörter, Tokens oder Share-URLs mit Zugriffsrechten loggen. Synthetische
  Fixtures statt Produktionsdaten; keine mutierenden Live-Tests ohne Zustimmung.
- Plugin-Entwicklung erst nach eigenem Change. Dann zusätzlich aktuelle offizielle
  Plugin-Vorlagen, Server-APIs und Testwege prüfen; Theme-Regeln nicht blind übertragen.
- Öffentliche Bearbeitungslinks bleiben bis zu gesonderter Entscheidung das
  Bestandsmodell. Discourse-Dateirechte sind ausdrücklich Phase 2.
