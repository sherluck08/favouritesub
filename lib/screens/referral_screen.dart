import 'package:favouritesub/config/brand.dart';
import 'package:favouritesub/models/referral_member.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/services/referral_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

typedef ReferralLoader = Future<List<ReferralMember>> Function();

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({
    super.key,
    this.loadReferrals = ReferralService.fetchReferrals,
  });

  final ReferralLoader loadReferrals;

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late Future<List<ReferralMember>> _referrals;

  @override
  void initState() {
    super.initState();
    _referrals = widget.loadReferrals();
  }

  Future<void> _refresh() async {
    final request = widget.loadReferrals();
    setState(() => _referrals = request);
    try {
      await Future.wait<void>([
        request.then<void>((_) {}),
        context.read<AppDataProvider>().refresh(),
      ]);
    } catch (_) {
      // FutureBuilder renders the useful retry state for a failed refresh.
    }
  }

  String _referralLink(String username) =>
      '${Brand.current.domain}/signup/?referal=${Uri.encodeQueryComponent(username)}';

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Referral link copied')));
  }

  Future<void> _shareLink(BuildContext context, String link) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      'Join me on ${Brand.current.appName} for fast airtime, data and bill payments. Sign up with my referral link: $link',
      subject: 'Join ${Brand.current.appName}',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppDataProvider>().data;
    final username = appData?.user.username.trim() ?? '';
    final bonus = double.tryParse(appData?.user.bonusBalance ?? '0') ?? 0;
    final link = username.isEmpty
        ? Brand.current.domain
        : _referralLink(username);

    return Scaffold(
      appBar: AppBar(title: const Text('My referrals'), centerTitle: true),
      body: FutureBuilder<List<ReferralMember>>(
        future: _referrals,
        builder: (context, snapshot) {
          final referrals = snapshot.data ?? const <ReferralMember>[];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ReferralHero(
                              count: referrals.length,
                              bonus: bonus,
                            ),
                            const SizedBox(height: 16),
                            _InviteCard(
                              username: username,
                              link: link,
                              onCopy: username.isEmpty
                                  ? null
                                  : () => _copyLink(link),
                              onShare: username.isEmpty
                                  ? null
                                  : (buttonContext) =>
                                        _shareLink(buttonContext, link),
                            ),
                            const SizedBox(height: 24),
                            const _HowItWorks(),
                            const SizedBox(height: 26),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'People you invited',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (snapshot.hasData)
                                  _CountBadge(count: referrals.length),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverToBoxAdapter(child: _ReferralLoading())
                else if (snapshot.hasError)
                  SliverToBoxAdapter(
                    child: _ReferralError(
                      message: snapshot.error.toString(),
                      onRetry: () =>
                          setState(() => _referrals = widget.loadReferrals()),
                    ),
                  )
                else if (referrals.isEmpty)
                  const SliverToBoxAdapter(child: _EmptyReferrals())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: referrals.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 728),
                          child: _ReferralTile(
                            referral: referrals[index],
                            position: index + 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReferralHero extends StatelessWidget {
  const _ReferralHero({required this.count, required this.bonus});

  final int count;
  final double bonus;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            Color.lerp(colors.primary, colors.secondary, 0.35)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.2),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.group_add_rounded,
              color: colors.onPrimary,
              size: 27,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Invite friends. Grow together.',
            style: TextStyle(
              color: colors.onPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Share your personal link and track everyone who joins through you.',
            style: TextStyle(
              color: colors.onPrimary.withValues(alpha: 0.82),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'TOTAL REFERRALS',
                  value: count.toString(),
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: colors.onPrimary.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _HeroStat(
                  label: 'BONUS BALANCE',
                  value: money.format(bonus),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: onPrimary.withValues(alpha: 0.65),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: onPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.username,
    required this.link,
    required this.onCopy,
    required this.onShare,
  });

  final String username;
  final String link;
  final VoidCallback? onCopy;
  final ValueChanged<BuildContext>? onShare;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your referral link',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            username.isEmpty
                ? 'Your referral link is being prepared.'
                : 'Friends who register with this link are added to your referral list.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy link',
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 19),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (buttonContext) => FilledButton.icon(
                onPressed: onShare == null
                    ? null
                    : () => onShare!(buttonContext),
                icon: const Icon(Icons.ios_share_rounded, size: 19),
                label: const Text('Share referral link'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How it works',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 12),
        _Step(
          number: '1',
          title: 'Share your link',
          body: 'Send your personal referral link to friends and family.',
        ),
        _Step(
          number: '2',
          title: 'They create an account',
          body: 'Your username is applied automatically during registration.',
        ),
        _Step(
          number: '3',
          title: 'Track your network',
          body: 'Their account appears here once registration is complete.',
          isLast: true,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final String number;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1, color: colors.outlineVariant),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralTile extends StatelessWidget {
  const _ReferralTile({required this.referral, required this.position});

  final ReferralMember referral;
  final int position;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final joined = referral.joinedAt == null
        ? 'Registered user'
        : 'Joined ${DateFormat('d MMM yyyy').format(referral.joinedAt!)}';
    final initial = referral.username.isEmpty
        ? 'U'
        : referral.username.substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: colors.primary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  referral.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  joined,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '#$position',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$count total',
        style: TextStyle(
          color: colors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReferralLoading extends StatelessWidget {
  const _ReferralLoading();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 728),
          child: Column(
            children: List.generate(
              3,
              (index) => Container(
                height: 72,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyReferrals extends StatelessWidget {
  const _EmptyReferrals();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
        child: Column(
          children: [
            Icon(Icons.people_outline_rounded, size: 44, color: colors.primary),
            const SizedBox(height: 10),
            const Text(
              'Your referral list is waiting',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              'Share your link above. New referrals will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralError extends StatelessWidget {
  const _ReferralError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, color: colors.error, size: 38),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
