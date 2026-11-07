import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';

final class Movement {
  const Movement({
    required this.id,
    required this.vendorUid,
    required this.clientId,
    required this.kind,
    required this.amountCents,
    required this.occurredAt,
    required this.createdAt,
    this.pendingSync = true,
    this.voided = false,
  });

  final String id;
  final String vendorUid;
  final String clientId;
  final MovementKind kind;
  final int amountCents;
  final DateTime occurredAt;
  final DateTime createdAt;
  final bool pendingSync;
  final bool voided;

  int get signedCents {
    if (voided) return 0;
    return kind == MovementKind.fiado ? amountCents : -amountCents;
  }

  Movement copyWith({
    MovementKind? kind,
    int? amountCents,
    DateTime? occurredAt,
    bool? pendingSync,
    bool? voided,
  }) {
    return Movement(
      id: id,
      vendorUid: vendorUid,
      clientId: clientId,
      kind: kind ?? this.kind,
      amountCents: amountCents ?? this.amountCents,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt,
      pendingSync: pendingSync ?? this.pendingSync,
      voided: voided ?? this.voided,
    );
  }
}
