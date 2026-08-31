// lib/services/tag_sheet_pdf.dart
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:frontend/models/batch.dart';
import 'package:frontend/models/tag.dart';

/// Builds the printable tag sheet for a batch and sends it to a printer.
///
/// The layout targets a plain A4 sheet on an ordinary office printer, which is
/// what the site actually has: tags are laid out in a grid with cut borders, so
/// the printerman prints the page and cuts them apart. A dedicated label
/// printer would need a different page size and one tag per page - that is a
/// separate builder, not a variation of this one.
///
/// Every tag on the sheet carries only its tag code and pole number. Anything
/// else (QR code, DU branding) is not on the physical tag today, so putting it
/// here would print something the field crew has not been told to expect.
class TagSheetPdf {
  /// Tags per row and rows per page.
  ///
  /// 2 x 5 on A4 gives each tag roughly 92mm x 53mm - large enough for the code
  /// to stay readable at arm's length on a pole, which is the whole point of the
  /// encoding. Raising these numbers shrinks the code, so change them together
  /// with [_codeFontSize] rather than on their own.
  static const int _columns = 2;
  static const int _rows = 5;
  static const int tagsPerPage = _columns * _rows;

  static const double _codeFontSize = 34;

  /// Renders [tags] as an A4 tag sheet and returns the PDF bytes.
  ///
  /// Tags arrive in the order the caller passes them, so the printed sheet
  /// matches the order shown on the review screen - the printerman checks the
  /// paper against that list.
  static Future<Uint8List> build({
    required Batch batch,
    required List<Tag> tags,
  }) async {
    final doc = pw.Document(title: 'Tags ${batch.batchCode}');

    // Courier for the code: the encoding alphabet drops I, O and X because they
    // misread on a physical tag, and a monospaced face keeps the survivors
    // (0 vs D, 1 vs 7) distinct at a glance.
    //
    // Both are PDF built-ins rather than downloaded faces, so the sheet renders
    // with no network call - the printerman may well be offline.
    final codeFont = pw.Font.courierBold();
    final labelFont = pw.Font.helvetica();

    final pages = _chunk(tags, tagsPerPage);

    for (var i = 0; i < pages.length; i++) {
      final pageTags = pages[i];

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginLeft: 10 * PdfPageFormat.mm,
            marginRight: 10 * PdfPageFormat.mm,
            marginTop: 10 * PdfPageFormat.mm,
            marginBottom: 10 * PdfPageFormat.mm,
          ),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(
                batch: batch,
                labelFont: labelFont,
                page: i + 1,
                pageCount: pages.length,
                totalTags: tags.length,
              ),
              pw.SizedBox(height: 6),
              pw.Expanded(
                child: _grid(
                  pageTags: pageTags,
                  codeFont: codeFont,
                  labelFont: labelFont,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return doc.save();
  }

  /// The strip above the tags. Printed on every page so a sheet that gets
  /// separated from the rest can still be traced back to its batch.
  static pw.Widget _header({
    required Batch batch,
    required pw.Font labelFont,
    required int page,
    required int pageCount,
    required int totalTags,
  }) {
    final printedOn = DateTime.now();

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${batch.batchCode}  ·  $totalTags tags',
            style: pw.TextStyle(font: labelFont, fontSize: 9),
          ),
          pw.Text(
            'Printed ${_formatDateTime(printedOn)}  ·  Page $page of $pageCount',
            style: pw.TextStyle(font: labelFont, fontSize: 9),
          ),
        ],
      ),
    );
  }

  /// The tag grid for one page.
  ///
  /// A short last page is padded with empty cells so its tags keep the same
  /// size and position as every other page - without the padding a final page
  /// of three tags would stretch them across the whole sheet and the cut lines
  /// would no longer line up.
  static pw.Widget _grid({
    required List<Tag> pageTags,
    required pw.Font codeFont,
    required pw.Font labelFont,
  }) {
    final cells = <pw.Widget>[
      for (final tag in pageTags)
        _tagCell(tag: tag, codeFont: codeFont, labelFont: labelFont),
      for (var i = pageTags.length; i < tagsPerPage; i++) pw.SizedBox(),
    ];

    return pw.Column(
      children: [
        for (var row = 0; row < _rows; row++)
          pw.Expanded(
            child: pw.Row(
              children: [
                for (var col = 0; col < _columns; col++)
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: cells[row * _columns + col],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// One tag: its code, large, with the pole number under it.
  static pw.Widget _tagCell({
    required Tag tag,
    required pw.Font codeFont,
    required pw.Font labelFont,
  }) {
    return pw.Container(
      // A visible border doubles as the cut line.
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.7, color: PdfColors.grey600),
      ),
      alignment: pw.Alignment.center,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            tag.tagCode,
            style: pw.TextStyle(
              font: codeFont,
              fontSize: _codeFontSize,
              letterSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'POLE ${tag.poleNo}',
            style: pw.TextStyle(
              font: labelFont,
              fontSize: 12,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  static List<List<T>> _chunk<T>(List<T> items, int size) {
    final out = <List<T>>[];
    for (var start = 0; start < items.length; start += size) {
      final end = (start + size).clamp(0, items.length);
      out.add(items.sublist(start, end));
    }
    return out;
  }

  static String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
