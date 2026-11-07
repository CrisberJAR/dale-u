import 'package:dale_u/features/voice/domain/voice_capture_gateway.dart';
import 'package:dale_u/features/voice/domain/voice_playback_gateway.dart';
import 'package:dale_u/features/voice/presentation/viewmodels/voice_capture_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVoiceGateway implements VoiceCaptureGateway {
  void Function(VoiceTranscript transcript)? onTranscript;
  void Function(String message)? onError;
  void Function()? onDone;

  @override
  Future<bool> ensureReady() async => true;

  @override
  Future<void> start({
    required void Function(VoiceTranscript transcript) onTranscript,
    required void Function(String message) onError,
    required void Function() onDone,
    void Function()? onStarted,
    void Function(double level)? onSoundLevel,
  }) async {
    this.onTranscript = onTranscript;
    this.onError = onError;
    this.onDone = onDone;
    onStarted?.call();
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

class _FakePlayback implements VoicePlaybackGateway {
  final spoken = <String>[];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('muestra el texto dictado y lo deja en pantalla al terminar', () async {
    final gateway = _FakeVoiceGateway();
    final playback = _FakePlayback();
    final viewModel = VoiceCaptureViewModel(
      capture: gateway,
      playback: playback,
    );

    await viewModel.start();
    expect(viewModel.isListening, isTrue);

    gateway.onTranscript!(
      const VoiceTranscript(text: '  buenos días María  ', isFinal: false),
    );
    expect(viewModel.transcript, 'buenos días María');

    gateway.onDone!();
    await _settle();
    expect(viewModel.isListening, isFalse);
    expect(viewModel.transcript, 'Oí. buenos días María');
    expect(viewModel.errorMessage, isNull);
    expect(playback.spoken, ['Oí. buenos días María']);

    viewModel.dispose();
  });

  test('si no hay texto, avisa que no se escuchó y lo dice en voz alta', () async {
    final gateway = _FakeVoiceGateway();
    final playback = _FakePlayback();
    final viewModel = VoiceCaptureViewModel(
      capture: gateway,
      playback: playback,
    );

    await viewModel.start();
    gateway.onDone!();
    await _settle();

    expect(viewModel.isListening, isFalse);
    expect(viewModel.errorMessage, contains('No se escuchó nada'));
    expect(playback.spoken.single, contains('No se escuchó nada'));

    viewModel.dispose();
  });

  test('guarda cliente por voz y confirma en voz alta una sola vez', () async {
    final gateway = _FakeVoiceGateway();
    final playback = _FakePlayback();
    final saved = <({String name, String phone})>[];
    final viewModel = VoiceCaptureViewModel(
      capture: gateway,
      playback: playback,
      registerClientByVoice: ({required String name, required String phone}) async {
        saved.add((name: name, phone: phone));
        return null;
      },
    );

    await viewModel.start();
    gateway.onTranscript!(
      const VoiceTranscript(
        text: 'nuevo cliente María teléfono 3001234567',
        isFinal: true,
      ),
    );
    gateway.onDone!();
    gateway.onDone!();
    await _settle();

    expect(saved, [(name: 'María', phone: '3001234567')]);
    expect(playback.spoken.single, 'Listo. Cliente María guardado. Teléfono 3001234567.');
    expect(viewModel.transcript, contains('Listo. Cliente María'));

    viewModel.dispose();
  });

  test('si falta el nombre, no guarda y pide el nombre en voz alta', () async {
    final gateway = _FakeVoiceGateway();
    final playback = _FakePlayback();
    var called = false;
    final viewModel = VoiceCaptureViewModel(
      capture: gateway,
      playback: playback,
      registerClientByVoice: ({required String name, required String phone}) async {
        called = true;
        return null;
      },
    );

    await viewModel.start();
    gateway.onTranscript!(
      const VoiceTranscript(text: 'nuevo cliente', isFinal: true),
    );
    gateway.onDone!();
    await _settle();

    expect(called, isFalse);
    expect(viewModel.errorMessage, contains('Dime el nombre'));
    expect(playback.spoken.single, contains('Dime el nombre'));

    viewModel.dispose();
  });

  test('si el guardado local falla, lo dice en voz alta', () async {
    final gateway = _FakeVoiceGateway();
    final playback = _FakePlayback();
    final viewModel = VoiceCaptureViewModel(
      capture: gateway,
      playback: playback,
      registerClientByVoice: ({required String name, required String phone}) async {
        return 'Escribe el nombre del cliente.';
      },
    );

    await viewModel.start();
    gateway.onTranscript!(
      const VoiceTranscript(text: 'nuevo cliente María', isFinal: true),
    );
    gateway.onDone!();
    await _settle();

    expect(playback.spoken.single, 'Escribe el nombre del cliente.');
    expect(viewModel.errorMessage, 'Escribe el nombre del cliente.');

    viewModel.dispose();
  });

  test('anota fiado por voz una sola vez y lo confirma', () async {
    final gateway = _FakeVoiceGateway();
    final playback = _FakePlayback();
    final saved = <({String name, int amount})>[];
    final viewModel = VoiceCaptureViewModel(
      capture: gateway,
      playback: playback,
      recordLedgerByVoice: ({
        required kind,
        required spokenName,
        required amountCents,
      }) async {
        saved.add((name: spokenName, amount: amountCents));
        return (ok: true, message: 'Listo. Fiado de 5.000 soles a María.');
      },
    );

    await viewModel.start();
    gateway.onTranscript!(
      const VoiceTranscript(text: 'fiado a María 5000', isFinal: true),
    );
    gateway.onDone!();
    gateway.onDone!();
    await _settle();

    expect(saved, [(name: 'María', amount: 500000)]);
    expect(playback.spoken.single, contains('Fiado de 5.000 soles'));

    viewModel.dispose();
  });

  test('si el fiado no trae monto, pide el monto y no guarda', () async {
    final gateway = _FakeVoiceGateway();
    final playback = _FakePlayback();
    var called = false;
    final viewModel = VoiceCaptureViewModel(
      capture: gateway,
      playback: playback,
      recordLedgerByVoice: ({
        required kind,
        required spokenName,
        required amountCents,
      }) async {
        called = true;
        return (ok: true, message: 'no');
      },
    );

    await viewModel.start();
    gateway.onTranscript!(
      const VoiceTranscript(text: 'fiado a María', isFinal: true),
    );
    gateway.onDone!();
    await _settle();

    expect(called, isFalse);
    expect(viewModel.errorMessage, contains('Dime el monto'));
    expect(playback.spoken.single, contains('Dime el monto'));

    viewModel.dispose();
  });

  test('consulta deuda por voz y la dice en voz alta', () async {
    final gateway = _FakeVoiceGateway();
    final playback = _FakePlayback();
    final asked = <String>[];
    final viewModel = VoiceCaptureViewModel(
      capture: gateway,
      playback: playback,
      queryBalanceByVoice: ({required spokenName}) async {
        asked.add(spokenName);
        return (ok: true, message: 'María debe 5.000 soles.');
      },
    );

    await viewModel.start();
    gateway.onTranscript!(
      const VoiceTranscript(text: 'cuánto debe María', isFinal: true),
    );
    gateway.onDone!();
    await _settle();

    expect(asked, ['María']);
    expect(playback.spoken.single, 'María debe 5.000 soles.');

    viewModel.dispose();
  });

  test('si la consulta no trae nombre, pide el nombre y no consulta', () async {
    final gateway = _FakeVoiceGateway();
    final playback = _FakePlayback();
    var called = false;
    final viewModel = VoiceCaptureViewModel(
      capture: gateway,
      playback: playback,
      queryBalanceByVoice: ({required spokenName}) async {
        called = true;
        return (ok: true, message: 'no');
      },
    );

    await viewModel.start();
    gateway.onTranscript!(
      const VoiceTranscript(text: 'cuánto debe', isFinal: true),
    );
    gateway.onDone!();
    await _settle();

    expect(called, isFalse);
    expect(viewModel.errorMessage, contains('Dime el nombre'));
    expect(playback.spoken.single, contains('cuánto debe María'));

    viewModel.dispose();
  });

  test('buscar por voz pone el nombre y confirma en voz alta', () async {
    final gateway = _FakeVoiceGateway();
    final playback = _FakePlayback();
    final asked = <String>[];
    final viewModel = VoiceCaptureViewModel(
      capture: gateway,
      playback: playback,
      applySearchByVoice: ({required spokenQuery}) async {
        asked.add(spokenQuery);
        return (ok: true, message: 'Buscando María. Hay 1 cliente.');
      },
    );

    await viewModel.start();
    gateway.onTranscript!(
      const VoiceTranscript(text: 'buscar María', isFinal: true),
    );
    gateway.onDone!();
    await _settle();

    expect(asked, ['María']);
    expect(playback.spoken.single, 'Buscando María. Hay 1 cliente.');

    viewModel.dispose();
  });

  test('un nombre suelto también filtra si hay buscador', () async {
    final gateway = _FakeVoiceGateway();
    final playback = _FakePlayback();
    final asked = <String>[];
    final viewModel = VoiceCaptureViewModel(
      capture: gateway,
      playback: playback,
      applySearchByVoice: ({required spokenQuery}) async {
        asked.add(spokenQuery);
        return (ok: true, message: 'Buscando Juan. Hay 1 cliente.');
      },
    );

    await viewModel.start();
    gateway.onTranscript!(
      const VoiceTranscript(text: 'Juan', isFinal: true),
    );
    gateway.onDone!();
    await _settle();

    expect(asked, ['Juan']);
    expect(playback.spoken.single, contains('Buscando Juan'));

    viewModel.dispose();
  });

  test('si buscar no trae nombre, pide el nombre y no filtra', () async {
    final gateway = _FakeVoiceGateway();
    final playback = _FakePlayback();
    var called = false;
    final viewModel = VoiceCaptureViewModel(
      capture: gateway,
      playback: playback,
      applySearchByVoice: ({required spokenQuery}) async {
        called = true;
        return (ok: true, message: 'no');
      },
    );

    await viewModel.start();
    gateway.onTranscript!(
      const VoiceTranscript(text: 'buscar', isFinal: true),
    );
    gateway.onDone!();
    await _settle();

    expect(called, isFalse);
    expect(viewModel.errorMessage, contains('Dime el nombre'));
    expect(playback.spoken.single, contains('buscar María'));

    viewModel.dispose();
  });
}
