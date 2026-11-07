import 'dart:async';

import 'package:dale_u/core/error/auth_failure.dart';
import 'package:dale_u/core/error/result.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/repositories/auth_repository.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/presence/data/datasources/presence_remote_datasource.dart';
import 'package:dale_u/features/presence/data/presence_local_store.dart';
import 'package:dale_u/features/presence/domain/geo_fix.dart';
import 'package:dale_u/features/presence/domain/location_gateway.dart';
import 'package:dale_u/features/presence/domain/vendor_on_map.dart';
import 'package:dale_u/features/presence/domain/vendor_presence.dart';
import 'package:dale_u/features/presence/presentation/viewmodels/presence_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(this.session);

  final UserSession? session;

  @override
  Stream<UserSession?> observeAuthState() => Stream.value(session);

  @override
  Future<Result<UserSession>> signInWithGoogle() async {
    return const Err(AuthFailure.unknown());
  }

  @override
  Future<Result<void>> signOut() async => const Ok<void>(null);
}

class _FakeGps implements LocationGateway {
  String? blocked;
  GeoFix fix = const GeoFix(latitude: -12.05, longitude: -77.04);
  int reads = 0;

  @override
  Future<String?> ensureReady() async => blocked;

  @override
  Future<GeoFix?> readFix() async {
    reads++;
    return fix;
  }

  final stream = StreamController<GeoFix>.broadcast();

  @override
  Stream<GeoFix> watch() => stream.stream;
}

class _FakeRemote implements PresenceRemoteDataSource {
  final published = <VendorPresence>[];

  @override
  Future<void> publish(String vendorUid, VendorPresence presence) async {
    published.add(presence);
  }

  @override
  Future<VendorPresence?> fetch(String vendorUid) async =>
      published.isEmpty ? null : published.last;

  @override
  Stream<VendorPresence?> watch(String vendorUid) =>
      const Stream<VendorPresence?>.empty();

  @override
  Stream<List<VendorOnRoute>> watchAllOnRoute() =>
      const Stream<List<VendorOnRoute>>.empty();
}

void main() {
  const session = UserSession(
    uid: 'uid123',
    email: 'ana@pan.com',
    displayName: 'Ana',
  );

  PresenceViewModel build({
    _FakeGps? gps,
    _FakeRemote? remote,
    PresenceLocalStore? store,
    DateTime Function()? now,
  }) {
    return PresenceViewModel(
      observeAuthState: ObserveAuthState(_FakeAuth(session)),
      location: gps ?? _FakeGps(),
      remote: remote ?? _FakeRemote(),
      store: store ?? PresenceLocalStore.memory(),
      now: now,
    );
  }

  test('sin permiso no entra en ruta ni escribe', () async {
    final gps = _FakeGps()..blocked = 'Sin permiso';
    final remote = _FakeRemote();
    final viewModel = build(gps: gps, remote: remote);

    await Future<void>.delayed(Duration.zero);
    await viewModel.enterRoute();

    expect(viewModel.onRoute, isFalse);
    expect(viewModel.errorMessage, 'Sin permiso');
    expect(remote.published, isEmpty);
    viewModel.dispose();
  });

  test('al entrar publica el punto y al salir avisa que ya no está', () async {
    final remote = _FakeRemote();
    final viewModel = build(remote: remote);
    await Future<void>.delayed(Duration.zero);

    await viewModel.enterRoute();
    expect(viewModel.onRoute, isTrue);
    expect(viewModel.lastReadFix?.latitude, -12.05);
    expect(remote.published, hasLength(1));
    expect(remote.published.first.onRoute, isTrue);
    expect(remote.published.first.fix?.latitude, -12.05);

    await viewModel.leaveRoute();
    expect(viewModel.onRoute, isFalse);
    expect(remote.published.last.onRoute, isFalse);
    expect(remote.published.last.fix, isNull);
    viewModel.dispose();
  });

  test('en ruta, cada avance del GPS sube un punto nuevo', () async {
    final gps = _FakeGps();
    final remote = _FakeRemote();
    var clock = DateTime(2026, 9, 1, 8);
    final viewModel = build(gps: gps, remote: remote, now: () => clock);
    await Future<void>.delayed(Duration.zero);

    await viewModel.enterRoute();
    expect(remote.published, hasLength(1));

    // 3 segundos después: muy pronto, no escribe.
    clock = clock.add(const Duration(seconds: 3));
    gps.stream.add(const GeoFix(latitude: -12.0510, longitude: -77.04));
    await Future<void>.delayed(Duration.zero);
    expect(remote.published, hasLength(1));
    expect(viewModel.lastReadFix?.latitude, -12.0510);

    // 15 segundos y ~110 m más allá: sí escribe.
    clock = clock.add(const Duration(seconds: 15));
    gps.stream.add(const GeoFix(latitude: -12.0520, longitude: -77.04));
    await Future<void>.delayed(Duration.zero);
    expect(remote.published, hasLength(2));
    expect(remote.published.last.fix?.latitude, -12.0520);

    await viewModel.leaveRoute();
    viewModel.dispose();
  });
}
