import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:flutter/material.dart';

/// Cuántos movimientos se ven de golpe. Con más, la lista cansa la vista.
const int movementPageSize = 5;

/// Cuántos mostrar tras pulsar "ver más", sin pasarse del total.
int nextMovementCount(int visible, int total) {
  final next = visible + movementPageSize;
  return next > total ? total : next;
}

/// Pie de la lista de movimientos: cuántos se ven y cómo ver el resto.
class MovementsShowMore extends StatelessWidget {
  const MovementsShowMore({
    super.key,
    required this.total,
    required this.visible,
    required this.onMore,
    required this.onLess,
  });

  final int total;
  final int visible;
  final VoidCallback onMore;
  final VoidCallback onLess;

  @override
  Widget build(BuildContext context) {
    final remaining = total - visible;
    final step = remaining < movementPageSize ? remaining : movementPageSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Text(
          'Mostrando $visible de $total',
          textAlign: TextAlign.center,
          style: VendorLook.body,
        ),
        const SizedBox(height: 8),
        if (remaining > 0)
          VendorSecondaryButton(
            label: step == 1 ? 'Ver 1 más' : 'Ver $step más',
            onPressed: onMore,
          ),
        if (visible > movementPageSize)
          VendorTextAction(label: 'Ver menos', onPressed: onLess),
      ],
    );
  }
}
