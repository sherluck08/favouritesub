import 'package:flutter/material.dart';

import '../models/app_data.dart';

final imagePath = "assets/images";

class NetworkCard extends StatelessWidget {
  const NetworkCard({
    super.key,
    required this.network,
    this.isSelected = false,
    this.dim = false,
  });

  final NetworkDef network;
  final bool isSelected;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.transparent;
    if (network.id == 1) {
      bgColor = Colors.yellow;
    } else if (network.id == 2) {
      bgColor = Color(0xFF53ac46);
    } else if (network.id == 4) {
      bgColor = Colors.red.shade100;
    } else if (network.id == 3) {
      bgColor = Colors.green.shade300;
    }

    String image = "";
    if (network.id == 1) {
      image = "assets/images/mtn_logo.png";
    } else if (network.id == 2) {
      image = "assets/images/glo_logo.png";
    } else if (network.id == 4) {
      image = "assets/images/airtel_logo.png";
    } else if (network.id == 3) {
      image = "assets/images/9mobile_logo.png";
    }

    return Stack(
      children: [
        Opacity(
          opacity: dim ? 0.3 : 1.0,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(image, height: 38, width: 38),
              ),
              const SizedBox(height: 6),
              Text(
                network.name,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        if (isSelected)
          Positioned(
            top: 0,
            right: 0,
            child: Icon(Icons.check_circle, color: Colors.green, size: 25),
          ),
      ],
    );
  }
}
