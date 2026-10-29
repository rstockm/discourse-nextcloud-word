# Spec Delta

## Purpose

Nextcloud-Dateien und Shares werden ohne unbeabsichtigtes Überschreiben oder
Doppelerstellung erzeugt; entfernte Teilfehler bleiben nachvollziehbar und reparierbar.

## ADDED Requirements

### Requirement: Nie bestehende Dokumente überschreiben
Jede neue Operation MUST ein eigenes Ziel unter dem konfigurierten Ordner
erhalten. Gleiche Anzeigenamen und parallele Requests SHALL keine vorhandene
Datei überschreiben; Pfadseparatoren und Unicode-Namen MUST sicher behandelt werden.

#### Scenario: Kollision oder konkurrierender Upload
- **WHEN** das gewählte Ziel bereits existiert oder parallel angelegt wird
- **THEN** wird kein vorhandener Inhalt ersetzt
- **AND** wird ein neuer sicherer Zielpfad verwendet oder ein kontrollierter Konflikt gemeldet

### Requirement: Wiederholungen sind idempotent
Wiederholungen derselben Operation durch denselben Nutzer SHALL innerhalb des
dokumentierten Wiederholungsfensters dasselbe Ergebnis liefern, ohne weitere
Dateien/Shares anzulegen. Ein wiederverwendeter Schlüssel mit anderer Nutzlast
MUST abgelehnt werden.

#### Scenario: Doppelklick oder verlorene Antwort
- **WHEN** zwei gleiche Requests gleichzeitig oder nach einem Antwortverlust eintreffen
- **THEN** wird höchstens eine Datei und ein zugehöriger Share erstellt
- **AND** können nur der ursprüngliche Nutzer und autorisierte Serverprozesse den Status abrufen

#### Scenario: Veränderte Nutzlast
- **WHEN** derselbe Nutzer denselben Schlüssel mit anderem Inhalt oder anderen Parametern sendet
- **THEN** wird ein Konflikt zurückgegeben statt die vorhandene Operation zu verändern

### Requirement: Bearbeitbare Shares mit optionalem Passwort erhalten
Erfolgreiche Operationen SHALL einen öffentlichen Nextcloud-Share mit Lesen und
Bearbeiten liefern, bei Vorlagenerstellung optional passwortgeschützt.
Eine fehlgeschlagene Passwortvergabe MUST niemals durch einen ungeschützten Share ersetzt werden.

#### Scenario: Share-Erstellung erfolgreich
- **WHEN** HTTP- und OCS-Ergebnis sowie zurückgegebene URL gültig sind
- **THEN** erhält der Nutzer den geprüften Share-Link und den tatsächlich verwendeten Dateinamen
- **AND** bleibt das Dokument über Nextcloud/Collabora bearbeitbar

#### Scenario: Passwortpolicy nicht erfüllt
- **WHEN** Nextcloud das gewünschte Passwort ablehnt
- **THEN** wird kein ungeschützter Erfolgslink geliefert

### Requirement: Teilfehler sicher auflösen
Bei Datei-/Share-Timeouts oder Prozessabbrüchen MUST der Zustand vor einer
erneuten Mutation abgeglichen werden. Der Abgleich SHALL bei erneuter Anfrage
oder Statusabfrage erfolgen. Phase 1 MUST auf automatische entfernte Löschungen
und periodische Remote-Abgleichjobs verzichten. Unvollständige Vorgänge SHALL
für gezielte Betreiberbereinigung nachvollziehbar bleiben.

#### Scenario: Share existiert trotz verlorener Antwort
- **WHEN** nach der Share-Anfrage die Verbindung abbricht
- **THEN** wird vor Wiederholung oder Löschung der Share-Zustand des eindeutigen Ziels abgefragt
- **AND** wird kein bereits erfolgreich ausgegebenes Dokument automatisch gelöscht

#### Scenario: Bereinigung nicht möglich
- **WHEN** eine notwendige Bereinigung Nextcloud nicht erreicht
- **THEN** bleibt der Vorgang als reparaturbedürftig nachvollziehbar und wird bei erneuter Nutzeranfrage begrenzt geprüft
- **AND** bleiben fremde oder bestehende Dateien und Shares unangetastet

#### Scenario: Lokale Aufbewahrungsfrist endet
- **WHEN** abgeschlossene lokale Journaldaten nach Ablauf der Frist entfernt werden
- **THEN** werden keine Nextcloud-Dateien oder Shares gelöscht

### Requirement: Öffentliche Linkrechte bleiben unverändert
Phase 1 SHALL keine Topic-/Gruppenrechte, SSO oder automatischen Rechtewiderruf
für Shares einführen. Dokumentation und Oberfläche MUST öffentliche Links als
solche kenntlich machen, nicht als vertrauliche Discourse-Ablage.

#### Scenario: Discourse-Mitgliedschaft endet
- **WHEN** ein Nutzer einen bereits bekannten öffentlichen Share-Link besitzt
- **THEN** wird dessen Nextcloud-Zugriff durch diese Phase nicht automatisch entzogen
