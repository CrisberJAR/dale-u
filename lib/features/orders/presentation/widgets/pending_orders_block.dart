import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/orders/domain/entities/pan_order.dart';
import 'package:dale_u/features/orders/presentation/viewmodels/order_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _previewLimit = 3;

class PendingOrdersBlock extends StatelessWidget {
  const PendingOrdersBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderViewModel>();
    final preview = orders.pending.take(_previewLimit).toList();
    final extra = orders.pending.length - preview.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview.isNotEmpty) ...[
          Text(
            'Recordatorios',
            textAlign: TextAlign.center,
            style: VendorLook.subtitle,
          ),
          const SizedBox(height: 6),
          for (final order in preview) ...[
            _OrderRow(order: order),
            const SizedBox(height: 6),
          ],
          if (extra > 0)
            VendorTextAction(
              label: extra == 1 ? 'Ver 1 más' : 'Ver $extra más',
              onPressed: () => showAllOrdersSheet(context),
            ),
        ],
        VendorSecondaryButton(
          label: 'Anotar pedido',
          size: VendorControlSize.compact,
          onPressed: () => showAddOrderSheet(context),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final PanOrder order;

  @override
  Widget build(BuildContext context) {
    return VendorSurface(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.label,
                  style: VendorLook.subtitle.copyWith(fontSize: 15),
                ),
                Text(
                  'para el ${order.spokenDay}',
                  style: VendorLook.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.read<OrderViewModel>().complete(order.id),
            style: FilledButton.styleFrom(
              backgroundColor: VendorLook.accent,
              foregroundColor: VendorLook.onAccent,
              minimumSize: const Size(72, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VendorLook.buttonRadius),
              ),
            ),
            child: Text(
              'Listo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: VendorLook.onAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showAllOrdersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VendorLook.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Consumer<OrderViewModel>(
            builder: (context, orders, _) {
              return Column(
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
                    'Recordatorios',
                    textAlign: TextAlign.center,
                    style: VendorLook.subtitle,
                  ),
                  const SizedBox(height: 12),
                  if (orders.pending.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No hay pedidos pendientes.',
                        textAlign: TextAlign.center,
                        style: VendorLook.body,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: orders.pending.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          return _OrderRow(order: orders.pending[index]);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

Future<void> showAddOrderSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VendorLook.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: const _AddOrderSheet(),
      );
    },
  );
}

class _AddOrderSheet extends StatefulWidget {
  const _AddOrderSheet();

  @override
  State<_AddOrderSheet> createState() => _AddOrderSheetState();
}

class _AddOrderSheetState extends State<_AddOrderSheet> {
  late int _dateKey;
  final _label = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dateKey = peruTomorrowDateKey();
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final peru = toPeru(DateTime.now());
    final first = DateTime(peru.year, peru.month, peru.day);
    final initial = DateTime(
      _yearOf(_dateKey),
      _monthOf(_dateKey),
      _dayOf(_dateKey),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 90)),
      helpText: 'Día de entrega',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateKey = peruDateKeyFromYmd(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save() async {
    final ok = await context.read<OrderViewModel>().add(
      label: _label.text,
      deliveryDateKey: _dateKey,
    );
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderViewModel>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
              'Recordatorio',
              textAlign: TextAlign.center,
              style: VendorLook.subtitle,
            ),
            const SizedBox(height: 8),
            Text(
              'Para alguien que no está en la ruta. Solo el día y qué te pidieron.',
              textAlign: TextAlign.center,
              style: VendorLook.body,
            ),
            const SizedBox(height: 12),
            VendorSecondaryButton(
              label: 'Para el ${peruDateKeyLabel(_dateKey)}',
              size: VendorControlSize.compact,
              onPressed: _pickDate,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _label,
              maxLength: 80,
              style: VendorLook.subtitle,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Qué te pidieron',
                hintText: 'Ej. la vecina de la esquina, 2 bolsas',
                labelStyle: VendorLook.body,
                hintStyle: VendorLook.body,
                counterStyle: VendorLook.body,
              ),
            ),
            if (orders.errorMessage != null) ...[
              Text(orders.errorMessage!, style: VendorLook.dangerText),
              const SizedBox(height: 8),
            ],
            VendorPrimaryButton(
              label: 'Guardar',
              busy: orders.saving,
              size: VendorControlSize.compact,
              onPressed: orders.saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

int _yearOf(int key) => key ~/ 10000;
int _monthOf(int key) => (key ~/ 100) % 100;
int _dayOf(int key) => key % 100;
