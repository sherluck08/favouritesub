import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final double size;
  const ProfileAvatar({
    super.key,
    this.imageUrl,
    required this.initials,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: Colors.white, width: 3);
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.2),
        backgroundImage: NetworkImage(imageUrl!),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        border: border,
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: size * 0.35,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
