import 'dart:async';

import 'package:dale_u/features/statement/data/statement_link_service.dart';
import 'package:dale_u/features/statement/data/statement_pdf.dart';
import 'package:dale_u/features/statement/domain/statement.dart';
import 'package:dale_u/features/statement/domain/whatsapp_reminder.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Abre WhatsApp con el recordatorio escrito y el enlace al estado de
/// cuenta. El vendedor revisa y pulsa enviar: nada sale solo.
///
/// [beforeLink] sube lo pendiente para que el enlace muestre lo último.
Future<void> sendWhatsAppReminder(
  BuildContext context, {
  required Statement statement,
  required String phone,
  required String vendorUid,
  required String clientId,
  StatementLinkService? links,
  Future<void> Function()? beforeLink,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  String? link;
  if (links != null) {
    try {
      if (beforeLink != null) {
        await beforeLink().timeout(const Duration(seconds: 10));
      }
    } catch (error) {
      debugPrint('Sync before reminder failed: ${error.runtimeType}');
    }
    try {
      link = await links.linkFor(vendorUid: vendorUid, clientId: clientId);
    } catch (error) {
      debugPrint('Statement link failed: ${error.runtimeType}');
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Sin señal para el enlace. Va solo el mensaje.'),
        ),
      );
    }
  }
  final text = WhatsAppReminder.message(
    clientName: statement.clientName,
    vendorName: statement.vendorName,
    balanceCents: statement.balanceCents,
    link: link,
  );
  final uri = WhatsAppReminder.uri(phone: phone, text: text);
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('WhatsApp launch failed: ${error.runtimeType}');
  }
  if (!opened) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
    );
  }
}
