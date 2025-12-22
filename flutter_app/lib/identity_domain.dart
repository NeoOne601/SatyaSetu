/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.0 (The Signed Interaction)
 * VERSION: 1.5.0
 * STATUS: STABLE (Functional Mirror)
 */

class SatyaIdentity {
  final String id;
  final String label;
  final String did;

  SatyaIdentity({
    required this.id,
    required this.label,
    required this.did,
  });

  factory SatyaIdentity.fromJson(Map<String, dynamic> json) {
    return SatyaIdentity(
      id: json['id'] as String,
      label: json['label'] as String,
      did: json['did'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'did': did,
  };
}

class UpiIntent {
  final String vpa;
  final String name;
  final String amount;
  final String currency;

  UpiIntent({
    required this.vpa,
    required this.name,
    required this.amount,
    required this.currency,
  });

  factory UpiIntent.fromJson(Map<String, dynamic> json) {
    return UpiIntent(
      vpa: json['vpa'] as String,
      name: json['name'] as String,
      amount: json['amount'] as String,
      currency: json['currency'] as String,
    );
  }
}