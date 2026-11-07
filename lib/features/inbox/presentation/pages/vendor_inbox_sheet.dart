import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/client/presentation/pages/client_detail_page.dart';
import 'package:dale_u/features/inbox/domain/pan_request.dart';
import 'package:dale_u/features/inbox/presentation/viewmodels/vendor_inbox_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Ventana de recados. No vive en la casa: la casa es para hablar.
Future<void> showVendorInboxSheet(BuildContext host) {
  return showModalBottomSheet<void>(
    context: host,
    isScrollControlled: true,
    backgroundColor: VendorLook.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return VendorInboxSheet(
        onOpenClient: (clientId) {
          Navigator.of(sheetContext).pop();
          Navigator.of(host).push(
            MaterialPageRoute<void>(
              builder: (_) => ClientDetailPage(clientId: clientId),
            ),
          );
        },
      );
    },
  );
}

class VendorInboxSheet extends StatelessWidget {
  const VendorInboxSheet({super.key, required this.onOpenClient});

  final void Function(String clientId) onOpenClient;

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<VendorInboxViewModel>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFBBBBBB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pedidos de pan',
              textAlign: TextAlign.center,
              style: VendorLook.title,
            ),
            const SizedBox(height: 12),
            if (inbox.unread.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Nadie te pidió pan.',
                  textAlign: TextAlign.center,
                  style: VendorLook.body,
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: inbox.unread.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _PanCard(
                      request: inbox.unread[index],
                      onOpenClient: onOpenClient,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PanCard extends StatelessWidget {
  const _PanCard({required this.request, required this.onOpenClient});

  final PanRequest request;
  final void Function(String clientId) onOpenClient;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VendorLook.surface,
      elevation: VendorLook.cardElevation,
      shadowColor: VendorLook.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VendorLook.radius),
        side: VendorLook.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              request.label,
              textAlign: TextAlign.center,
              style: VendorLook.subtitle,
            ),
            const SizedBox(height: 8),
            VendorPrimaryButton(
              label: 'Ver ficha',
              icon: Icons.person,
              onPressed: () => onOpenClient(request.clientId),
            ),
            VendorTextAction(
              label: 'Listo, ya lo entregué',
              onPressed: () {
                context.read<VendorInboxViewModel>().markSeen(request);
              },
            ),
          ],
        ),
      ),
    );
  }
}
