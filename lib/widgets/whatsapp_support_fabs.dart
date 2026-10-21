import 'dart:async';

import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reusable support actions backed by WebsiteConfiguration.
class WhatsAppSupportFabs extends StatefulWidget {
  const WhatsAppSupportFabs({super.key});

  @override
  State<WhatsAppSupportFabs> createState() => _WhatsAppSupportFabsState();
}

class _WhatsAppSupportFabsState extends State<WhatsAppSupportFabs> {
  static const _whatsAppGreen = Color(0xFF128C4A);
  bool _loadQueued = false;
  _WhatsAppAction? _opening;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadQueued) return;
    _loadQueued = true;
    unawaited(context.read<AppDataProvider>().loadPublicConfig());
  }

  Future<void> _openSupport() async {
    await _runAction(_WhatsAppAction.support, () async {
      final provider = context.read<AppDataProvider>();
      var rawPhone = provider.webconfig?.supportPhoneNumber?.trim() ?? '';
      if (rawPhone.isEmpty) {
        await provider.loadPublicConfig(force: true);
        rawPhone = provider.webconfig?.supportPhoneNumber?.trim() ?? '';
      }

      final digits = _normalisePhone(rawPhone);
      if (digits.isEmpty) {
        _showMessage('WhatsApp contact is not available right now');
        return;
      }
      await _open(
        Uri.parse(
          'https://wa.me/$digits?text=${Uri.encodeComponent('Hello FavoriteSub support, I need some help.')}',
        ),
        failureMessage: 'Could not open WhatsApp',
      );
    });
  }

  Future<void> _openCommunity() async {
    await _runAction(_WhatsAppAction.community, () async {
      final provider = context.read<AppDataProvider>();
      var rawLink = provider.webconfig?.whatsappGroupLink?.trim() ?? '';
      if (rawLink.isEmpty) {
        await provider.loadPublicConfig(force: true);
        rawLink = provider.webconfig?.whatsappGroupLink?.trim() ?? '';
      }

      final target = _normaliseLink(rawLink);
      if (target == null) {
        _showMessage('WhatsApp community is not available right now');
        return;
      }
      await _open(target, failureMessage: 'Could not open WhatsApp community');
    });
  }

  Future<void> _runAction(
    _WhatsAppAction action,
    Future<void> Function() operation,
  ) async {
    if (_opening != null) return;
    setState(() => _opening = action);
    try {
      await operation();
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  Future<void> _open(Uri target, {required String failureMessage}) async {
    final opened = await launchUrl(
      target,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) _showMessage(failureMessage);
  }

  String _normalisePhone(String value) {
    var digits = value.replaceAll(RegExp('[^0-9]'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      digits = '234${digits.substring(1)}';
    } else if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    return digits;
  }

  Uri? _normaliseLink(String value) {
    if (value.isEmpty || value == 'https://wa.me') return null;
    final withScheme =
        value.startsWith('http://') || value.startsWith('https://')
        ? value
        : 'https://$value';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) return null;
    return uri;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'whatsapp_community',
            tooltip: 'Join WhatsApp community',
            onPressed: _opening == null ? _openCommunity : null,
            elevation: 4,
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: _whatsAppGreen,
            child: _opening == _WhatsAppAction.community
                ? const _FabProgress(color: _whatsAppGreen)
                : const Icon(Icons.groups_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'whatsapp_support',
            tooltip: 'Chat with support on WhatsApp',
            onPressed: _opening == null ? _openSupport : null,
            elevation: 5,
            backgroundColor: _whatsAppGreen,
            foregroundColor: Colors.white,
            child: _opening == _WhatsAppAction.support
                ? const _FabProgress(color: Colors.white)
                : const Icon(Icons.chat_rounded),
          ),
        ],
      ),
    );
  }
}

enum _WhatsAppAction { support, community }

class _FabProgress extends StatelessWidget {
  const _FabProgress({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 19,
      height: 19,
      child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
    );
  }
}
