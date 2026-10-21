import 'package:flutter/material.dart';
import 'package:favouritesub/models/network.dart';

final imagePath = "assets/images";

final networks = [
  Network(
    id: 1,
    name: "Mtn",
    image: "$imagePath/mtn_logo.png",
    bgColor: Colors.yellow,
  ),
  Network(
    id: 2,
    name: "Glo",
    image: "$imagePath/glo_logo.png",
    bgColor: Color(0xFF53ac46),
  ),
  Network(
    id: 4,
    name: "Airtel",
    image: "$imagePath/airtel_logo.png",
    bgColor: Colors.red.shade100,
  ),
  Network(
    id: 3,
    name: "9mobile",
    image: "$imagePath/9mobile_logo.png",
    bgColor: Colors.green.shade300,
  ),
];
