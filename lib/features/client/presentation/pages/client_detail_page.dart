import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:dale_u/features/statement/domain/statement.dart';
import 'package:dale_u/features/statement/presentation/statement_actions.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/presentation/pages/add_client_page.dart';
import 'package:dale_u/features/client/presentation/pages/client_house_map_page.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:dale_u/features/radar/presentation/viewmodels/debtor_radar_view_model.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/ledger/presentation/widgets/movements_show_more.dart';
import 'package:dale_u/features/ledger/presentation/pages/edit_movement_page.dart';
import 'package:dale_u/features/ledger/presentation/pages/record_movement_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Ficha del cliente: cuánto debe, anotar y cobrar arriba; el historial
/// abajo con todo el espacio. Lo de una vez (casa, datos, desactivar) va
/// en el menú.
class ClientDetailPage extends StatefulWidget {
  const ClientDetailPage({super.key, required this.clientId});

  final String clientId;

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  int _visible = movementPageSize;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClientViewModel>().loadClientDetail(widget.clientId);
    });
  }

  Future<void> _confirmDeactivate(Client client) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: VendorLook.surface,
          title: Text('¿Desactivar cliente?', style: VendorLook.subtitle),
          content: Text(
            'Se oculta de la ruta. Solo se puede si está al día (sin deuda). '
            'Si pasa un mes sin fiados ni pagos, se borra del todo para no llenar la libreta.',
            style: VendorLook.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: VendorLook.subtitle),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Desactivar', style: VendorLook.dangerText),
            ),
          ],
        );
      },
    );
    if (go != true || !mounted) return;
    final ok = await context.read<ClientViewModel>().deactivateClient(
      client.id,
    );
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
  }

  Statement _statementOf(ClientViewModel viewModel, Client client) {
    return Statement(
      vendorName: context.read<AuthViewModel>().session?.displayName ?? '',
      clientName: client.name,
      movements: viewModel.openMovements,
      balanceCents: viewModel.balanceCents(client.id),
      generatedAt: DateTime.now(),
    );
  }

  Future<void> _share(Future<void> Function() action) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClientViewModel>();
    final radar = context.watch<DebtorRadarViewModel>();
    final client = viewModel.clientById(widget.clientId);

    return Theme(
      data: VendorLook.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: VendorLook.background,
        appBar: AppBar(
          backgroundColor: VendorLook.background,
          foregroundColor: VendorLook.ink,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          actions: [
            if (client != null)
              _ClientMenu(
                client: client,
                muted: radar.isMuted(client.id),
                busy: viewModel.saving,
                onEdit: () => _push(AddClientPage(existing: client)),
                onHouse: () => _push(ClientHouseMapPage(clientId: client.id)),
                onToggleAlerts: () => radar.setMuted(
                  clientId: client.id,
                  muted: !radar.isMuted(client.id),
                ),
                onDeactivate: () => _confirmDeactivate(client),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: client == null
              ? _Missing(onBack: () => Navigator.of(context).pop())
              : _body(viewModel, client),
        ),
      ),
    );
  }

  Widget _body(ClientViewModel viewModel, Client client) {
    final movements = viewModel.openMovements;
    final shown = _visible > movements.length ? movements.length : _visible;
    final paged = movements.length > movementPageSize;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(client.name, textAlign: TextAlign.center, style: VendorLook.title),
        if (client.phone.isNotEmpty ||
            client.hasHousePin ||
            client.isLinked) ...[
          const SizedBox(height: 4),
          Text(
            [
              if (client.phone.isNotEmpty) client.phone,
              if (client.hasHousePin) 'Casa marcada',
              if (client.isLinked) 'Ve su deuda en su celular',
            ].join(' · '),
            textAlign: TextAlign.center,
            style: VendorLook.body,
          ),
        ],
        const SizedBox(height: 16),
        _BalanceBlock(balanceCents: viewModel.balanceCents(client.id)),
        VendorReveal(
          child: viewModel.errorMessage == null
              ? null
              : Padding(
                  key: ValueKey(viewModel.errorMessage),
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    viewModel.errorMessage!,
                    textAlign: TextAlign.center,
                    style: VendorLook.dangerText,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        VendorPrimaryButton(
          label: 'Anotar fiado o pago',
          icon: Icons.add,
          onPressed: () => _push(const RecordMovementPage()),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: VendorSecondaryButton(
                label: 'Cobrar por WhatsApp',
                icon: Icons.chat_outlined,
                size: VendorControlSize.compact,
                onPressed: _sharing
                    ? null
                    : () => _share(
                        () => sendWhatsAppReminder(
                          context,
                          statement: _statementOf(viewModel, client),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            _SquareAction(
              tooltip: 'Compartir PDF',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: _sharing
                  ? null
                  : () => _share(
                      () => shareStatementPdf(
                        context,
                        _statementOf(viewModel, client),
                      ),
                    ),
            ),
          ],
        ),
        // El código solo sirve hasta que vincula su celular; después estorba.
        if (!client.isLinked) ...[
          const SizedBox(height: 16),
          _InviteBlock(client: client),
        ],
        const SizedBox(height: 24),
        Text('Movimientos', style: VendorLook.subtitle),
        const SizedBox(height: 8),
        if (movements.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Aún no hay fiados ni pagos.\n'
              'Pulsa “Anotar fiado o pago” o di: fiado a ${_firstName(client.name)} 5 soles.',
              textAlign: TextAlign.center,
              style: VendorLook.body,
            ),
          )
        else ...[
          for (final movement in movements.take(shown)) ...[
            _MovementTile(
              movement: movement,
              onTap: movement.voided
                  ? null
                  : () => _push(EditMovementPage(movement: movement)),
            ),
            const SizedBox(height: 8),
          ],
          if (paged)
            MovementsShowMore(
              total: movements.length,
              visible: shown,
              onMore: () => setState(() {
                _visible = nextMovementCount(shown, movements.length);
              }),
              onLess: () => setState(() => _visible = movementPageSize),
            ),
        ],
      ],
    );
  }
}

