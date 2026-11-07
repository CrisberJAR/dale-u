import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:flutter/material.dart';

class MovementKindChips extends StatelessWidget {
  const MovementKindChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MovementKind value;
  final ValueChanged<MovementKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KindChip(
            label: 'Fiado',
            selected: value == MovementKind.fiado,
            onTap: () => onChanged(MovementKind.fiado),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KindChip(
            label: 'Pago',
            selected: value == MovementKind.pago,
            onTap: () => onChanged(MovementKind.pago),
          ),
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: VendorLook.buttonHeight,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? VendorLook.ink : VendorLook.surface,
          foregroundColor: selected ? VendorLook.onAccent : VendorLook.ink,
          side: VendorLook.thickBorder,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VendorLook.radius),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: selected ? VendorLook.onAccent : VendorLook.ink,
          ),
        ),
      ),
    );
  }
}
