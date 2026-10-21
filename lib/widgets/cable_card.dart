import 'package:flutter/material.dart';
import '../models/app_data.dart';

class CableCard extends StatelessWidget {
  final Cable cable;
  final bool isSelected;
  final bool dim;
  const CableCard({
    super.key,
    required this.cable,
    this.isSelected = false,
    this.dim = false,
  });

  String _assetForCable(String name) {
    final n = name.toLowerCase();
    if (n.contains('start')) return 'assets/images/startimes_logo.png';
    if (n.contains('go')) return 'assets/images/gotv_logo.png';
    if (n.contains('dst')) return 'assets/images/dstv_logo.png';
    return 'assets/images/startimes_logo.png';
  }

  Color _bgForCable(String name) {
    final n = name.toLowerCase();
    if (n.contains('dst')) return const Color(0xFF00AEEF);
    if (n.contains('go')) return Colors.green.shade200;
    if (n.contains('start')) return Colors.orange.shade200;
    return Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    final img = _assetForCable(cable.name);
    final bg = _bgForCable(cable.name);
    return Stack(
      children: [
        Opacity(
          opacity: dim ? 0.3 : 1.0,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  img,
                  height: 38,
                  width: 38,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cable.name,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        if (isSelected)
          const Positioned(
            top: 0,
            right: 0,
            child: Icon(Icons.check_circle, color: Colors.green, size: 25),
          ),
      ],
    );
  }
}
