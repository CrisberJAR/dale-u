import 'package:dale_u/core/format/money.dart';

/// Los documentos viejos guardaban soles enteros en `amountPesos`.
/// Se leen como céntimos para que una deuda antigua no se vea cien veces menor.
int? readAmountCents(Map<String, dynamic> data) {
  final cents = _asInt(data['amountCents']);
  if (cents != null) return cents;
  final soles = _asInt(data['amountPesos']);
  return soles == null ? null : soles * centsPerSol;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
