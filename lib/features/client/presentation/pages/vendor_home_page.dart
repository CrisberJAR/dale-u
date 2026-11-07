import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/core/theme/look_view_model.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:dale_u/features/client/presentation/pages/add_client_page.dart';
import 'package:dale_u/features/client/presentation/pages/vendor_clients_page.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:dale_u/features/inbox/presentation/pages/vendor_inbox_sheet.dart';
import 'package:dale_u/features/inbox/presentation/viewmodels/vendor_inbox_view_model.dart';
import 'package:dale_u/features/ledger/presentation/pages/daily_close_page.dart';
import 'package:dale_u/features/notice/presentation/pages/send_notice_page.dart';
import 'package:dale_u/features/orders/presentation/widgets/pending_orders_block.dart';
import 'package:dale_u/features/presence/presentation/viewmodels/presence_view_model.dart';
import 'package:dale_u/features/role/presentation/pages/admin_accounts_page.dart';
import 'package:dale_u/features/role/presentation/viewmodels/role_view_model.dart';
import 'package:dale_u/features/voice/presentation/pages/voice_commands_page.dart';
import 'package:dale_u/features/voice/presentation/viewmodels/voice_capture_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// La casa del vendedor: hablar es lo principal. La lista es un destino.
class VendorHomePage extends StatefulWidget {
  const VendorHomePage({super.key});

  @override
  State<VendorHomePage> createState() => _VendorHomePageState();
}

class _VendorHomePageState extends State<VendorHomePage> {
  late final ClientViewModel _clients;
  late final VendorInboxViewModel _inbox;
  int _lastSearchRequest = 0;

  @override
  void initState() {
    super.initState();
    _clients = context.read<ClientViewModel>();
    _inbox = context.read<VendorInboxViewModel>();
    _lastSearchRequest = _clients.searchRequests;
    _clients.addListener(_onClientsChanged);
    _inbox.addListener(_onInbox);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onInbox();
    });
  }

  @override
  void dispose() {
    _clients.removeListener(_onClientsChanged);
    _inbox.removeListener(_onInbox);
    super.dispose();
  }

  void _onInbox() {
    final spoken = _inbox.freshSpoken;
    if (spoken == null) return;
    _inbox.clearSpoken();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VoiceCaptureViewModel>().say(spoken);
    });
  }

  /// "Buscar María" desde aquí abre la lista ya filtrada.
  void _onClientsChanged() {
    if (_clients.searchRequests == _lastSearchRequest) return;
    _lastSearchRequest = _clients.searchRequests;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      _openClients();
    });
  }

  void _openClients() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const VendorClientsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = context.watch<ClientViewModel>();
    final session = context.watch<AuthViewModel>().session;

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
                _VendorHeader(
                  name: session?.displayName ?? 'Vendedor',
                  clients: clients,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _VoiceConsole(),
                          VendorTextAction(
                            label: '¿Qué puedo decir?',
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
                    ),
                  ),
                ),
                const _RouteToggle(),
                const SizedBox(height: 8),
                const PendingOrdersBlock(),
                _ClientsButton(clients: clients, onPressed: _openClients),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: VendorSecondaryButton(
                        label: 'Cuadre del día',
                        size: VendorControlSize.compact,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const DailyClosePage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: VendorSecondaryButton(
                        label: 'Avisar',
                        size: VendorControlSize.compact,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SendNoticePage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VendorHeader extends StatelessWidget {
  const _VendorHeader({required this.name, required this.clients});

  final String name;
  final ClientViewModel clients;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text('Mi ruta', style: VendorLook.title),
              const Align(
                alignment: Alignment.centerLeft,
                child: _InboxButton(),
              ),
              const Align(
                alignment: Alignment.centerRight,
                child: _VendorMenu(),
              ),
            ],
          ),
        ),
        Text(name, textAlign: TextAlign.center, style: VendorLook.body),
        if (clients.pendingSyncCount > 0 || clients.clients.isEmpty) ...[
          const SizedBox(height: 2),
          Text(
            _syncLine(clients),
            textAlign: TextAlign.center,
            style: VendorLook.body,
          ),
        ],
        if (clients.syncError != null) ...[
          const SizedBox(height: 4),
          Text(
            clients.syncError!,
            textAlign: TextAlign.center,
            style: VendorLook.dangerText,
          ),
          VendorTextAction(
            label: 'Reintentar subida',
            onPressed: clients.refresh,
          ),
        ],
      ],
    );
  }
}

class _InboxButton extends StatelessWidget {
  const _InboxButton();

  @override
  Widget build(BuildContext context) {
    final count = context.watch<VendorInboxViewModel>().unread.length;
    return IconButton(
      tooltip: 'Pedidos de pan',
      padding: EdgeInsets.zero,
      onPressed: () => showVendorInboxSheet(context),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: VendorLook.danger,
        textColor: VendorLook.onAccent,
        child: Icon(
          count > 0 ? Icons.notifications : Icons.notifications_outlined,
          size: 24,
          color: VendorLook.ink,
        ),
      ),
    );
  }
}

class _RouteToggle extends StatelessWidget {
  const _RouteToggle();

