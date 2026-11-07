import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/ledger/presentation/viewmodels/daily_close_view_model.dart';
import 'package:dale_u/features/ledger/presentation/widgets/movements_show_more.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DailyClosePage extends StatefulWidget {
  const DailyClosePage({super.key});

  @override
  State<DailyClosePage> createState() => _DailyClosePageState();
}

class _DailyClosePageState extends State<DailyClosePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DailyCloseViewModel>().refresh();
    });
  }

  Future<void> _pickDate() async {
    final viewModel = context.read<DailyCloseViewModel>();
    final current = fromPeruDateKey(viewModel.dateKey);
    final peru = toPeru(current);
    final now = peruNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(peru.year, peru.month, peru.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Día en hora de Perú',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (picked == null || !mounted) return;
    await viewModel.load(peruDateKeyFromYmd(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DailyCloseViewModel>();
    final clients = context.watch<ClientViewModel>();
    final close = viewModel.close;
    final names = {
      for (final client in clients.clients) client.id: client.name,
    };

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
                  'Cuadre del día',
                  textAlign: TextAlign.center,
                  style: VendorLook.title,
                ),
                const SizedBox(height: 8),
                VendorSecondaryButton(
                  label: peruDateKeyLabel(viewModel.dateKey),
                  onPressed: _pickDate,
                ),
                const SizedBox(height: 12),
                _TotalsCard(
                  title: 'Fiados',
                  count: close.fiadoCount,
                  cents: close.fiadoCents,
                ),
                const SizedBox(height: 8),
                _TotalsCard(
                  title: 'Pagos',
                  count: close.pagoCount,
                  cents: close.pagoCents,
                ),
                if (viewModel.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    viewModel.errorMessage!,
                    textAlign: TextAlign.center,
                    style: VendorLook.dangerText,
                  ),
                ],
                const SizedBox(height: 12),
                Text('Movimientos', style: VendorLook.subtitle),
                const SizedBox(height: 8),
                Expanded(
                  child: viewModel.loading && close.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(color: VendorLook.ink),
                        )
                      : _DayList(
                          movements: close.movements,
                          names: names,
                        ),
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

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.title,
    required this.count,
    required this.cents,
  });

  final String title;
  final int count;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final howMany = count == 1 ? '1 movimiento' : '$count movimientos';
    return VendorSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: VendorLook.subtitle),
                Text(howMany, style: VendorLook.body),
              ],
            ),
          ),
          Text(
            'S/ ${formatSoles(cents)}',
            style: VendorLook.title,
          ),
        ],
      ),
    );
  }
}

class _DayList extends StatefulWidget {
  const _DayList({required this.movements, required this.names});

  final List<Movement> movements;
  final Map<String, String> names;

  @override
  State<_DayList> createState() => _DayListState();
}

class _DayListState extends State<_DayList> {
  int _visible = movementPageSize;

  @override
  void didUpdateWidget(_DayList oldWidget) {
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
          'Ese día no hay fiados ni pagos.',
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
        final name = widget.names[movement.clientId] ?? 'Cliente';
        final kind = movement.kind == MovementKind.fiado ? 'Fiado' : 'Pago';
        return VendorSurface(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              '$kind S/ ${formatSoles(movement.amountCents)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: VendorLook.ink,
              ),
            ),
            subtitle: Text(
              '$name · ${peruTimeLabel(movement.occurredAt)}',
              style: VendorLook.body,
            ),
          ),
        );
      },
    );
  }
}
