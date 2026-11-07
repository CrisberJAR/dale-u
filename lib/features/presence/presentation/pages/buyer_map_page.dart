import 'dart:async';

import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:dale_u/features/buyer/domain/linked_account.dart';
import 'package:dale_u/features/presence/domain/vendor_on_map.dart';
import 'package:dale_u/features/presence/presentation/viewmodels/buyer_map_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

/// Mapa a pedido. Teselas de OpenStreetMap, sin Google y sin factura.
class BuyerMapPage extends StatefulWidget {
  const BuyerMapPage({super.key, required this.accounts});

  final List<LinkedAccount> accounts;

  @override
  State<BuyerMapPage> createState() => _BuyerMapPageState();
}

class _BuyerMapPageState extends State<BuyerMapPage> {
  final _mapController = MapController();
  late final BuyerMapViewModel _map;
  var _mapReady = false;
  var _framedKey = '';

  @override
  void initState() {
    super.initState();
    _map = context.read<BuyerMapViewModel>();
    _map.addListener(_onPinsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _map.start(widget.accounts);
    });
  }

  @override
  void dispose() {
    _map.removeListener(_onPinsChanged);
    unawaited(_map.stop());
    _mapController.dispose();
    super.dispose();
  }

  void _onPinsChanged() => _framePins(_map.visiblePins);

  /// `initialCenter` no se actualiza. Hay que mover la cámara a mano.
  void _framePins(List<VendorOnMap> pins) {
    if (!_mapReady || !mounted) return;
    if (pins.isEmpty) {
      _framedKey = '';
      return;
    }
    final key = (pins.map((pin) => pin.vendorUid).toList()..sort()).join('|');
    if (key == _framedKey) return;
    final points = pins.map(_pointOf).toList();
    try {
      if (points.length == 1 || _sameSpot(points)) {
        _mapController.move(points.first, 15);
      } else {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.all(56),
            maxZoom: 16,
          ),
        );
      }
      _framedKey = key;
    } on StateError {
      // El mapa aún no está en el árbol; onMapReady lo reintenta.
    }
  }

  static bool _sameSpot(List<LatLng> points) {
    const Distance meters = Distance();
    final first = points.first;
    return points.every((point) => meters(first, point) <= 40);
  }

  @override
  Widget build(BuildContext context) {
    final map = context.watch<BuyerMapViewModel>();
    final pins = map.visiblePins;

    return Theme(
      data: VendorLook.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: VendorLook.background,
        appBar: AppBar(
          backgroundColor: VendorLook.background,
          foregroundColor: VendorLook.ink,
          title: Text('Dónde está', style: BuyerLook.title),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                _statusLine(map, pins),
                textAlign: TextAlign.center,
                style: BuyerLook.body,
              ),
            ),
            if (map.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  map.errorMessage!,
                  textAlign: TextAlign.center,
                  style: BuyerLook.dangerText,
                ),
              ),
            Expanded(
              child: map.loading && pins.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(color: VendorLook.ink),
                    )
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: pins.isEmpty
                            ? const LatLng(-12.0464, -77.0428)
                            : _pointOf(pins.first),
                        initialZoom: 14,
                        onMapReady: () {
                          _mapReady = true;
                          _framePins(pins);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.daleu.dale_u',
                        ),
                        MarkerLayer(
                          markers: [
                            for (final pin in pins)
                              Marker(
                                point: _pointOf(pin),
                                width: 72,
                                height: 64,
                                alignment: Alignment.topCenter,
                                child: _Pin(name: pin.name),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '© OpenStreetMap',
                textAlign: TextAlign.center,
                style: BuyerLook.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static LatLng _pointOf(VendorOnMap pin) {
    final fix = pin.presence.fix!;
    return LatLng(fix.latitude, fix.longitude);
  }

  static String _statusLine(BuyerMapViewModel map, List<VendorOnMap> pins) {
    if (map.loading && pins.isEmpty) {
      return 'Buscando al panadero…';
    }
    if (pins.isEmpty) {
      return 'Hoy no está en ruta, o la última ubicación ya es vieja.';
    }
    if (pins.length == 1) {
      return '${pins.first.name}. ${_age(pins.first)}';
    }
    return '${pins.length} vendedores en ruta.';
  }

  static String _age(VendorOnMap pin) {
    final minutes = DateTime.now().difference(pin.presence.updatedAt).inMinutes;
    if (minutes < 1) return 'Lo vimos recién.';
    if (minutes == 1) return 'Hace 1 minuto.';
    return 'Hace $minutes minutos.';
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_shipping, size: 36, color: VendorLook.ink),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: VendorLook.ink,
          ),
        ),
      ],
    );
  }
}
