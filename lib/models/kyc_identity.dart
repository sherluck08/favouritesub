import 'package:flutter/foundation.dart';

enum IdentityType { bvn, nin }

class KycIdentityData {
  final String fullName;
  final IdentityType type;
  final String identityNumber;

  const KycIdentityData({
    required this.fullName,
    required this.type,
    required this.identityNumber,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'type': describeEnum(type),
    'identityNumber': identityNumber,
  };
}
