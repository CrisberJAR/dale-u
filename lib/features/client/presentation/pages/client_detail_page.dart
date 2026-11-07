import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:dale_u/features/statement/data/statement_link_service.dart';
import 'package:dale_u/features/statement/domain/statement.dart';
import 'package:dale_u/features/statement/presentation/statement_actions.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/presentation/pages/add_client_page.dart';
import 'package:dale_u/features/client/presentation/pages/client_house_map_page.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:dale_u/features/radar/presentation/viewmodels/debtor_radar_view_model.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/presentation/widgets/movements_show_more.dart';
import 'package:dale_u/features/ledger/presentation/pages/edit_movement_page.dart';
import 'package:dale_u/features/ledger/presentation/pages/record_movement_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ClientDetailPage extends StatefulWidget {
  const ClientDetailPage({super.key, required this.clientId});

  final String clientId;

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
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
          title: Text(
            '¿Desactivar cliente?',
            style: VendorLook.subtitle,
          ),
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
              child: Text(
                'Desactivar',
                style: VendorLook.dangerText,
              ),
            ),
          ],
        );
      },
    );
    if (go != true || !mounted) return;
    final ok = await context.read<ClientViewModel>().deactivateClient(client.id);
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
  }

  bool _sharing = false;

  Statement _statementOf(ClientViewModel viewModel, Client client) {
    return Statement(
      vendorName: context.read<AuthViewModel>().session?.displayName ?? '',
      clientName: client.name,
      movements: viewModel.openMovements,
      balanceCents: viewModel.balanceCents(client.id),
      generatedAt: DateTime.now(),
    );
  }

  Future<void> _remind(ClientViewModel viewModel, Client client) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await sendWhatsAppReminder(
        context,
        statement: _statementOf(viewModel, client),
        phone: client.phone,
        vendorUid: client.vendorUid,
        clientId: client.id,
        links: context.read<StatementLinkService?>(),
        beforeLink: viewModel.syncNow,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _sharePdf(ClientViewModel viewModel, Client client) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await shareStatementPdf(context, _statementOf(viewModel, client));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
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
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: client == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        'Este cliente ya no está en la lista.',
                        textAlign: TextAlign.center,
                        style: VendorLook.body,
                      ),
                      const Spacer(),
                      VendorTextAction(
                        label: 'Volver',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        client.name,
                        textAlign: TextAlign.center,
                        style: VendorLook.title,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _debtLine(viewModel.balanceCents(client.id)) ??
                            'Sin deuda',
                        textAlign: TextAlign.center,
                        style: VendorLook.subtitle,
                      ),
                      if (client.phone.isNotEmpty)
                        Text(
                          client.phone,
                          textAlign: TextAlign.center,
                          style: VendorLook.body,
                        ),
                      const SizedBox(height: 10),
                      Text(
                        'Código para que vea su deuda',
                        textAlign: TextAlign.center,
                        style: VendorLook.body,
                      ),
                      SelectableText(
                        client.inviteCode.isEmpty ? '——' : client.inviteCode,
                        textAlign: TextAlign.center,
                        style: VendorLook.title,
                      ),
                      Text(
                        client.isLinked
                            ? 'Ya está vinculada a su celular'
                            : 'Dáselo. Lo escribe una vez en la app.',
                        textAlign: TextAlign.center,
                        style: VendorLook.body,
                      ),
                      if (client.hasHousePin)
                        Text(
                          'Casa marcada en el mapa',
                          textAlign: TextAlign.center,
                          style: VendorLook.body,
                        ),
                      if (viewModel.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          viewModel.errorMessage!,
                          textAlign: TextAlign.center,
                          style: VendorLook.dangerText,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: VendorPrimaryButton(
                              label: 'Cobrar por WhatsApp',
                              icon: Icons.chat,
                              size: VendorControlSize.compact,
                              busy: _sharing,
                              onPressed: _sharing
                                  ? null
                                  : () => _remind(viewModel, client),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: VendorSecondaryButton(
                              label: 'PDF',
                              size: VendorControlSize.compact,
                              onPressed: _sharing
                                  ? null
                                  : () => _sharePdf(viewModel, client),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Movimientos',
                              style: VendorLook.subtitle,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Anotar fiado o pago',
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const RecordMovementPage(),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.add_circle,
                              size: 32,
                              color: VendorLook.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _MovementList(
                          movements: viewModel.openMovements,
                          onTap: (movement) {
                            if (movement.voided) return;
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    EditMovementPage(movement: movement),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      VendorPrimaryButton(
                        label: client.hasHousePin
                            ? 'Mover marca de casa'
                            : 'Marcar casa',
                        icon: Icons.home,
                        size: VendorControlSize.compact,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ClientHouseMapPage(
                                clientId: client.id,
                              ),
                            ),
                          );
                        },
                      ),
                      if (client.hasHousePin) ...[
                        const SizedBox(height: 8),
                        VendorSecondaryButton(
                          label: radar.isMuted(client.id)
                              ? 'Avisar al acercarme'
                              : 'No avisar de esta casa',
                          size: VendorControlSize.compact,
                          onPressed: () {
                            radar.setMuted(
                              clientId: client.id,
                              muted: !radar.isMuted(client.id),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      VendorSecondaryButton(
                        label: 'Editar datos',
                        size: VendorControlSize.compact,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AddClientPage(existing: client),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      VendorDangerButton(
                        label: 'Desactivar cliente',
                        size: VendorControlSize.compact,
                        onPressed: viewModel.saving
                            ? null
                            : () => _confirmDeactivate(client),
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

class _MovementList extends StatefulWidget {
  const _MovementList({required this.movements, required this.onTap});

  final List<Movement> movements;
  final void Function(Movement movement) onTap;

  @override
  State<_MovementList> createState() => _MovementListState();
}

class _MovementListState extends State<_MovementList> {
  int _visible = movementPageSize;

  @override
  void didUpdateWidget(_MovementList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final total = widget.movements.length;
    if (_visible > total) {
      _visible = total < movementPageSize ? movementPageSize : total;
    }
  }

  @override
  Widget build(BuildContext context) {
    final movements = widget.movements;
    if (movements.isEmpty) {
      return Center(
        child: Text(
          'Aún no hay fiados ni pagos.\nPulsa + o usa Hablar en la lista.',
          textAlign: TextAlign.center,
          style: VendorLook.body,
        ),
      );
    }

    final visible = _visible > movements.length ? movements.length : _visible;
    final paged = movements.length > movementPageSize;

    return ListView.separated(
      itemCount: paged ? visible + 1 : visible,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == visible) {
          return MovementsShowMore(
            total: movements.length,
            visible: visible,
            onMore: () => setState(() {
              _visible = nextMovementCount(visible, movements.length);
            }),
            onLess: () => setState(() => _visible = movementPageSize),
          );
        }
        final movement = movements[index];
        final title =
            '${movement.kind.spokenLabel} S/ ${formatSoles(movement.amountCents)}';
        return Material(
          color: VendorLook.surface,
          elevation: VendorLook.cardElevation,
          shadowColor: VendorLook.shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VendorLook.radius),
            side: VendorLook.cardBorder,
          ),
          child: ListTile(
            onTap: movement.voided ? null : () => widget.onTap(movement),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              movement.voided ? '$title (anulado)' : title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: VendorLook.ink,
                decoration: movement.voided
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Text(
              spokenStamp(movement.occurredAt),
              style: VendorLook.body,
            ),
          ),
        );
      },
    );
  }
}

String? _debtLine(int balance) {
  if (balance > 0) return 'Debe S/ ${formatSoles(balance)}';
  if (balance < 0) return 'A favor S/ ${formatSoles(-balance)}';
  return null;
}
