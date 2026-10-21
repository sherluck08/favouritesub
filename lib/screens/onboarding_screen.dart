import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:favouritesub/config/brand.dart';
import 'package:favouritesub/screens/login_screen.dart';
import 'package:favouritesub/screens/signup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _imagesPrecached = false;

  late final AnimationController _entranceController;
  late final Animation<double> _entranceAnimation;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      imagePath: 'assets/images/favouritesub_onboarding_payments.webp',
      eyebrow: 'EVERYDAY ESSENTIALS',
      title: 'Everyday payments,\nmade simple.',
      subtitle:
          'Buy data, top up airtime and settle bills in a few quick taps—wherever your day takes you.',
      badge: 'Data • Airtime • Bills',
      badgeIcon: Icons.bolt_rounded,
      color: Color(0xFFC71920),
      imageAlignment: Alignment(0, -0.1),
    ),
    _OnboardingPage(
      imagePath: 'assets/images/favouritesub_onboarding_security.webp',
      eyebrow: 'PAY WITH CONFIDENCE',
      title: 'Built for your\npeace of mind.',
      subtitle:
          'Secure payments, instant updates and dependable service you can count on every time.',
      badge: 'Safe & reliable',
      badgeIcon: Icons.verified_user_rounded,
      color: Color(0xFF0B9366),
      imageAlignment: Alignment(0, -0.12),
    ),
    _OnboardingPage(
      imagePath: 'assets/images/favouritesub_onboarding_value.webp',
      eyebrow: 'SMARTER EVERY DAY',
      title: 'More value for\nevery naira.',
      subtitle:
          'Enjoy competitive rates on data, airtime, cable TV and electricity—all in one place.',
      badge: 'Better everyday rates',
      badgeIcon: Icons.savings_rounded,
      color: Color(0xFFE46D2A),
      imageAlignment: Alignment(0, -0.08),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_imagesPrecached) return;
    _imagesPrecached = true;
    for (final page in _pages) {
      precacheImage(AssetImage(page.imagePath), context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  void _continue() {
    HapticFeedback.lightImpact();
    if (_currentPage == _pages.length - 1) {
      _goToSignup();
    } else {
      _goToPage(_currentPage + 1);
    }
  }

  void _goToLogin() {
    HapticFeedback.selectionClick();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _goToSignup() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const SignupScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isCompact = MediaQuery.sizeOf(context).height < 720;
    final isDark = theme.brightness == Brightness.dark;
    final page = _pages[_currentPage];
    final background = Color.lerp(
      colors.surface,
      page.color,
      isDark ? 0.13 : 0.055,
    )!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          color: background,
          child: Stack(
            children: [
              _BackgroundGlow(color: page.color, isDark: isDark),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: FadeTransition(
                      opacity: _entranceAnimation,
                      child: Column(
                        children: [
                          _Header(
                            isCompact: isCompact,
                            showSkip: _currentPage != _pages.length - 1,
                            onSkip: _goToLogin,
                          ),
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _pages.length,
                              onPageChanged: (index) {
                                if (index != _currentPage) {
                                  HapticFeedback.selectionClick();
                                }
                                setState(() => _currentPage = index);
                              },
                              itemBuilder: (context, index) {
                                return AnimatedBuilder(
                                  animation: _pageController,
                                  builder: (context, child) {
                                    final position = _pageController.hasClients
                                        ? (_pageController.page ??
                                              _currentPage.toDouble())
                                        : _currentPage.toDouble();
                                    final distance = (position - index)
                                        .abs()
                                        .clamp(0.0, 1.0);
                                    return _OnboardingContent(
                                      page: _pages[index],
                                      isCompact: isCompact,
                                      pageDistance: distance,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          _BottomControls(
                            currentPage: _currentPage,
                            pageCount: _pages.length,
                            accentColor: page.color,
                            isLastPage: _currentPage == _pages.length - 1,
                            isCompact: isCompact,
                            onPageSelected: _goToPage,
                            onContinue: _continue,
                            onLogin: _goToLogin,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isCompact,
    required this.showSkip,
    required this.onSkip,
  });

  final bool isCompact;
  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, isCompact ? 8 : 14, 18, 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Brand.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/images/Logo_2.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Brand.current.appName,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const _NigeriaFlag(),
                    const SizedBox(width: 6),
                    Text(
                      'Built for Nigeria',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AnimatedOpacity(
            opacity: showSkip ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: IgnorePointer(
              ignoring: !showSkip,
              child: TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: colors.onSurfaceVariant,
                  backgroundColor: colors.surface.withValues(alpha: 0.64),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NigeriaFlag extends StatelessWidget {
  const _NigeriaFlag();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: const SizedBox(
        width: 18,
        height: 11,
        child: Row(
          children: [
            Expanded(child: ColoredBox(color: Color(0xFF008751))),
            Expanded(child: ColoredBox(color: Colors.white)),
            Expanded(child: ColoredBox(color: Color(0xFF008751))),
          ],
        ),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow({required this.color, required this.isDark});

  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: isDark ? 0.11 : 0.07),
              ),
            ),
          ),
          Positioned(
            left: -130,
            bottom: 80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: isDark ? 0.12 : 0.07),
                  width: 34,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.currentPage,
    required this.pageCount,
    required this.accentColor,
    required this.isLastPage,
    required this.isCompact,
    required this.onPageSelected,
    required this.onContinue,
    required this.onLogin,
  });

  final int currentPage;
  final int pageCount;
  final Color accentColor;
  final bool isLastPage;
  final bool isCompact;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onContinue;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 6, 24, isCompact ? 12 : 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (index) {
              final active = currentPage == index;
              return GestureDetector(
                onTap: () => onPageSelected(index),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    width: active ? 30 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? accentColor
                          : colors.onSurface.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: isCompact ? 10 : 14),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: Brand.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      isLastPage ? 'Create free account' : 'Continue',
                      key: ValueKey(isLastPage),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Icon(
                    isLastPage
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: isCompact ? 2 : 5),
          TextButton(
            onPressed: onLogin,
            child: Text.rich(
              TextSpan(
                text: 'Already have an account? ',
                children: [
                  TextSpan(
                    text: 'Sign in',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent({
    required this.page,
    required this.isCompact,
    required this.pageDistance,
  });

  final _OnboardingPage page;
  final bool isCompact;
  final double pageDistance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final photoHeight = (constraints.maxHeight * (isCompact ? 0.44 : 0.56))
            .clamp(180.0, 370.0)
            .toDouble();

        return Opacity(
          opacity: 1 - (pageDistance * 0.32),
          child: Transform.scale(
            scale: 1 - (pageDistance * 0.035),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                isCompact ? 8 : 14,
                24,
                isCompact ? 4 : 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: photoHeight,
                    child: _PhotoCard(page: page),
                  ),
                  SizedBox(height: isCompact ? 16 : 24),
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 3,
                        decoration: BoxDecoration(
                          color: page.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        page.eyebrow,
                        style: TextStyle(
                          color: page.color,
                          fontSize: isCompact ? 10 : 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.25,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 7 : 10),
                  Text(
                    page.title,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: isCompact ? 27 : 33,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.9,
                    ),
                  ),
                  SizedBox(height: isCompact ? 7 : 11),
                  Text(
                    page.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: isCompact ? 13.5 : 15,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.14),
            blurRadius: 30,
            spreadRadius: -8,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              page.imagePath,
              fit: BoxFit.cover,
              alignment: page.imageAlignment,
              filterQuality: FilterQuality.medium,
              semanticLabel:
                  'A smiling African man and woman using their phones',
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x08000000),
                    Color(0xB8000000),
                  ],
                  stops: [0.48, 0.68, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 15,
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(page.badgeIcon, color: page.color, size: 17),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              page.badge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF11162A),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF008751),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.imagePath,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeIcon,
    required this.color,
    required this.imageAlignment,
  });

  final String imagePath;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String badge;
  final IconData badgeIcon;
  final Color color;
  final Alignment imageAlignment;
}
