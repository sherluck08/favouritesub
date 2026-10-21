import 'package:flutter/material.dart';
import 'package:favouritesub/services/beneficiary_service.dart';

class RecentBeneficiariesStrip extends StatelessWidget {
  final List<BeneficiaryItem> items;
  final String Function(int networkId) logoForNetwork;
  final ValueChanged<BeneficiaryItem> onTap;

  const RecentBeneficiariesStrip({
    super.key,
    required this.items,
    required this.logoForNetwork,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent beneficiaries',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              return _BeneficiaryTile(
                item: item,
                logo: logoForNetwork(item.networkId),
                onTap: () => onTap(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BeneficiaryTile extends StatelessWidget {
  final BeneficiaryItem item;
  final String logo;
  final VoidCallback onTap;

  const _BeneficiaryTile({
    required this.item,
    required this.logo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: 'Use ${item.phone}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? cs.surfaceContainerHigh
                      : cs.surfaceContainerHighest.withValues(alpha: 0.45),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: isDark ? 0.18 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: logo.isNotEmpty
                      ? Image.asset(logo, fit: BoxFit.contain)
                      : Icon(
                          Icons.phone_android_rounded,
                          color: cs.primary,
                          size: 26,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
