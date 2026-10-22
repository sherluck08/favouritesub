import 'package:flutter/material.dart';

class BrandConfig {
  const BrandConfig({
    required this.appName,
    required this.domain,
    required this.seedColor,
    required this.logoAsset,
  });

  final String appName;

  final String domain; // e.g. https://favouritesub.com

  final Color seedColor;

  /// Packaged app logo used by portable branded surfaces such as receipts.
  final String logoAsset;
}

class Brand {
  static BrandConfig current = const BrandConfig(
    appName: 'favouritesub',
    domain: 'https://favouritesub.com',
    seedColor: Color(0xFF490000),
    logoAsset: 'assets/images/Logo_2.png',
  );

  static Color get primary => Color(0xFF490000);

  static ColorScheme colorScheme({Brightness brightness = Brightness.light}) {
    return ColorScheme.fromSeed(
      seedColor: Color(0xFF490000),
      brightness: brightness,
    );
  }

  static withOpacity(double d) {}
}
