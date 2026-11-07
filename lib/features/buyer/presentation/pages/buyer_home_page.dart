import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/core/theme/look_switch.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:dale_u/features/buyer/presentation/viewmodels/buyer_view_model.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/presentation/widgets/movements_show_more.dart';
import 'package:dale_u/features/notice/presentation/widgets/buyer_notice_banner.dart';
import 'package:dale_u/features/presence/presentation/pages/buyer_map_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BuyerHomePage extends StatelessWidget {
  const BuyerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final buyer = context.watch<BuyerViewModel>();
    final session = context.watch<AuthViewModel>().session;

    return Theme(
      data: VendorLook.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: VendorLook.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Mi cuenta',
                  textAlign: TextAlign.center,
                  style: BuyerLook.title,
                ),
                Text(
                  session?.displayName ?? 'Cliente',
                  textAlign: TextAlign.center,
                  style: BuyerLook.subtitle,
                ),
                const SizedBox(height: 16),
                if (buyer.loading && !buyer.isLinked)
                  Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: VendorLook.ink),
                    ),
                  )
                else if (!buyer.isLinked)
                  Expanded(child: _FirstLink())
                else
                  Expanded(child: _Ledgers(buyer: buyer)),
                const LookSwitchAction(),
                VendorSecondaryButton(
                  label: 'Cerrar sesión',
                  size: VendorControlSize.compact,
                  onPressed: context.read<AuthViewModel>().signOut,
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

class _FirstLink extends StatefulWidget {
  const _FirstLink();

  @override
  State<_FirstLink> createState() => _FirstLinkState();
}

class _FirstLinkState extends State<_FirstLink> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyer = context.watch<BuyerViewModel>();
    return ListView(
      children: [
        Text(
          'Pide al vendedor el código de 6 letras de tu ficha y escríbelo aquí. Así ves tu deuda.',
          textAlign: TextAlign.center,
          style: BuyerLook.body,
        ),
        const SizedBox(height: 16),
        _CodeField(controller: _controller),
        if (buyer.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            buyer.errorMessage!,
            textAlign: TextAlign.center,
            style: BuyerLook.dangerText,
          ),
        ],
        const SizedBox(height: 12),
        VendorPrimaryButton(
          label: 'Vincular',
          busy: buyer.saving,
          size: VendorControlSize.compact,
          onPressed: buyer.saving
              ? null
              : () => buyer.linkWithCode(_controller.text),
        ),
      ],
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      textAlign: TextAlign.center,
      style: BuyerLook.title,
      maxLength: 8,
      decoration: InputDecoration(
        counterText: '',
        hintText: 'ABC23X',
        hintStyle: BuyerLook.body,
        filled: true,
        fillColor: VendorLook.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VendorLook.radius),
          borderSide: VendorLook.cardBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VendorLook.radius),
          borderSide: VendorLook.thickBorder,
        ),
      ),
    );
  }
}

class _Ledgers extends StatelessWidget {
  const _Ledgers({required this.buyer});

  final BuyerViewModel buyer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _totalLine(buyer.totalbalanceCents),
          textAlign: TextAlign.center,
          style: BuyerLook.title,
        ),
        Text(
          buyer.ledgers.length == 1
              ? 'Con 1 vendedor'
              : 'Con ${buyer.ledgers.length} vendedores',
          textAlign: TextAlign.center,
          style: BuyerLook.body,
        ),
        if (buyer.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            buyer.errorMessage!,
            textAlign: TextAlign.center,
            style: BuyerLook.dangerText,
          ),
        ],
        if (buyer.panStatus != null) ...[
          const SizedBox(height: 8),
          Text(
            buyer.panStatus!,
            textAlign: TextAlign.center,
            style: BuyerLook.body,
          ),
        ],
        const SizedBox(height: 12),
        const BuyerNoticeBanner(),
        Expanded(
          child: ListView.separated(
            itemCount: buyer.ledgers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ledger = buyer.ledgers[index];
              return _VendorCard(
                key: ValueKey(ledger.account.id),
                ledger: ledger,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        VendorPrimaryButton(
          label: 'Ver panadero',
          icon: Icons.map,
          size: VendorControlSize.compact,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BuyerMapPage(
                  accounts: buyer.ledgers
                      .map((ledger) => ledger.account)
                      .toList(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        VendorPrimaryButton(
          label: 'Agregar otro vendedor',
          icon: Icons.add,
          size: VendorControlSize.compact,
          onPressed: () => _openAddSheet(context),
        ),
      ],
    );
  }

  Future<void> _openAddSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VendorLook.background,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: ChangeNotifierProvider<BuyerViewModel>.value(
          value: buyer,
          child: const _AddVendorSheet(),
        ),
      ),
    );
  }
}