  @override
  Widget build(BuildContext context) {
    final presence = context.watch<PresenceViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (presence.onRoute)
          VendorSecondaryButton(
            label: presence.busy ? 'Saliendo…' : 'Salir de la ruta',
            onPressed: presence.busy ? null : presence.toggle,
          )
        else
          VendorPrimaryButton(
            label: presence.busy ? 'Entrando…' : 'Estoy en ruta',
            icon: Icons.route,
            busy: presence.busy,
            tone: VendorButtonTone.route,
            onPressed: presence.busy ? null : presence.toggle,
          ),
        if (presence.onRoute) ...[
          const SizedBox(height: 6),
          Text(
            _routeLine(presence),
            textAlign: TextAlign.center,
            style: VendorLook.body,
          ),
          const SizedBox(height: 4),
          Text(
            'Avisaré si te acercas a un deudor con casa marcada.',
            textAlign: TextAlign.center,
            style: VendorLook.body,
          ),
        ],
        if (presence.errorMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            presence.errorMessage!,
            textAlign: TextAlign.center,
            style: VendorLook.dangerText,
          ),
          if (presence.onRoute)
            VendorTextAction(
              label: 'Reintentar ubicación',
              onPressed: presence.retryPublish,
            ),
        ],
      ],
    );
  }

  static String _routeLine(PresenceViewModel presence) {
    final at = presence.lastPublishedAt;
    if (at == null) {
      return presence.locating
          ? 'Buscando tu ubicación…'
          : 'Aún no pude subir tu ubicación';
    }
    final minutes = DateTime.now().difference(at).inMinutes;
    if (minutes < 1) return 'Ubicación recién subida';
    if (minutes == 1) return 'Última ubicación hace 1 minuto';
    return 'Última ubicación hace $minutes minutos';
  }
}

String _syncLine(ClientViewModel clients) {
  if (clients.pendingSyncCount > 0) {
    return 'Guardado en el teléfono. Subiendo a la nube…';
  }
  if (clients.clients.isEmpty) {
    return 'Los clientes se guardan aunque no haya señal';
  }
  return 'Sincronizado con la nube';
}

/// Se usa una vez al mes: no compite con Hablar.
class _VendorMenu extends StatelessWidget {
  const _VendorMenu();

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<RoleViewModel>().isAdmin;
    final look = context.watch<LookViewModel>();

    return PopupMenuButton<String>(
      tooltip: 'Más opciones',
      padding: EdgeInsets.zero,
      icon: Icon(Icons.settings, size: 24, color: VendorLook.ink),
      color: VendorLook.surface,
      onSelected: (value) {
        switch (value) {
          case 'accounts':
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminAccountsPage(),
              ),
            );
          case 'look':
            look.toggle();
          case 'signOut':
            context.read<AuthViewModel>().signOut();
        }
      },
      itemBuilder: (context) => [
        if (isAdmin)
          PopupMenuItem<String>(
            value: 'accounts',
            child: Text('Cuentas y vendedores', style: VendorLook.subtitle),
          ),
        PopupMenuItem<String>(
          value: 'look',
          child: Text(look.switchLabel, style: VendorLook.subtitle),
        ),
        PopupMenuItem<String>(
          value: 'signOut',
          child: Text('Cerrar sesión', style: VendorLook.subtitle),
        ),
      ],
    );
  }
}

/// Botón grande con el dato que antes daba la lista de un vistazo.
class _ClientsButton extends StatelessWidget {
  const _ClientsButton({required this.clients, required this.onPressed});

  final ClientViewModel clients;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return VendorSurface(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(VendorLook.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.groups, size: 24, color: VendorLook.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mis clientes',
                      style: TextStyle(
                        fontSize: VendorLook.buttonLabelSize,
                        fontWeight: FontWeight.w800,
                        color: VendorLook.ink,
                      ),
                    ),
                    Text(_summary(clients), style: VendorLook.body),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 24,
                color: VendorLook.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _summary(ClientViewModel clients) {
    final total = clients.clients.length;
    if (total == 0) return 'Aún no tienes clientes';
    final debtors = clients.debtorCount;
    if (debtors == 0) return 'Todos al día · $total en la ruta';
    final debt = formatSoles(clients.totalDebtCents);
    final who = debtors == 1 ? '1 debe' : '$debtors deben';
    return '$who S/ $debt · $total en la ruta';
  }
}

class _VoiceConsole extends StatelessWidget {
  const _VoiceConsole();

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceCaptureViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 72,
          child: FilledButton.icon(
            onPressed: voice.toggle,
            icon: Icon(
              voice.isListening ? Icons.stop : Icons.mic,
              size: 28,
              color: VendorLook.onAccent,
            ),
            label: Text(
              voice.isListening ? 'Detener' : 'Hablar',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: VendorLook.onAccent,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: VendorLook.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VendorLook.buttonRadius),
                side: VendorLook.buttonSide,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        VendorSurface(
          padding: const EdgeInsets.all(10),
          child: Text(
            voiceHint(voice),
            textAlign: TextAlign.center,
            style: voice.transcript.isEmpty
                ? VendorLook.body
                : VendorLook.subtitle,
          ),
        ),
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
      ],
    );
  }
}

String voiceHint(VoiceCaptureViewModel voice) {
  if (voice.transcript.isNotEmpty) return voice.transcript;
  if (!voice.isListening) {
    return 'Pulsa Hablar. Di: fiado a María 10 soles';
  }
  if (voice.hearingStrength > 0.2) return 'Te oigo… sigue hablando';
  return 'Escuchando… habla ahora';
}

class MicHearingBar extends StatelessWidget {
  const MicHearingBar({super.key, required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(8, (index) {
        final active = strength > (index + 1) / 8;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ColoredBox(
              color: active ? VendorLook.ink : const Color(0xFFDDDDDD),
              child: const SizedBox(height: 12),
            ),
          ),
        );
      }),
    );
  }
}