String _firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

/// El dato que el vendedor viene a ver: grande y sin adornos.
class _BalanceBlock extends StatelessWidget {
  const _BalanceBlock({required this.balanceCents});

  final int balanceCents;

  @override
  Widget build(BuildContext context) {
    final settled = balanceCents == 0;
    final label = balanceCents > 0
        ? 'Debe'
        : balanceCents < 0
        ? 'A favor'
        : 'Sin deuda';
    final amount = settled ? 'Al día' : 'S/ ${formatSoles(balanceCents.abs())}';
    return VendorSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Semantics(
        label: settled ? 'Al día, sin deuda' : '$label $amount',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(label, style: VendorLook.subtitle),
            const SizedBox(height: 2),
            Text(
              amount,
              style: TextStyle(
                fontSize: 36,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: balanceCents < 0 ? VendorLook.paid : VendorLook.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteBlock extends StatelessWidget {
  const _InviteBlock({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return VendorSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.key_outlined,
            size: VendorLook.iconSize,
            color: VendorLook.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Código para que vea su deuda', style: VendorLook.body),
                SelectableText(
                  client.inviteCode.isEmpty ? '——' : client.inviteCode,
                  style: VendorLook.title.copyWith(letterSpacing: 2),
                ),
                Text(
                  'Dáselo. Lo escribe una vez en la app.',
                  style: VendorLook.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.onTap});

  final Movement movement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isPago = movement.kind == MovementKind.pago;
    final tone = movement.voided
        ? VendorLook.muted
        : isPago
        ? VendorLook.paid
        : VendorLook.ink;
    final title =
        '${movement.kind.spokenLabel} S/ ${formatSoles(movement.amountCents)}';
    return Material(
      color: VendorLook.surface,
      elevation: VendorLook.cardElevation,
      shadowColor: VendorLook.shadow,
      shape: VendorLook.cardShape,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        minTileHeight: 64,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          isPago ? Icons.payments_outlined : Icons.shopping_basket_outlined,
          size: 26,
          color: tone,
        ),
        title: Text(
          movement.voided ? '$title (anulado)' : title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: tone,
            fontFeatures: const [FontFeature.tabularFigures()],
            decoration: movement.voided ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          spokenStamp(movement.occurredAt),
          style: VendorLook.body,
        ),
        trailing: onTap == null
            ? null
            : Icon(Icons.chevron_right, color: VendorLook.muted),
      ),
    );
  }
}

/// Botón cuadrado de 48 dp para una acción que el ícono ya explica.
class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return VendorPressable(
      enabled: onPressed != null,
      child: SizedBox.square(
        dimension: VendorLook.compactButtonHeight,
        child: Tooltip(
          message: tooltip,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: VendorLook.ink,
              backgroundColor: VendorLook.surface,
              side: VendorLook.thickBorder,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VendorLook.buttonRadius),
              ),
            ),
            child: Icon(icon, size: VendorLook.iconSize),
          ),
        ),
      ),
    );
  }
}

class _ClientMenu extends StatelessWidget {
  const _ClientMenu({
    required this.client,
    required this.muted,
    required this.busy,
    required this.onEdit,
    required this.onHouse,
    required this.onToggleAlerts,
    required this.onDeactivate,
  });

  final Client client;
  final bool muted;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onHouse;
  final VoidCallback onToggleAlerts;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<VoidCallback> item(
      VoidCallback action,
      IconData icon,
      String label, {
      bool danger = false,
      bool enabled = true,
    }) {
      final color = danger ? VendorLook.danger : VendorLook.ink;
      return PopupMenuItem<VoidCallback>(
        value: action,
        enabled: enabled,
        height: 52,
        child: Row(
          children: [
            Icon(icon, size: VendorLook.iconSize, color: color),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: VendorLook.subtitle.copyWith(
                  color: color,
                  fontWeight: danger ? FontWeight.w700 : null,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<VoidCallback>(
      tooltip: 'Más opciones del cliente',
      icon: Icon(Icons.more_vert, color: VendorLook.ink),
      color: VendorLook.surface,
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        item(onEdit, Icons.edit_outlined, 'Editar datos'),
        item(
          onHouse,
          Icons.home_outlined,
          client.hasHousePin ? 'Mover marca de casa' : 'Marcar casa',
        ),
        if (client.hasHousePin)
          item(
            onToggleAlerts,
            muted
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            muted ? 'Avisar al acercarme' : 'No avisar de esta casa',
          ),
        const PopupMenuDivider(),
        item(
          onDeactivate,
          Icons.person_off_outlined,
          'Desactivar cliente',
          danger: true,
          enabled: !busy,
        ),
      ],
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'Este cliente ya no está en la lista.',
            textAlign: TextAlign.center,
            style: VendorLook.body,
          ),
          const Spacer(),
          VendorSecondaryButton(label: 'Volver', onPressed: onBack),
        ],
      ),
    );
  }
}
