class NetworkInfo {
  final String name;
  final String code;
  final List<String> prefixes;

  const NetworkInfo({
    required this.name,
    required this.code,
    required this.prefixes,
  });
}

class ValidationResult {
  final bool isValid;
  final String? number;
  final String? formattedNumber;
  final NetworkInfo? network;
  final String? error;

  const ValidationResult({
    required this.isValid,
    this.number,
    this.formattedNumber,
    this.network,
    this.error,
  });

  @override
  String toString() {
    return 'ValidationResult{isValid: $isValid, number: $number, formattedNumber: $formattedNumber, network: ${network?.name}, error: $error}';
  }
}

class NigerianNetworkData {
  static const List<NetworkInfo> networks = [
    NetworkInfo(
      name: 'MTN',
      code: 'MTN',
      prefixes: [
        '703',
        '706',
        '803',
        '806',
        '810',
        '813',
        '814',
        '816',
        '903',
        '906',
        '704'
            '0703',
        '0706',
        '0803',
        '0806',
        '0810',
        '0813',
        '0814',
        '0816',
        '0903',
        '0906',
        '7047',
        '0704',
      ],
    ),
    NetworkInfo(
      name: 'Glo',
      code: 'GLO',
      prefixes: [
        '705',
        '805',
        '807',
        '811',
        '815',
        '905',
        '0705',
        '0805',
        '0807',
        '0811',
        '0815',
        '0905',
      ],
    ),
    NetworkInfo(
      name: 'Airtel',
      code: 'AIRTEL',
      prefixes: [
        '701',
        '708',
        '802',
        '808',
        '812',
        '902',
        '907',
        '0701',
        '0708',
        '0802',
        '0808',
        '0812',
        '0902',
        '0907',
      ],
    ),
    NetworkInfo(
      name: '9mobile',
      code: '9MOBILE',
      prefixes: [
        '809',
        '817',
        '818',
        '909',
        '908',
        '0809',
        '0817',
        '0818',
        '0909',
        '0908',
      ],
    ),
  ];
}
