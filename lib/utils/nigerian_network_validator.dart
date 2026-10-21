import 'package:favouritesub/utils/network_data.dart';

class NigerianNetworkValidator {
  static ValidationResult validateNumber(String phoneNumber) {
    try {
      String cleanedNumber = _cleanPhoneNumber(phoneNumber);

      if (!_isValidBasicFormat(cleanedNumber)) {
        return ValidationResult(
          isValid: false,
          error: 'Invalid phone number format',
        );
      }

      String prefix = _extractPrefix(cleanedNumber);
      print(prefix);

      NetworkInfo? network = _findNetworkByPrefix(prefix);
      print(network?.name);
      if (network == null) {
        return ValidationResult(
          isValid: false,
          error: 'Unknown network for prefix: $prefix',
        );
      }

      String formattedNumber = _formatNumber(cleanedNumber);

      return ValidationResult(
        isValid: true,
        number: cleanedNumber,
        formattedNumber: formattedNumber,
        network: network,
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        error: 'Error validating number: $e',
      );
    }
  }

  static NetworkInfo? getNetworkByPrefix(String prefix) {
    return _findNetworkByPrefix(prefix);
  }

  static List<NetworkInfo> getAvailableNetworks() {
    return NigerianNetworkData.networks;
  }

  static String _cleanPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  }

  static bool _isValidBasicFormat(String number) {
    if (number.startsWith('+234')) {
      number = number.substring(4);
    } else if (number.startsWith('234')) {
      number = number.substring(3);
    }

    if (number.length == 11 && number.startsWith('0')) {
      return true;
    } else if (number.length == 10 && !number.startsWith('0')) {
      return true;
    }

    return false;
  }

  static String _extractPrefix(String number) {
    if (number.startsWith('+234')) {
      number = number.substring(4);
    } else if (number.startsWith('234')) {
      number = number.substring(3);
    }

    if (!number.startsWith('0') && number.length == 10) {
      number = '0$number';
    }

    String fourDigitPrefix = number.substring(0, 4);

    String threeDigitPrefix = number.substring(0, 3);

    for (var network in NigerianNetworkData.networks) {
      if (network.prefixes.contains(fourDigitPrefix)) {
        return fourDigitPrefix;
      }
    }

    return threeDigitPrefix;
  }

  static NetworkInfo? _findNetworkByPrefix(String prefix) {
    for (var network in NigerianNetworkData.networks) {
      if (network.prefixes.contains(prefix)) {
        return network;
      }
    }
    return null;
  }

  static String _formatNumber(String number) {
    if (number.startsWith('+234')) {
      return number;
    } else if (number.startsWith('234')) {
      return '+$number';
    } else if (number.startsWith('0')) {
      return '+234${number.substring(1)}';
    } else {
      return '+234$number';
    }
  }
}
