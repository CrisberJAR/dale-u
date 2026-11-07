import 'dart:async';

import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/voice/domain/debt_voice_command.dart';
import 'package:dale_u/features/voice/domain/ledger_voice_command.dart';
import 'package:dale_u/features/voice/domain/new_client_voice_command.dart';
import 'package:dale_u/features/voice/domain/search_voice_command.dart';
import 'package:dale_u/features/voice/domain/undo_voice_command.dart';
import 'package:dale_u/features/voice/domain/voice_capture_gateway.dart';
import 'package:dale_u/features/voice/domain/voice_playback_gateway.dart';
import 'package:flutter/foundation.dart';

/// Guarda un cliente en local. `null` = ok; texto = error para decirlo en voz alta.
typedef VoiceClientRegistrar =
    Future<String?> Function({required String name, required String phone});

typedef VoiceLedgerRecorder =
    Future<({bool ok, String message})> Function({
      required MovementKind kind,
      required String spokenName,
      required int amountCents,
    });

typedef VoiceBalanceQuery =
    Future<({bool ok, String message})> Function({required String spokenName});

/// Anula el último fiado o pago dicho por voz.
typedef VoiceUndo = Future<({bool ok, String message})> Function();

typedef VoiceSearchApplier =
    Future<({bool ok, String message})> Function({required String spokenQuery});

class VoiceCaptureViewModel extends ChangeNotifier {
  static const notUnderstoodHint =
      'No te entendí. Di: fiado a María 10 soles.';

  VoiceCaptureViewModel({
    required this.capture,
    required this.playback,
    this.registerClientByVoice,
    this.recordLedgerByVoice,
    this.queryBalanceByVoice,
    this.applySearchByVoice,
    this.undoLastByVoice,
  });

  final VoiceCaptureGateway capture;
  final VoicePlaybackGateway playback;
  final VoiceClientRegistrar? registerClientByVoice;
  final VoiceLedgerRecorder? recordLedgerByVoice;
  final VoiceBalanceQuery? queryBalanceByVoice;
  final VoiceSearchApplier? applySearchByVoice;
  final VoiceUndo? undoLastByVoice;

  VoiceCaptureStatus _status = VoiceCaptureStatus.idle;
  String _transcript = '';
  String? _errorMessage;
  double _soundLevel = 0;
  bool _busy = false;
  bool _turnClosed = false;

  VoiceCaptureStatus get status => _status;
  String get transcript => _transcript;
  String? get errorMessage => _errorMessage;
  bool get isListening => _status == VoiceCaptureStatus.listening;
  double get hearingStrength {
    final normalized = _soundLevel < 0
        ? (_soundLevel + 20) / 20
        : _soundLevel / 10;
    return normalized.clamp(0.0, 1.0);
  }

  Future<void> toggle() async {
    if (isListening) {
      await stop();
      return;
    }
    await start();
  }

  Future<void> start() async {
    if (isListening || _busy) return;
    _busy = true;
    _turnClosed = false;
    _errorMessage = null;
    _transcript = '';
    _soundLevel = 0;
    await playback.stop();
    notifyListeners();

    try {
      await capture.start(
        onStarted: () {
          _status = VoiceCaptureStatus.listening;
          notifyListeners();
        },
        onTranscript: (result) {
          _transcript = InputSanitizer.spokenText(result.text);
          notifyListeners();
        },
        onSoundLevel: (level) {
          _soundLevel = level;
          notifyListeners();
        },
        onError: (message) {
          if (_transcript.isNotEmpty) {
            _status = VoiceCaptureStatus.idle;
          } else {
            _errorMessage = message;
            _status = VoiceCaptureStatus.error;
          }
          notifyListeners();
          unawaited(_finishTurn());
        },
        onDone: () {
          if (_status != VoiceCaptureStatus.listening) return;
          _status = VoiceCaptureStatus.idle;
          if (_transcript.isEmpty && _errorMessage == null) {
            _errorMessage =
                'No se escuchó nada. Pulsa Hablar, espera el pitido y habla cerca del teléfono.';
          }
          notifyListeners();
          unawaited(_finishTurn());
        },
      );
    } catch (_) {
      _errorMessage = 'No se pudo iniciar el micrófono.';
      _status = VoiceCaptureStatus.error;
      notifyListeners();
      unawaited(_finishTurn());
    } finally {
      _busy = false;
    }
  }

  Future<void> stop() async {
    await capture.stop();
    _soundLevel = 0;
    _status = VoiceCaptureStatus.idle;
    notifyListeners();
    unawaited(_finishTurn());
  }

