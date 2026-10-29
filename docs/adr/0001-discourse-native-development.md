# 0001: Discourse-natives Entwicklungsprofil

- Status: proposed
- Datum: 2026-10-28
- Entscheidungsträger: noch nicht bestätigt
- Freigabegrenze: Harness-Einrichtung freigegeben, keine gesonderte ADR-Akzeptanz

## Kontext und Problem

Das Projekt ist eine Discourse Theme Component mit PHP-Middleware. Die
eingebrachten Guidelines beschreiben dagegen Static-/Service-Apps. Eine
unveränderte Übernahme würde einen zweiten Frontend-Stack und ungeeignete
Testannahmen einführen. Der Bestand nutzt teilweise alte Ember-/Dialog-Muster.

## Betrachtete Optionen

- Guidelines-Stack unverändert: vertraute Werkzeuge, aber Vite/Tailwind und eine
  eigenständige App passen nicht zur von Discourse bereitgestellten Laufzeit.
- Eigenes minimales Discourse-Profil: native UI/APIs und offizielles Skeleton-
  Tooling, dafür Abhängigkeit von Core-Entwicklung und komplexerer Testumgebung.
- Status quo ohne Harness: kein Einrichtungsaufwand, aber keine verlässliche
  Quellen-, Freigabe- oder Prüfdisziplin.

## Entscheidung und Begründung

Vorschlag: ein Discourse-natives Profil verwenden. Prozess/Sicherheit aus den
Guidelines übernehmen, konkrete Bibliotheken und Tests dagegen aus aktuellen
offiziellen Discourse-Quellen ableiten. Kein eigener Build-Stack nur für das Theme.

OpenSpec hält Verhalten und Änderungen fest; Markdown-ADRs erklären langlebige
Architekturentscheidungen. Offizielle Core-Integration statt eigener Schemas
oder Agentenketten. Quellenprüfung und reproduzierbarer Versionsstand ergänzen
sich: frisch recherchieren, danach bewusst pinnen und prüfen.

## Konsequenzen

- Positiv: weniger Stack-Mischung, native UX und realistische Core-Kompatibilität;
  Prozesskontext bleibt im Repository.
- Negativ: Tests benötigen Discourse-Kontext; regelmäßige Quellenprüfung und
  bewusste Behandlung offizieller Vorabversionen sind nötig.
- Regeln sind zunächst Agenten-/Review-Verträge, keine technischen CI-Gates.
  Der Bestands-Code wird durch ihre Einführung nicht automatisch modernisiert.

## Überprüfung

Harness gegen Workflow-Szenarien reviewen. Ein separater Tooling-Change muss
Skeleton-Diff, native Tests und reproduzierbare Abhängigkeiten liefern; ein
späterer UI-Change muss beide Composer-Modi und echte Browser-Geometrie prüfen.

## Verknüpfungen

- [Change](../../openspec/changes/establish-discourse-development-harness/proposal.md)
- [Workflow-Spec-Delta](../../openspec/changes/establish-discourse-development-harness/specs/development-workflow/spec.md)
- [Standards](../development/discourse-standards.md) und [Quellen](../development/upstream-sources.md)
