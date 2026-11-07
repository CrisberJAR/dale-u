import 'dart:typed_data';

import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/statement/domain/statement.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Estado de cuenta en PDF, armado en el teléfono (sin señal también).
/// Letra grande: lo leen personas mayores en el celular.
final class StatementPdf {
  const StatementPdf._();

  static const _ink = PdfColor.fromInt(0xFF2B1D0E);
  static const _muted = PdfColor.fromInt(0xFF6B5A45);
  static const _line = PdfColor.fromInt(0xFFE2D6C2);
  static const _debt = PdfColor.fromInt(0xFFB71C1C);
  static const _paid = PdfColor.fromInt(0xFF1B5E20);

  static Future<Uint8List> build(Statement statement) async {
    final doc = pw.Document(
      title: 'Estado de cuenta de ${statement.clientName}',
      author: statement.vendorLabel,
      creator: 'Dale U',
    );
    final balanceColor = statement.balanceCents > 0 ? _debt : _paid;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: _muted),
          ),
        ),
        build: (context) => [
          pw.Text(
            'Estado de cuenta',
            style: pw.TextStyle(
              fontSize: 26,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${statement.vendorLabel} · Generado el '
            '${peruDateLabel(statement.generatedAt)} a las '
            '${peruTimeLabel(statement.generatedAt)}',
            style: const pw.TextStyle(fontSize: 12, color: _muted),
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line, width: 1.5),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  statement.clientName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  statement.balanceLine,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: balanceColor,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Movimientos',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 8),
          if (statement.movements.isEmpty)
            pw.Text(
              'Aún no hay fiados ni pagos.',
              style: const pw.TextStyle(fontSize: 13, color: _muted),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Fecha', 'Hora', 'Tipo', 'Monto'],
              data: [
                for (final movement in statement.movements)
                  [
                    peruDateLabel(movement.occurredAt),
                    peruTimeLabel(movement.occurredAt),
                    movement.kind.spokenLabel,
                    '${movement.kind == MovementKind.pago ? '-' : ''}'
                        'S/ ${formatSoles(movement.amountCents)}',
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
              cellStyle: const pw.TextStyle(fontSize: 13, color: _ink),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF6EFE3),
              ),
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: _line, width: 0.8),
                bottom: pw.BorderSide(color: _line, width: 0.8),
              ),
              cellAlignments: const {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
              },
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 7,
              ),
            ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Fiado suma a la deuda; pago la resta. Los montos están en soles.',
            style: const pw.TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// "estado-de-cuenta-maria-lopez.pdf"
  static String fileName(Statement statement) {
    final slug = statement.clientName
        .toLowerCase()
        .replaceAll(RegExp('[áàä]'), 'a')
        .replaceAll(RegExp('[éèë]'), 'e')
        .replaceAll(RegExp('[íìï]'), 'i')
        .replaceAll(RegExp('[óòö]'), 'o')
        .replaceAll(RegExp('[úùü]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'estado-de-cuenta${slug.isEmpty ? '' : '-$slug'}.pdf';
  }
}
