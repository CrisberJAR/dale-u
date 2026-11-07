import 'package:dale_u/core/theme/look_switch.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();
    final isLoading = viewModel.status == AuthStatus.loading;

    return Theme(
      data: VendorLook.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: VendorLook.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(),
                Icon(Icons.bakery_dining, size: 88, color: VendorLook.accent),
                const SizedBox(height: 20),
                Text(
                  'Dale U',
                  textAlign: TextAlign.center,
                  style: VendorLook.title.copyWith(fontSize: 36),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ruta de pan',
                  textAlign: TextAlign.center,
                  style: VendorLook.subtitle,
                ),
                const Spacer(),
                if (viewModel.errorMessage != null) ...[
                  Text(
                    viewModel.errorMessage!,
                    textAlign: TextAlign.center,
                    style: VendorLook.dangerText,
                  ),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton(
                    onPressed: isLoading ? null : viewModel.signIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: VendorLook.accent,
                      disabledBackgroundColor: VendorLook.disabledAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          VendorLook.buttonRadius,
                        ),
                        side: VendorLook.buttonSide,
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              color: VendorLook.onAccent,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            'Entrar con Google',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: VendorLook.onAccent,
                            ),
                          ),
                  ),
                ),
                const LookSwitchAction(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
