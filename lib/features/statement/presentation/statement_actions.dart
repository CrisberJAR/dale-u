import 'dart:async';

import 'package:dale_u/features/statement/data/statement_pdf.dart';
import 'package:dale_u/features/statement/domain/statement.dart';
import 'package:dale_u/features/statement/domain/whatsapp_reminder.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Comparte el estado de cuenta en PDF (WhatsApp, correo, Drive…).
/// Funciona sin señal: el PDF se arma en el teléfono.
Future<void> shareStatementPdf(
  BuildContext context,
  Statement statement,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final bytes = await StatementPdf.build(statement);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
        fileNameOverrides: [StatementPdf.fileName(statement)],
        subject: 'Estado de cuenta de ${statement.clientName}',
      ),
    );
  } catch (error, stack) {
    debugPrint('Share PDF failed: ${error.runtimeType}');
    debugPrint('$stack');
    messenger?.showSnackBar(
      const SnackBar(content: Text('No se pudo armar el PDF.')),
    );
  }
}

/// Cobro por WhatsApp: comparte el PDF del estado de cuenta con el
/// recordatorio ya escrito. Android no deja adjuntar un archivo al chat de
/// un número (wa.me es solo texto), así que se abre el menú de compartir:
/// el vendedor elige WhatsApp y el contacto. Funciona sin señal.
///
/// El enlace al estado de cuenta en la web ([StatementLinkService]) queda
/// en pausa hasta publicar Hosting + Functions o la ficha en Play Store.
Future<void> sendWhatsAppReminder(
  BuildContext context, {
  required Statement statement,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final text = WhatsAppReminder.message(
    clientName: statement.clientName,
    vendorName: statement.vendorName,
    balanceCents: statement.balanceCents,
  );
  try {
    final bytes = await StatementPdf.build(statement);
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
        fileNameOverrides: [StatementPdf.fileName(statement)],
        subject: 'Estado de cuenta de ${statement.clientName}',
      ),
    );
  } catch (error, stack) {
    debugPrint('WhatsApp reminder failed: ${error.runtimeType}');
    debugPrint('$stack');
    messenger?.showSnackBar(
      const SnackBar(content: Text('No se pudo armar el PDF.')),
    );
  }
}
