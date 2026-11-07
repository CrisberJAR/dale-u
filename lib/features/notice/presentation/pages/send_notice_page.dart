import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:dale_u/features/notice/presentation/viewmodels/vendor_notice_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SendNoticePage extends StatefulWidget {
  const SendNoticePage({super.key});

  @override
  State<SendNoticePage> createState() => _SendNoticePageState();
}

class _SendNoticePageState extends State<SendNoticePage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final clients = context.read<ClientViewModel>();
    final session = context.read<AuthViewModel>().session;
    final ok = await context.read<VendorNoticeViewModel>().send(
      body: _controller.text,
      vendorName: session?.displayName ?? 'Tu panadero',
      buyerUids: [
        for (final client in clients.clients)
          if (client.isLinked) client.linkedUid,
      ],
    );
    if (!mounted) return;
    if (ok) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final notice = context.watch<VendorNoticeViewModel>();
    final linked = context
        .watch<ClientViewModel>()
        .clients
        .where((client) => client.isLinked)
        .length;

    return Theme(
      data: VendorLook.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: VendorLook.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Avisar a clientes',
                  textAlign: TextAlign.center,
                  style: VendorLook.title,
                ),
                const SizedBox(height: 8),
                Text(
                  linked == 0
                      ? 'Nadie tiene la app vinculada todavía. El aviso solo llega a quienes ya escribieron el código.'
                      : linked == 1
                      ? 'Se envía a 1 cliente con la app.'
                      : 'Se envía a $linked clientes con la app.',
                  textAlign: TextAlign.center,
                  style: VendorLook.body,
                ),
                const SizedBox(height: 16),
                Text('Mensaje', style: VendorLook.subtitle),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  maxLength: InputSanitizer.maxNoticeLength,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 20,
                    color: VendorLook.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ej. Hoy no hay pan',
                    hintStyle: const TextStyle(
                      color: Color(0xFF4A4A4A),
                      fontSize: 18,
                    ),
                    filled: true,
                    fillColor: VendorLook.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VendorLook.radius),
                      borderSide: VendorLook.cardBorder,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VendorLook.radius),
                      borderSide: VendorLook.thickBorder,
                    ),
                  ),
                ),
                if (notice.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    notice.errorMessage!,
                    textAlign: TextAlign.center,
                    style: VendorLook.dangerText,
                  ),
                ],
                if (notice.status != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    notice.status!,
                    textAlign: TextAlign.center,
                    style: VendorLook.subtitle,
                  ),
                ],
                const Spacer(),
                VendorPrimaryButton(
                  label: 'Enviar aviso',
                  icon: Icons.campaign,
                  busy: notice.saving,
                  onPressed: notice.saving || linked == 0 ? null : _send,
                ),
                VendorTextAction(
                  label: 'Volver',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
