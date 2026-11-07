import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/ledger/presentation/widgets/movement_kind_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class EditMovementPage extends StatefulWidget {
  const EditMovementPage({super.key, required this.movement});

  final Movement movement;

  @override
  State<EditMovementPage> createState() => _EditMovementPageState();
}

class _EditMovementPageState extends State<EditMovementPage> {
  late MovementKind _kind;
  late DateTime _occurredAt;
  late final TextEditingController _amountController;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _kind = widget.movement.kind;
    _occurredAt = widget.movement.occurredAt;
    _amountController = TextEditingController(
      text: formatSoles(widget.movement.amountCents),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final peru = toPeru(_occurredAt);
    final now = peruNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(peru.year, peru.month, peru.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1)),
      helpText: 'Fecha en hora de Perú',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (picked == null) return;
    setState(() {
      _occurredAt = fromPeruWallClock(
        DateTime(picked.year, picked.month, picked.day, peru.hour, peru.minute),
      );
    });
  }

  Future<void> _pickTime() async {
    final peru = toPeru(_occurredAt);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: peru.hour, minute: peru.minute),
      helpText: 'Hora de Perú',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _occurredAt = fromPeruWallClock(
        DateTime(peru.year, peru.month, peru.day, picked.hour, picked.minute),
      );
    });
  }

  Future<void> _save() async {
    final parsed = InputSanitizer.centimos(
      parseSolesText(_amountController.text),
    );
    if (parsed == null) {
      setState(() {
        _formError = 'Escribe un monto válido en soles, por ejemplo 1.50.';
      });
      return;
    }
    setState(() => _formError = null);
    final viewModel = context.read<ClientViewModel>();
    final ok = await viewModel.updateOpenMovement(
      movementId: widget.movement.id,
      kind: _kind,
      amountCents: parsed,
      occurredAt: _occurredAt,
    );
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _confirmVoid() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: VendorLook.surface,
          title: Text(
            '¿Anular este movimiento?',
            style: VendorLook.subtitle,
          ),
          content: Text(
            'Ya no cuenta para la deuda. Queda marcado como anulado por si lo necesitas ver.',
            style: VendorLook.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: VendorLook.subtitle),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Anular', style: VendorLook.dangerText),
            ),
          ],
        );
      },
    );
    if (go != true || !mounted) return;
    final ok = await context.read<ClientViewModel>().voidOpenMovement(
      widget.movement.id,
    );
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClientViewModel>();

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
                  'Corregir movimiento',
                  textAlign: TextAlign.center,
                  style: VendorLook.title,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      Text('Tipo', style: VendorLook.subtitle),
                      const SizedBox(height: 8),
                      MovementKindChips(
                        value: _kind,
                        onChanged: (kind) => setState(() => _kind = kind),
                      ),
                      const SizedBox(height: 16),
                      Text('Monto en soles', style: VendorLook.subtitle),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                        ],
                        style: TextStyle(
                          fontSize: 20,
                          color: VendorLook.ink,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _boxDecoration('Ej. 1.50'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Fecha y hora (Perú)',
                        style: VendorLook.subtitle,
                      ),
                      const SizedBox(height: 8),
                      VendorSecondaryButton(
                        label: 'Fecha ${peruDateLabel(_occurredAt)}',
                        onPressed: _pickDate,
                      ),
                      const SizedBox(height: 8),
                      VendorSecondaryButton(
                        label: 'Hora ${peruTimeLabel(_occurredAt)}',
                        onPressed: _pickTime,
                      ),
                      if (_formError != null ||
                          viewModel.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _formError ?? viewModel.errorMessage!,
                          textAlign: TextAlign.center,
                          style: VendorLook.dangerText,
                        ),
                      ],
                    ],
                  ),
                ),
                VendorPrimaryButton(
                  label: 'Guardar',
                  busy: viewModel.saving,
                  onPressed: viewModel.saving ? null : _save,
                ),
                VendorDangerButton(
                  label: 'Anular movimiento',
                  onPressed: viewModel.saving ? null : _confirmVoid,
                ),
                VendorTextAction(
                  label: 'Cancelar',
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

  InputDecoration _boxDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF4A4A4A), fontSize: 18),
      filled: true,
      fillColor: VendorLook.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VendorLook.radius),
        borderSide: VendorLook.cardBorder,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VendorLook.radius),
        borderSide: VendorLook.thickBorder,
      ),
    );
  }
}
