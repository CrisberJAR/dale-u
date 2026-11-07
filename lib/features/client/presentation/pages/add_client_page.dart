import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddClientPage extends StatefulWidget {
  const AddClientPage({super.key, this.existing});

  final Client? existing;

  @override
  State<AddClientPage> createState() => _AddClientPageState();
}

class _AddClientPageState extends State<AddClientPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _phoneController = TextEditingController(text: widget.existing?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final viewModel = context.read<ClientViewModel>();
    final ok = _isEdit
        ? await viewModel.updateClient(
            id: widget.existing!.id,
            name: _nameController.text,
            phone: _phoneController.text,
          )
        : await viewModel.addClient(
            name: _nameController.text,
            phone: _phoneController.text,
          );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    }
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
                  _isEdit ? 'Editar cliente' : 'Nuevo cliente',
                  textAlign: TextAlign.center,
                  style: VendorLook.title,
                ),
                const SizedBox(height: 24),
                Text('Nombre', style: VendorLook.subtitle),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    fontSize: 20,
                    color: VendorLook.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _fieldDecoration('Ej. Doña María'),
                ),
                const SizedBox(height: 16),
                Text('Teléfono (opcional)', style: VendorLook.subtitle),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    fontSize: 20,
                    color: VendorLook.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _fieldDecoration('Ej. 300 123 4567'),
                ),
                if (viewModel.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    viewModel.errorMessage!,
                    textAlign: TextAlign.center,
                    style: VendorLook.dangerText,
                  ),
                ],
                const Spacer(),
                VendorPrimaryButton(
                  label: 'Guardar',
                  busy: viewModel.saving,
                  onPressed: viewModel.saving ? null : _save,
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

  InputDecoration _fieldDecoration(String hint) {
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
