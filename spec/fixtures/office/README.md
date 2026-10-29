# Synthetische Office-Fixtures

Diese Dateien wurden ausschließlich für Tests erzeugt. Sie enthalten keine
Nutzerdaten, keine echten Dokumente und keine Makros. Erzeuger ist
[`script/generate-office-fixtures`](../../../script/generate-office-fixtures)
mit fester ZIP-Zeit (`2026-01-01T00:00:00Z`) und den Bibliotheken aus dem
isolierten Core-Bundle (`rubyzip`).

Es sind minimale, strukturell konsistente OOXML-/ODF-Pakete: Content-Types,
Root-Relationships und Hauptteil sind vorhanden, ODF zusätzlich `mimetype`
(unkomprimiert, erster Eintrag), Manifest und `content.xml`. Eine echte
Öffnung in Microsoft Office, LibreOffice oder Collabora wurde in dieser
Umgebung nicht durchgeführt; die Abnahme ist strukturell, nicht optisch.

Neu erzeugen:

```sh
BUNDLE_GEMFILE="$PWD/.local/discourse/Gemfile" BUNDLE_PATH="$PWD/.local/bundle" \
  PATH="/opt/homebrew/opt/ruby@3.4/bin:$PWD/.local/gems/bin:$PATH" \
  .local/gems/bin/bundle exec ruby script/generate-office-fixtures
```

| Datei | Bytes | SHA-256 |
| --- | ---: | --- |
| `template.docx` | 1043 | `3a4693d6e5fd93e7eb4e5302dc4b040a0ab8377d5cb473e618b8d81b10f16356` |
| `template.xlsx` | 1784 | `db08a2be857aaeae0360a8ea529b9f109e980b283151064c6eab9cefd8e8a6b6` |
| `template.pptx` | 1428 | `d626b14fed37fd098d4ec8868b08cdd2be9cd171f508ff3654f7d18185244d23` |
| `upload.docx` | 1067 | `3fd814ca43009f181568c0872847b407ed9a749d65e98c4ec9819ef1189f474a` |
| `upload.xlsx` | 1809 | `2f3d5ec555e46cb772ba74a7f3aeec57ab061c29b3a3d03acd65d1ffe456f45c` |
| `upload.pptx` | 1452 | `6d4a01529125974e570ec759f07b3fcb8fff35820502e933d6c452120fa088f3` |
| `upload.odt` | 874 | `a48c045e746dc45fa63e33f6d38c89e03ac83c5db913fcab29cb7f53b2f2eaa3` |
| `upload.ods` | 929 | `96a817d451a75c9054aa41ddb2eff91258e9b32a92cc458bf26e02d1215aa208` |
| `upload.odp` | 911 | `d9f23fc9a1b136dfb2c13abe649a6f28e7d7da18b38ce624e71b2bd468e29436` |

`upload.pptx` und `template.pptx` sind bewusst leere Präsentationen. Die
DOCX-/XLSX-Uploads enthalten einen kurzen Text bzw. eine Zelle; Vorlagen enthalten
keinen Beispieltext. Der Generator aktualisiert gleichzeitig die Laufzeitkopien
unter `templates/`. Ungültige Varianten (generisches ZIP, Makro, Verschlüsselung,
defektes XML) werden in den Specs zur Laufzeit erzeugt und nicht eingecheckt.

Die Fixtures ersetzen keinen Virenscan. `PackageValidator` prüft Struktur,
Hauptteile, Makro-/Verschlüsselungsmarker, gefährliche Eintragsnamen sowie die
Archiv-/XML-Budgets aus Aufgabe 2.4.
