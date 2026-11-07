import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:dale_u/features/presence/data/geolocator_location_gateway.dart';
import 'package:dale_u/features/presence/domain/location_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

/// El vendedor toca el mapa o usa el GPS. Sin avisos de cercanía todavía.
class ClientHouseMapPage extends StatefulWidget {
  const ClientHouseMapPage({
    super.key,
    required this.clientId,
    this.location,
  });

  final String clientId;
  final LocationGateway? location;

  @override
  State<ClientHouseMapPage> createState() => _ClientHouseMapPageState();
}

class _ClientHouseMapPageState extends State<ClientHouseMapPage> {
  static const _lima = LatLng(-12.0464, -77.0428);

  final _mapController = MapController();
  late final LocationGateway _location;
  LatLng? _draft;
  var _mapReady = false;
  var _locating = false;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    _location = widget.location ?? GeolocatorLocationGateway();
    final client = context.read<ClientViewModel>().clientById(widget.clientId);
    _draft = _pointOf(client);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  static LatLng? _pointOf(Client? client) {
    if (client == null || !client.hasHousePin) return null;
    return LatLng(client.latitude!, client.longitude!);
  }

  void _place(LatLng point) {
    setState(() {
      _draft = point;
      _gpsError = null;
    });
    if (_mapReady) {
      _mapController.move(point, 16);
    }
  }

  Future<void> _useGps() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _gpsError = null;
    });
    try {
      final blocked = await _location.ensureReady();
      if (!mounted) return;
      if (blocked != null) {
        setState(() => _gpsError = blocked);
        return;
      }
      final fix = await _location.readFix();
      if (!mounted) return;
      if (fix == null) {
        setState(() => _gpsError = 'No pude leer el GPS. Toca el mapa.');
        return;
      }
      _place(LatLng(fix.latitude, fix.longitude));
    } catch (_) {
      if (!mounted) return;
      setState(() => _gpsError = 'No pude leer el GPS. Toca el mapa.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) {
      setState(() => _gpsError = 'Toca el mapa o pulsa Estoy aquí.');
      return;
    }
    final ok = await context.read<ClientViewModel>().setHouseLocation(
      id: widget.clientId,
      latitude: draft.latitude,
      longitude: draft.longitude,
    );
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    final ok = await context.read<ClientViewModel>().setHouseLocation(
      id: widget.clientId,
      latitude: null,
      longitude: null,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _draft = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClientViewModel>();
    final client = viewModel.clientById(widget.clientId);
    final center = _draft ?? _lima;

    return Theme(
      data: VendorLook.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: VendorLook.background,
        appBar: AppBar(
          backgroundColor: VendorLook.background,
          foregroundColor: VendorLook.ink,
          title: Text('Casa del cliente', style: VendorLook.title),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                client == null
                    ? 'Este cliente ya no está en la lista.'
                    : 'Toca el mapa donde queda la casa de ${client.name}.',
                textAlign: TextAlign.center,
                style: VendorLook.body,
              ),
            ),
            if (_gpsError != null || viewModel.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _gpsError ?? viewModel.errorMessage!,
                  textAlign: TextAlign.center,
                  style: VendorLook.dangerText,
                ),
              ),
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _draft == null ? 14 : 16,
                  onMapReady: () {
                    _mapReady = true;
                    if (_draft != null) {
                      _mapController.move(_draft!, 16);
                    }
                  },
                  onTap: (_, point) => _place(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.daleu.dale_u',
                  ),
                  if (_draft != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _draft!,
                          width: 56,
                          height: 56,
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.home,
                            size: 40,
                            color: VendorLook.ink,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '© OpenStreetMap',
                textAlign: TextAlign.center,
                style: VendorLook.body,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  VendorSecondaryButton(
                    label: _locating ? 'Buscando…' : 'Estoy aquí',
                    onPressed: _locating || viewModel.saving ? null : _useGps,
                  ),
                  const SizedBox(height: 8),
                  VendorPrimaryButton(
                    label: 'Guardar casa',
                    icon: Icons.home,
                    busy: viewModel.saving,
                    onPressed: viewModel.saving || client == null ? null : _save,
                  ),
                  if (client != null && (client.hasHousePin || _draft != null))
                    VendorTextAction(
                      label: 'Quitar marca',
                      onPressed: viewModel.saving ? null : _clear,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
