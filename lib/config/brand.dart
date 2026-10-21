import 'package:flutter/material.dart';

class BrandConfig {
  const BrandConfig({
    required this.appName,
    required this.domain,
    required this.seedColor,
  });

  final String appName;

  final String domain; // e.g. https://favouritesub.com

  final Color seedColor;
}

class Brand {
  static BrandConfig current = const BrandConfig(
    appName: 'favouritesub',
    domain: 'https://favouritesub.com',
    seedColor: Color(0xFF490000),
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
