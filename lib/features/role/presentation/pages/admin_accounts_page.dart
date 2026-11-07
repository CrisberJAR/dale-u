import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/role/domain/entities/account_profile.dart';
import 'package:dale_u/features/role/domain/entities/user_role.dart';
import 'package:dale_u/features/role/presentation/viewmodels/admin_accounts_view_model.dart';
import 'package:dale_u/features/role/presentation/viewmodels/role_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Panel del administrador: aquí se nombra a los vendedores y a otros admins.
class AdminAccountsPage extends StatefulWidget {
  const AdminAccountsPage({super.key});

  @override
  State<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<AdminAccountsPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminAccountsViewModel>().refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminAccountsViewModel>();
    final myUid = context.watch<RoleViewModel>().uid;

    return Theme(
      data: VendorLook.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: VendorLook.background,
        appBar: AppBar(
          backgroundColor: VendorLook.background,
          foregroundColor: VendorLook.ink,
          title: Text('Cuentas', style: VendorLook.title),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              iconSize: 28,
              onPressed: viewModel.isLoading ? null : viewModel.refresh,
              icon: Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Quien entra por primera vez queda como cliente. Aquí lo subes a vendedor.',
                  style: VendorLook.body,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: viewModel.setQuery,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: VendorLook.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o correo',
                    hintStyle: VendorLook.body,
                    prefixIcon: Icon(Icons.search, color: VendorLook.ink),
                    filled: true,
                    fillColor: VendorLook.surface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VendorLook.radius),
                      borderSide: BorderSide(
                        color: VendorLook.border,
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VendorLook.radius),
                      borderSide: BorderSide(
                        color: VendorLook.border,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
                if (viewModel.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(viewModel.errorMessage!, style: VendorLook.dangerText),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: _AccountList(viewModel: viewModel, myUid: myUid),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList({required this.viewModel, required this.myUid});

  final AdminAccountsViewModel viewModel;
  final String? myUid;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading && viewModel.visibleAccounts.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: VendorLook.ink),
      );
    }

    final accounts = viewModel.visibleAccounts;
    if (accounts.isEmpty) {
      return Center(
        child: Text(
          'No hay cuentas para mostrar.',
          textAlign: TextAlign.center,
          style: VendorLook.body,
        ),
      );
    }

    return ListView.separated(
      itemCount: accounts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final account = accounts[index];
        return _AccountTile(
          account: account,
          isMe: account.uid == myUid,
          onTap: () => _openRolePicker(context, account),
        );
      },
    );
  }

  Future<void> _openRolePicker(
    BuildContext context,
    AccountProfile account,
  ) async {
    final picked = await showModalBottomSheet<UserRole>(
      context: context,
      backgroundColor: VendorLook.background,
      builder: (sheetContext) => _RolePicker(account: account),
    );
    if (picked == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final result = await viewModel.changeRole(account: account, role: picked);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.message,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isMe,
    required this.onTap,
  });

  final AccountProfile account;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = account.email.isEmpty ? account.uid : account.email;
    return Material(
      color: VendorLook.surface,
      elevation: VendorLook.cardElevation,
      shadowColor: VendorLook.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VendorLook.radius),
        side: VendorLook.cardBorder,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        // Un admin no cambia su propio rol: evita quedarse sin administrador.
        onTap: isMe ? null : onTap,
        title: Text(
          isMe ? '${account.displayName} (tú)' : account.displayName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: VendorLook.ink,
          ),
        ),
        subtitle: Text(subtitle, style: VendorLook.body),
        trailing: Text(
          account.role.label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: VendorLook.ink,
          ),
        ),
      ),
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.account});

  final AccountProfile account;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(account.displayName, style: VendorLook.title),
            const SizedBox(height: 4),
            Text('Hoy es ${account.role.label}', style: VendorLook.body),
            const SizedBox(height: 16),
            for (final role in UserRole.values) ...[
              VendorSecondaryButton(
                label: role.label,
                onPressed: () => Navigator.of(context).pop(role),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
