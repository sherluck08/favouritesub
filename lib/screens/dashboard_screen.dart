import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/screens/new_home_screen.dart';
import 'package:favouritesub/screens/profile_screen.dart';
import 'package:favouritesub/screens/transaction_screen.dart';
import 'package:favouritesub/screens/wallet_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _destinations = [
    _NavigationDestination(
      label: 'Home',
      tooltip: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavigationDestination(
      label: 'History',
      tooltip: 'Transactions',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
    ),
    _NavigationDestination(
      label: 'Wallet',
      tooltip: 'Wallet summary',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
    ),
    _NavigationDestination(
      label: 'Profile',
      tooltip: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  late final List<Widget> _pages;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pages = const [
      NewHomeScreen(),
      TransactionScreen(),
      WalletSummaryScreen(),
      ProfileScreen(),
    ];
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) {
      if (index == 0) {
        context.read<AppDataProvider>().silentRefresh();
      }
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);

    if (index == 0) {
      context.read<AppDataProvider>().silentRefresh();
    }
  }

  void _returnHome() {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = 0);
    context.read<AppDataProvider>().silentRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedIndex != 0) _returnHome();
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _pages),
        bottomNavigationBar: _ModernNavigationBar(
          destinations: _destinations,
          selectedIndex: _selectedIndex,
          onSelected: _selectDestination,
        ),
      ),
    );
  }
}

class _NavigationDestination {
  const _NavigationDestination({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String tooltip;
  final IconData icon;
  final IconData selectedIcon;
}

class _ModernNavigationBar extends StatelessWidget {
  const _ModernNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              height: 68,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: dark
                    ? colors.surfaceContainerHigh
                    : const Color(0xFFFCFAFA),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: colors.outlineVariant.withValues(
                    alpha: dark ? 0.3 : 0.55,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.16 : 0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 340;
                  return Row(
                    children: [
                      for (var index = 0; index < destinations.length; index++)
                        Expanded(
                          child: _NavigationItem(
                            destination: destinations[index],
                            selected: index == selectedIndex,
                            compact: compact,
                            onTap: () => onSelected(index),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final _NavigationDestination destination;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onPrimary
        : colors.onSurfaceVariant.withValues(alpha: 0.85);

    return Semantics(
      selected: selected,
      button: true,
      label: destination.tooltip,
      child: Tooltip(
        message: destination.tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: selected ? colors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.06 : 1,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        selected ? destination.selectedIcon : destination.icon,
                        color: foreground,
                        size: compact ? 20 : 21,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        color: foreground,
                        fontSize: compact ? 9 : 10,
                        height: 1.1,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        letterSpacing: selected ? -0.1 : 0,
                      ),
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
