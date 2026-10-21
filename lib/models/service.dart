import 'package:flutter/material.dart';

class Service {
  final String name;
  final IconData icon;
  final List<Color> gradientColors;
  final void Function()? onTap;

  Service({
    required this.name,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });
}
