import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:favouritesub/models/app_data.dart';

class AccountCardsList extends StatelessWidget {
  final List<BankAccount> accounts;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double spacing;
  final bool showPlaceholderWhenSingle;

  const AccountCardsList({
    super.key,
    required this.accounts,
    this.padding = const EdgeInsets.only(bottom: 12),
    this.height,
    this.spacing = 12,
    this.showPlaceholderWhenSingle = true,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_CardItem>[];
    for (final a in accounts) {
      items.add(_CardItem(account: a, isPlaceholder: false));
    }
    if (accounts.length == 1 && showPlaceholderWhenSingle) {
      items.add(_CardItem(account: accounts.first, isPlaceholder: true));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = height ?? 148.0;
        final cardWidth = constraints.maxWidth < 380
            ? constraints.maxWidth * 0.84
            : (constraints.maxWidth * 0.62).clamp(280.0, 360.0);

        return SizedBox(
          height: cardHeight + padding.vertical,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 4).add(padding),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(width: spacing),
            itemBuilder: (context, index) {
              final it = items[index];
              return _LiquidGlassAccountCard(
                width: cardWidth,
                height: cardHeight,
                account: it.account,
                isPlaceholder: it.isPlaceholder,
              );
            },
          ),
        );
      },
    );
  }
}

class _CardItem {
  final BankAccount account;
  final bool isPlaceholder;
  _CardItem({required this.account, required this.isPlaceholder});
}

class _LiquidGlassAccountCard extends StatefulWidget {
  final double width;
  final double height;
  final BankAccount account;
  final bool isPlaceholder;

  const _LiquidGlassAccountCard({
    required this.width,
    required this.height,
    required this.account,
    required this.isPlaceholder,
  });

  @override
  State<_LiquidGlassAccountCard> createState() =>
      _LiquidGlassAccountCardState();
}

class _LiquidGlassAccountCardState extends State<_LiquidGlassAccountCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.88),
                        Colors.white.withValues(alpha: 0.76),
                        Colors.white.withValues(alpha: 0.68),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),

                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.white.withValues(alpha: 0.03)),
                ),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.1,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

                Positioned(
                  top: -28,
                  right: -18,
                  child: _blob(Colors.white.withValues(alpha: 0.10), 90),
                ),
                Positioned(
                  bottom: -24,
                  left: -16,
                  child: _blob(Colors.white.withValues(alpha: 0.08), 72),
                ),

                _AccountContent(
                  account: widget.account,
                  placeholder: widget.isPlaceholder,
                  accent: cs.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _AccountContent extends StatelessWidget {
  final BankAccount account;
  final bool placeholder;
  final Color accent;

  const _AccountContent({
    required this.account,
    required this.placeholder,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final bankName = placeholder
        ? '— — —'
        : (account.bankName.isEmpty ? 'Bank' : account.bankName);
    final accountName = placeholder
        ? '— — — — — —'
        : (account.accountName.isEmpty ? 'Account name' : account.accountName);
    final accountNumber = placeholder
        ? '— — — — — — —'
        : (account.accountNumber.isEmpty
              ? 'Account number'
              : account.accountNumber);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance,
                  color: accent.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bankName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accountName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),

          _kv(
            'Account Number',
            accountNumber,
            accent,
            context,
            copyable: !placeholder,
            monospace: true,
          ),
          const SizedBox(height: 6),
          _kv('Bank Name', bankName, accent, context, copyable: false),
        ],
      ),
    );
  }

  Widget _kv(
    String label,
    String value,
    Color accent,
    BuildContext context, {
    bool copyable = true,
    bool monospace = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: monospace ? 'monospace' : null,
                  letterSpacing: monospace ? 0.4 : 0.0,
                ),
              ),
            ],
          ),
        ),
        if (copyable)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied')));
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(
                Icons.copy,
                color: accent.withValues(alpha: 0.9),
                size: 18,
              ),
            ),
          ),
      ],
    );
  }
}
