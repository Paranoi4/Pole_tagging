// test/tag_sheet_pdf_test.dart
//
// Covers the tag sheet builder only. It is pure Dart on top of the `pdf`
// package, so it runs without a device - the `printing` plugin that sends the
// sheet to a printer is platform code and is not exercised here.
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/batch.dart';
import 'package:frontend/models/tag.dart';
import 'package:frontend/services/tag_sheet_pdf.dart';

Batch _batch() => Batch(
      batchId: 1,
      duId: 1,
      batchCode: 'BT-NP-2026-0001',
      quantity: 5,
      status: 'Pending',
    );

List<Tag> _tags(int n) => [
      for (var i = 0; i < n; i++)
        Tag(
          tagId: i + 1,
          duId: 1,
          batchId: 1,
          tagCode: 'NP${i.toString().padLeft(4, '0')}',
          poleNo: '${100 + i}',
          status: 'Available',
        ),
    ];

void main() {
  test('builds a PDF for a single-page batch', () async {
    final bytes = await TagSheetPdf.build(batch: _batch(), tags: _tags(5));

    expect(bytes.length, greaterThan(0));
    // Every PDF starts with the %PDF- magic bytes.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('a batch larger than one page still renders', () async {
    // 25 tags over a 10-per-page grid is 3 pages, the last one short - the
    // short page is where the padding logic could go out of range.
    final bytes = await TagSheetPdf.build(batch: _batch(), tags: _tags(25));

    expect(bytes.length, greaterThan(0));
  });

  test('an exactly-full page renders', () async {
    final bytes = await TagSheetPdf.build(
      batch: _batch(),
      tags: _tags(TagSheetPdf.tagsPerPage),
    );

    expect(bytes.length, greaterThan(0));
  });

  test('one tag renders', () async {
    final bytes = await TagSheetPdf.build(batch: _batch(), tags: _tags(1));

    expect(bytes.length, greaterThan(0));
  });
}