class _AddVendorSheet extends StatefulWidget {
  const _AddVendorSheet();

  @override
  State<_AddVendorSheet> createState() => _AddVendorSheetState();
}

class _AddVendorSheetState extends State<_AddVendorSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyer = context.watch<BuyerViewModel>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Otro vendedor', style: BuyerLook.title),
            const SizedBox(height: 6),
            Text(
              'Escribe el código de 6 letras que te dio ese vendedor. Tus otras deudas no se tocan.',
              style: BuyerLook.body,
            ),
            const SizedBox(height: 16),
            _CodeField(controller: _controller),
            if (buyer.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(buyer.errorMessage!, style: BuyerLook.dangerText),
            ],
            const SizedBox(height: 12),
            VendorPrimaryButton(
              label: 'Vincular',
              busy: buyer.saving,
              size: VendorControlSize.compact,
              onPressed: buyer.saving
                  ? null
                  : () async {
                      final ok = await buyer.linkWithCode(_controller.text);
                      if (ok && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorCard extends StatefulWidget {
  const _VendorCard({super.key, required this.ledger});

  final BuyerLedger ledger;

  @override
  State<_VendorCard> createState() => _VendorCardState();
}

class _VendorCardState extends State<_VendorCard> {
  int _visible = movementPageSize;

  @override
  void didUpdateWidget(_VendorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final total = widget.ledger.movements.length;
    if (_visible > total) {
      _visible = total < movementPageSize ? movementPageSize : total;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = widget.ledger;
    final buyer = context.watch<BuyerViewModel>();
    final sending = buyer.sendingPan(ledger.account.id);
    final movements = ledger.movements;
    final visible = _visible > movements.length ? movements.length : _visible;

    return Material(
      color: VendorLook.surface,
      elevation: VendorLook.cardElevation,
      shadowColor: VendorLook.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VendorLook.radius),
        side: VendorLook.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              iconColor: VendorLook.ink,
              collapsedIconColor: VendorLook.ink,
              title: Text(
                ledger.vendorLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: VendorLook.ink,
                ),
              ),
              subtitle: Text(
                _debtLine(ledger.balanceCents),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: VendorLook.muted,
                ),
              ),
              children: [
                if (movements.isEmpty)
                  Text(
                    'Aún no hay fiados ni pagos.',
                    style: BuyerLook.body,
                  )
                else ...[
                  for (final movement in movements.take(visible))
                    _MovementRow(movement: movement),
                  if (movements.length > movementPageSize)
                    MovementsShowMore(
                      total: movements.length,
                      visible: visible,
                      onMore: () => setState(() {
                        _visible = nextMovementCount(
                          visible,
                          movements.length,
                        );
                      }),
                      onLess: () =>
                          setState(() => _visible = movementPageSize),
                    ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: VendorPrimaryButton(
              label: sending ? 'Enviando…' : 'Déjame pan',
              icon: Icons.bakery_dining,
              busy: sending,
              size: VendorControlSize.compact,
              onPressed: sending
                  ? null
                  : () => context.read<BuyerViewModel>().requestPan(ledger),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final Movement movement;

  @override
  Widget build(BuildContext context) {
    final title =
        '${movement.kind.spokenLabel} S/ ${formatSoles(movement.amountCents)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            movement.voided ? '$title (anulado)' : title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: VendorLook.ink,
              decoration: movement.voided ? TextDecoration.lineThrough : null,
            ),
          ),
          Text(spokenStamp(movement.occurredAt), style: BuyerLook.body),
        ],
      ),
    );
  }
}

String _totalLine(int balance) {
  if (balance > 0) return 'Debes S/ ${formatSoles(balance)} en total';
  if (balance < 0) return 'A favor S/ ${formatSoles(-balance)}';
  return 'No debes nada';
}

String _debtLine(int balance) {
  if (balance > 0) return 'Debes S/ ${formatSoles(balance)}';
  if (balance < 0) return 'A favor S/ ${formatSoles(-balance)}';
  return 'No debes nada';
}
