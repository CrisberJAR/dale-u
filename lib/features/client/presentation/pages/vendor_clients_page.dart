import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/client/domain/client_roster.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/presentation/pages/add_client_page.dart';
import 'package:dale_u/features/client/presentation/pages/client_detail_page.dart';
import 'package:dale_u/features/client/presentation/pages/vendor_home_page.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:dale_u/features/voice/presentation/pages/voice_commands_page.dart';
import 'package:dale_u/features/voice/presentation/viewmodels/voice_capture_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Solo la lista: buscador, filtros y clientes a pantalla completa.
class VendorClientsPage extends StatelessWidget {
  const VendorClientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final clientViewModel = context.watch<ClientViewModel>();
    final voice = context.watch<VoiceCaptureViewModel>();

    return Theme(
      data: VendorLook.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: VendorLook.background,
        appBar: AppBar(
          backgroundColor: VendorLook.background,
          foregroundColor: VendorLook.ink,
          title: Text('Mis clientes', style: VendorLook.title),
          actions: [
            IconButton(
              tooltip: 'Qué puedo decir',
              icon: Icon(Icons.help_outline, size: 24),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const VoiceCommandsPage(),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ClientSearchField(viewModel: clientViewModel),
                const SizedBox(height: 10),
                _RosterFilters(viewModel: clientViewModel),
                if (voice.isListening) ...[
                  const SizedBox(height: 10),
                  MicHearingBar(strength: voice.hearingStrength),
                ],
                if (voice.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    voice.errorMessage!,
                    textAlign: TextAlign.center,
                    style: VendorLook.dangerText,
                  ),
                ],
                const SizedBox(height: 10),
                Expanded(child: _ClientList(viewModel: clientViewModel)),
                const SizedBox(height: 12),
                VendorPrimaryButton(
                  label: 'Nuevo cliente',
                  icon: Icons.person_add,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AddClientPage(),
                      ),
                    );
                  },
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

class _ClientSearchField extends StatefulWidget {
  const _ClientSearchField({required this.viewModel});

  final ClientViewModel viewModel;

  @override
  State<_ClientSearchField> createState() => _ClientSearchFieldState();
}

class _ClientSearchFieldState extends State<_ClientSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.viewModel.searchQuery);
    widget.viewModel.addListener(_syncFromViewModel);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_syncFromViewModel);
    _controller.dispose();
    super.dispose();
  }

  void _syncFromViewModel() {
    final query = widget.viewModel.searchQuery;
    if (_controller.text == query) return;
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.viewModel.setSearchQuery,
      textInputAction: TextInputAction.search,
      style: VendorLook.subtitle,
      cursorColor: VendorLook.ink,
      decoration: InputDecoration(
        hintText: 'Buscar por nombre',
        hintStyle: VendorLook.body,
        filled: true,
        fillColor: VendorLook.surface,
        prefixIcon: Icon(
          Icons.search,
          size: 28,
          color: VendorLook.ink,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.viewModel.searchQuery.isNotEmpty)
              IconButton(
                tooltip: 'Borrar búsqueda',
                onPressed: () {
                  widget.viewModel.setSearchQuery('');
                  _controller.clear();
                },
                icon: Icon(
                  Icons.close,
                  size: 28,
                  color: VendorLook.ink,
                ),
              ),
            // El micrófono vive aquí: buscar hablando es lo natural.
            IconButton(
              tooltip: 'Buscar hablando',
              onPressed: context.read<VoiceCaptureViewModel>().toggle,
              icon: Icon(
                context.watch<VoiceCaptureViewModel>().isListening
                    ? Icons.stop
                    : Icons.mic,
                size: 28,
                color: VendorLook.ink,
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VendorLook.radius),
          borderSide: VendorLook.cardBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VendorLook.radius),
          borderSide: VendorLook.thickBorder,
        ),
      ),
    );
  }
}

class _RosterFilters extends StatelessWidget {
  const _RosterFilters({required this.viewModel});

  final ClientViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RosterChip(
            label: 'Todos',
            selected: viewModel.rosterFilter == ClientRosterFilter.all,
            onTap: () => viewModel.setRosterFilter(ClientRosterFilter.all),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RosterChip(
            label: 'Con deuda',
            selected: viewModel.rosterFilter == ClientRosterFilter.withDebt,
            onTap: () =>
                viewModel.setRosterFilter(ClientRosterFilter.withDebt),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RosterChip(
            label: 'Al día',
            selected: viewModel.rosterFilter == ClientRosterFilter.settled,
            onTap: () => viewModel.setRosterFilter(ClientRosterFilter.settled),
          ),
        ),
      ],
    );
  }
}

class _RosterChip extends StatelessWidget {
  const _RosterChip({
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
      height: VendorLook.compactButtonHeight,
      child: Material(
        color: selected ? VendorLook.ink : VendorLook.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VendorLook.radius),
          side: VendorLook.cardBorder,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VendorLook.radius),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected ? VendorLook.onAccent : VendorLook.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientList extends StatelessWidget {
  const _ClientList({required this.viewModel});

  final ClientViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.loading && viewModel.clients.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: VendorLook.ink),
      );
    }
    if (viewModel.clients.isEmpty) {
      return Center(
        child: Text(
          'Aún no hay clientes.\nDi: nuevo cliente María.',
          textAlign: TextAlign.center,
          style: VendorLook.body,
        ),
      );
    }
    final visible = viewModel.visibleClients;
    if (visible.isEmpty) {
      return Center(
        child: Text(
          'Nadie coincide con esa búsqueda o filtro.',
          textAlign: TextAlign.center,
          style: VendorLook.body,
        ),
      );
    }
    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final client = visible[index];
        return Material(
          color: VendorLook.surface,
          elevation: VendorLook.cardElevation,
          shadowColor: VendorLook.shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VendorLook.radius),
            side: VendorLook.cardBorder,
          ),
          child: ListTile(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ClientDetailPage(clientId: client.id),
                ),
              );
            },
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            title: Text(
              client.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: VendorLook.ink,
              ),
            ),
            subtitle: _clientSubtitle(viewModel, client),
            trailing: Icon(
              Icons.chevron_right,
              size: 28,
              color: VendorLook.muted,
            ),
          ),
        );
      },
    );
  }
}

/// Primero lo que importa (cuánto debe); el teléfono después, apagado.
Widget? _clientSubtitle(ClientViewModel viewModel, Client client) {
  final phone = client.phone;
  final balance = viewModel.balanceCents(client.id);
  final debt = _debtLine(balance);
  if (phone.isEmpty && debt == null) return null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (debt != null)
        Text(
          debt,
          style: VendorLook.body.copyWith(
            fontWeight: FontWeight.w800,
            color: balance < 0 ? VendorLook.paid : VendorLook.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      if (phone.isNotEmpty) Text(phone, style: VendorLook.body),
    ],
  );
}

String? _debtLine(int balance) {
  if (balance > 0) return 'Debe S/ ${formatSoles(balance)}';
  if (balance < 0) return 'A favor S/ ${formatSoles(-balance)}';
  return null;
}
