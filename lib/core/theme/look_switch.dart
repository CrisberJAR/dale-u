import 'package:dale_u/core/theme/look_view_model.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Cambia entre el look cálido y el original.
class LookSwitchAction extends StatelessWidget {
  const LookSwitchAction({super.key});

  @override
  Widget build(BuildContext context) {
    final look = context.watch<LookViewModel>();
    return VendorTextAction(
      label: look.switchLabel,
      onPressed: look.toggle,
    );
  }
}