  Future<void> _finishTurn() async {
    if (_turnClosed) return;
    _turnClosed = true;

    final phrase = await _replyForTurn();
    final clean = InputSanitizer.spokenText(phrase);
    if (clean.isEmpty) return;
    if (clean != _transcript && _errorMessage == null) {
      _transcript = clean;
      notifyListeners();
    }
    try {
      await playback.speak(clean);
    } catch (error) {
      debugPrint('DaleU TTS failed: $error');
    }
  }

  Future<String> _replyForTurn() async {
    if (_transcript.isEmpty) return _errorMessage ?? '';

    final undo = undoLastByVoice;
    if (undo != null && UndoVoiceCommand.matches(_transcript)) {
      final result = await undo();
      if (!result.ok) {
        _errorMessage = result.message;
        notifyListeners();
      }
      return result.message;
    }

    final newClient = NewClientVoiceCommand.tryParse(_transcript);
    if (newClient != null) {
      return _handleNewClient(newClient);
    }

    final ledger = LedgerVoiceCommand.tryParse(_transcript);
    if (ledger != null) {
      return _handleLedger(ledger);
    }

    final debt = DebtVoiceCommand.tryParse(_transcript);
    if (debt != null) {
      return _handleDebt(debt);
    }

    final search = SearchVoiceCommand.tryParse(_transcript);
    if (search != null) {
      return _handleSearch(search);
    }

    if (applySearchByVoice != null) {
      final bare = SearchVoiceCommand.asBareQuery(_transcript);
      if (bare != null) {
        return _handleSearch(SearchVoiceCommand(query: bare));
      }
      // Antes esto acababa en el buscador y vaciaba la lista sin avisar.
      _errorMessage = notUnderstoodHint;
      notifyListeners();
      return notUnderstoodHint;
    }

    return 'Oí. $_transcript';
  }

  Future<String> _handleNewClient(NewClientVoiceCommand command) async {
    if (!command.hasName) {
      _errorMessage = 'Dime el nombre. Por ejemplo: nuevo cliente María.';
      notifyListeners();
      return _errorMessage!;
    }

    final registrar = registerClientByVoice;
    if (registrar == null) {
      return 'Oí. $_transcript';
    }

    final error = await registrar(name: command.name, phone: command.phone);
    if (error != null) {
      _errorMessage = error;
      notifyListeners();
      return error;
    }

    final phoneBit = command.phone.isEmpty ? '' : ' Teléfono ${command.phone}.';
    return 'Listo. Cliente ${command.name} guardado.$phoneBit';
  }

  Future<String> _handleLedger(LedgerVoiceCommand command) async {
    if (!command.hasName) {
      _errorMessage = LedgerVoiceCommand.missingNameHint;
      notifyListeners();
      return _errorMessage!;
    }
    if (command.amountCents == null) {
      _errorMessage = LedgerVoiceCommand.missingAmountHint;
      notifyListeners();
      return _errorMessage!;
    }

    final recorder = recordLedgerByVoice;
    if (recorder == null) {
      return 'Oí. $_transcript';
    }

    final result = await recorder(
      kind: command.kind,
      spokenName: command.name,
      amountCents: command.amountCents!,
    );
    if (!result.ok) {
      _errorMessage = result.message;
      notifyListeners();
    }
    return result.message;
  }

  Future<String> _handleDebt(DebtVoiceCommand command) async {
    if (!command.hasName) {
      _errorMessage = DebtVoiceCommand.missingNameHint;
      notifyListeners();
      return _errorMessage!;
    }

    final query = queryBalanceByVoice;
    if (query == null) {
      return 'Oí. $_transcript';
    }

    final result = await query(spokenName: command.name);
    if (!result.ok) {
      _errorMessage = result.message;
      notifyListeners();
    }
    return result.message;
  }

  Future<String> _handleSearch(SearchVoiceCommand command) async {
    if (!command.hasQuery) {
      _errorMessage = SearchVoiceCommand.missingQueryHint;
      notifyListeners();
      return _errorMessage!;
    }

    final applier = applySearchByVoice;
    if (applier == null) {
      return 'Oí. $_transcript';
    }

    final result = await applier(spokenQuery: command.query);
    if (!result.ok) {
      _errorMessage = result.message;
      notifyListeners();
    }
    return result.message;
  }

  Future<void> say(String text) => playback.speak(text);

  @override
  void dispose() {
    unawaited(capture.cancel());
    unawaited(playback.stop());
    super.dispose();
  }
}
