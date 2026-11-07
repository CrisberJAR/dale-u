import 'package:dale_u/core/splash/eating_bread.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/auth/presentation/pages/login_page.dart';
import 'package:dale_u/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:dale_u/features/buyer/presentation/pages/buyer_home_page.dart';
import 'package:dale_u/features/client/presentation/pages/vendor_home_page.dart';
import 'package:dale_u/features/role/presentation/viewmodels/role_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final roleViewModel = context.watch<RoleViewModel>();
    final authStatus = context.watch<AuthViewModel>().status;
    final roleStatus = roleViewModel.status;

    if (authStatus == AuthStatus.unknown ||
        (authStatus == AuthStatus.authenticated &&
            roleStatus == RoleStatus.unknown)) {
      return const _Splash();
    }

    return switch (authStatus) {
      AuthStatus.unauthenticated || AuthStatus.loading => const LoginPage(),
      AuthStatus.authenticated => switch (roleStatus) {
        // El rol lo trae la nube: nadie elige ser vendedor desde el teléfono.
        RoleStatus.ready => roleViewModel.canSell
            ? const VendorHomePage()
            : const BuyerHomePage(),
        RoleStatus.failed => const _AccountProblem(),
        RoleStatus.none || RoleStatus.unknown => const _Splash(),
      },
      AuthStatus.unknown => const _Splash(),
    };
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: splashCream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EatingBread(size: 140),
            SizedBox(height: 24),
            Text(
              'Preparando la ruta…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: splashCrust,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La cuenta vive en la nube. Sin ella no sabemos qué pantalla abrir.
class _AccountProblem extends StatelessWidget {
  const _AccountProblem();

  @override
  Widget build(BuildContext context) {
    final roleViewModel = context.watch<RoleViewModel>();

    return Theme(
      data: VendorLook.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: VendorLook.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'No pudimos abrir tu cuenta',
                  textAlign: TextAlign.center,
                  style: VendorLook.title,
                ),
                const SizedBox(height: 12),
                Text(
                  roleViewModel.errorMessage ?? 'Revisa la señal e inténtalo.',
                  textAlign: TextAlign.center,
                  style: VendorLook.body,
                ),
                const SizedBox(height: 24),
                VendorPrimaryButton(
                  label: 'Reintentar',
                  onPressed: roleViewModel.retry,
                ),
                const SizedBox(height: 12),
                VendorSecondaryButton(
                  label: 'Cerrar sesión',
                  onPressed: context.read<AuthViewModel>().signOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
