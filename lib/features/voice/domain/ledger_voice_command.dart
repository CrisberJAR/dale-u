import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/voice/domain/new_client_voice_command.dart';
import 'package:dale_u/features/voice/domain/spoken_amount.dart';

/// Interpreta fiado o pago por voz. La consulta de deuda es DebtVoiceCommand.
final class LedgerVoiceCommand {
  const LedgerVoiceCommand({
    required this.kind,
    required this.name,
    required this.amountCents,
  });

  final MovementKind kind;
  final String name;
  final int? amountCents;

  bool get hasName => name.trim().length >= 2;
  bool get isComplete => hasName && amountCents != null;

  static const missingAmountHint =
      'Dime el monto. Por ejemplo: fiado a María 5 soles.';
  static const missingNameHint =
      'Dime a quién. Por ejemplo: fiado a María 5 soles.';

  /// `null` si la frase no es fiado ni pago.
  static LedgerVoiceCommand? tryParse(String spoken) {
    if (NewClientVoiceCommand.tryParse(spoken) != null) return null;

    final cleaned = spoken.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return null;

    return _fromStart(cleaned) ?? _fromEnd(cleaned);
  }

  /// "fiado a María 5000": la palabra clave abre la frase.
  static LedgerVoiceCommand? _fromStart(String cleaned) {
    final fiado = _fiadoTrigger.firstMatch(cleaned);
    final pago = _pagoTrigger.firstMatch(cleaned);
    if (fiado == null && pago == null) return null;

    final kind = fiado != null ? MovementKind.fiado : MovementKind.pago;
    final match = fiado ?? pago!;
    var rest = cleaned.substring(match.end).trim();
    rest = rest.replaceFirst(RegExp(r'^[\s:,.\-]+'), '').trim();

    if (rest.isEmpty) {
      return LedgerVoiceCommand(kind: kind, name: '', amountCents: null);
    }

    final split = _splitNameAndAmount(rest);
    return LedgerVoiceCommand(
      kind: kind,
      name: _prettyName(split.name),
      amountCents: split.amount,
    );
  }

  /// "María 10 soles de fiado": así habla el vendedor en la calle.
  /// Exige nombre y monto para no tragarse consultas ("cuánto tiene de fiado").
  static LedgerVoiceCommand? _fromEnd(String cleaned) {
    final fiado = _fiadoEnding.firstMatch(cleaned);
    final pago = fiado == null ? _pagoEnding.firstMatch(cleaned) : null;
    final match = fiado ?? pago;
    if (match == null) return null;

    final rest = cleaned.substring(0, match.start).trim();
    if (rest.isEmpty) return null;

    final split = _splitNameAndAmount(rest);
    final name = _prettyName(split.name);
    if (split.amount == null || name.trim().length < 2) return null;
    // "esto es un fiado": ahí "un" es artículo, no un sol.
    if (_bareArticle.hasMatch(split.amountText)) return null;

    return LedgerVoiceCommand(
      kind: fiado != null ? MovementKind.fiado : MovementKind.pago,
      name: name,
      amountCents: split.amount,
    );
  }

  static ({String name, int? amount, String amountText}) _splitNameAndAmount(
    String rest,
  ) {
    final tokens = rest.split(' ').where((token) => token.isNotEmpty).toList();
    final maxTake = tokens.length < 6 ? tokens.length : 6;
    for (var take = maxTake; take >= 1; take--) {
      final amountPart = tokens.sublist(tokens.length - take).join(' ');
      final parsed = SpokenAmount.tryParse(amountPart);
      if (parsed != null) {
        final name = tokens.sublist(0, tokens.length - take).join(' ');
        return (name: name, amount: parsed, amountText: amountPart);
      }
    }
    return (name: rest, amount: null, amountText: '');
  }

  static final _bareArticle = RegExp(r'^(?:un|una|uno)$', caseSensitive: false);

  static final _fiadoTrigger = RegExp(
    r'^(?:por favor |oye |okey |ok |bueno )?'
    r'(?:quiero |voy a |vamos a )?'
    r'(?:anotar |anota |apunta |apuntar )?'
    r'(?:un |una |el |la )?'
    r'(?:fiados?|fiar|f[ií]a)(?![a-záéíóúüñ])'
    // Sin esto "fiado Ander" se leía como "fiado a Nder".
    r'(?:\s+(?:a|de)\b)?',
    caseSensitive: false,
  );

  static final _pagoTrigger = RegExp(
    r'^(?:por favor |oye |okey |ok |bueno )?'
    r'(?:quiero |voy a |vamos a )?'
    r'(?:anotar |anota |apunta |apuntar )?'
    r'(?:un |una |el |la )?'
    r'(?:pag[oó]s?|pagar|pagu[eé]|cobros?|cobrar|cobr[eé])(?![a-záéíóúüñ])'
    r'(?:\s+(?:a|de|por)\b)?',
    caseSensitive: false,
  );

  static final _fiadoEnding = RegExp(
    r'\s+(?:de |en |como |al |a )?(?:fiado|fiados|fiar|fia|fía)\s*$',
    caseSensitive: false,
  );

  static final _pagoEnding = RegExp(
    r'\s+(?:de |en |como |al |a )?(?:pag[oó]|pagos|abono|abonos)\s*$',
    caseSensitive: false,
  );

  static String _prettyName(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) {
          if (word.length == 1) return word.toUpperCase();
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }
}
