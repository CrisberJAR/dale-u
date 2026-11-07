import 'dart:async';

import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/client/presentation/pages/client_detail_page.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:dale_u/features/presence/presentation/viewmodels/presence_view_model.dart';
import 'package:dale_u/features/radar/domain/debtor_hit.dart';
import 'package:dale_u/features/radar/presentation/viewmodels/debtor_radar_view_model.dart';
import 'package:dale_u/features/voice/presentation/viewmodels/voice_capture_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Escucha el GPS en ruta y avisa en el teléfono. Sin FCM.
class DebtorRadarListener extends StatefulWidget {
  const DebtorRadarListener({super.key, required this.child});

  final Widget child;

  @override
  State<DebtorRadarListener> createState() => _DebtorRadarListenerState();
}

class _DebtorRadarListenerState extends State<DebtorRadarListener> {
  late final PresenceViewModel _presence;
  late final ClientViewModel _clients;
  late final DebtorRadarViewModel _radar;
  var _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _presence = context.read<PresenceViewModel>();
    _clients = context.read<ClientViewModel>();
    _radar = context.read<DebtorRadarViewModel>();
    _presence.addListener(_scan);
    _clients.addListener(_scan);
    _radar.addListener(_onHit);
  }

  @override
  void dispose() {
    _presence.removeListener(_scan);
    _clients.removeListener(_scan);
    _radar.removeListener(_onHit);
    super.dispose();
  }

  void _scan() {
    _radar.scan(
      onRoute: _presence.onRoute,
      here: _presence.lastReadFix,
      clients: _clients.clients,
      balances: _clients.balances,
    );
  }

  void _onHit() {
    final hit = _radar.pending;
    if (hit == null || _dialogOpen || !mounted) return;
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_present(hit));
    });
  }

  Future<void> _present(DebtorHit hit) async {
    HapticFeedback.vibrate();
    unawaited(context.read<VoiceCaptureViewModel>().say(hit.spokenLine));
    if (!mounted) {
      _dialogOpen = false;
      return;
    }
    final action = await showDialog<_RadarAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: VendorLook.surface,
          title: Text('Cerca de un deudor', style: VendorLook.subtitle),
          content: Text(hit.screenLine, style: VendorLook.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _RadarAction.mute),
              child: Text(
                'No avisar más de esta casa',
                style: VendorLook.body,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _RadarAction.later),
              child: Text('Ahora no', style: VendorLook.subtitle),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _RadarAction.open),
              child: Text('Ver ficha', style: VendorLook.subtitle),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      _dialogOpen = false;
      return;
    }
    _radar.dismiss();
    _dialogOpen = false;
    if (action == _RadarAction.mute) {
      await _radar.setMuted(clientId: hit.clientId, muted: true);
    }
    if (action == _RadarAction.open && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ClientDetailPage(clientId: hit.clientId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

enum _RadarAction { open, later, mute }
