import 'package:flutter/material.dart';

String formatNigerianNumber(String number) {
  number = number.replaceAll(' ', '').replaceAll('-', '');

  if (number.startsWith('+234')) {
    return '0${number.substring(4)}';
  } else if (number.startsWith('234')) {
    return '0${number.substring(3)}';
  } else if (number.startsWith('0')) {
    return number;
  }

  return number;
}

class Utils {
  static String logoFor(String network) {
    final n = network.toLowerCase();
    if (n.contains('mtn')) {
      return 'assets/images/mtn_logo.png';
    } else if (n.contains('airtel')) {
      return 'assets/images/airtel_logo.png';
    } else if (n.contains('glo')) {
      return 'assets/images/glo_logo.png';
    } else if (n.contains('9mobile') || n.contains('etisalat')) {
      return 'assets/images/9mobile_logo.png';
    } else {
      return 'assets/images/mtn_logo.png';
    }
  }

  static String getNetworkName(String networkId) {
    switch (networkId) {
      case "1":
        return "MTN";
      case "2":
        return "GLO";
      case "3":
        return "AIRTEL";
      case "6":
        return "9MOBILE";
      default:
        return "Unknown";
    }
  }

  static String getAssetForCable(String name) {
    final n = name.toLowerCase();
    if (n.contains('start')) {
      return 'assets/images/startimes_logo.png';
    } else if (n.contains('go')) {
      return 'assets/images/gotv_logo.png';
    } else if (n.contains('dst')) {
      return 'assets/images/dstv_logo.png';
    } else {
      return 'assets/images/startimes_logo.png';
    }
  }

  static String getAssetForElectricity(String name) {
    final n = name.toLowerCase();
    if (n.contains('abuja')) {
      return 'assets/images/abuja_electric.png';
    } else if (n.contains('eko')) {
      return 'assets/images/eko_electric.png';
    } else if (n.contains('ibadan')) {
      return 'assets/images/ibadan_electric.png';
    } else if (n.contains('ikeja')) {
      return 'assets/images/ikeja_electric.png';
    } else if (n.contains('jos')) {
      return 'assets/images/jos_electric.png';
    } else if (n.contains('kaduna')) {
      return 'assets/images/kaduna_electric.png';
    } else if (n.contains('kano')) {
      return 'assets/images/kano_electric.png';
    } else if (n.contains('yola')) {
      return 'assets/images/yola_electric.png';
    } else if (n.contains('benin')) {
      return 'assets/images/benin_electric.png';
    } else if (n.contains('port harcourt')) {
      return 'assets/images/port_harcourt_electric.png';
    } else if (n.contains('enugu')) {
      return 'assets/images/enugu_electric.png';
    }
    return 'assets/images/electricity_logo.png';
  }

  static String getAssetForExam(String name) {
    final n = name.toLowerCase();
    if (n.contains('waec')) {
      return 'assets/images/waec_logo.png';
    } else if (n.contains('neco')) {
      return 'assets/images/neco_logo.png';
    } else {
      return 'assets/images/exam_logo.png';
    }
  }

  static void showErrorModal(String message, BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red[600],
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              "Error",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Dismiss",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static bool isValidPin(String value, {int length = 5}) {
    final trimmed = value.trim();
    if (trimmed.length != length) return false;
    return RegExp(r'^\d+$').hasMatch(trimmed);
  }

  static bool pinsMatch(String a, String b, {int length = 5}) {
    return isValidPin(a, length: length) &&
        isValidPin(b, length: length) &&
        a.trim() == b.trim();
  }
}
