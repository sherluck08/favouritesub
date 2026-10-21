import 'package:flutter/material.dart';
import 'package:favouritesub/widgets/bank_card.dart';
import 'package:provider/provider.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/models/app_data.dart';
import 'package:favouritesub/services/virtual_account_service.dart';
import 'package:favouritesub/widgets/kyc_identity_sheet.dart';
import 'package:favouritesub/models/kyc_identity.dart';
import 'package:favouritesub/providers/profile_provider.dart';
import 'package:loader_overlay/loader_overlay.dart';

class AutomatedFundingScreen extends StatefulWidget {
  const AutomatedFundingScreen({super.key});

  @override
  State<AutomatedFundingScreen> createState() => _AutomatedFundingScreenState();
}

class _AutomatedFundingScreenState extends State<AutomatedFundingScreen> {
  bool _creating = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppDataProvider>().refresh();
    });
  }

  Future<void> _createVirtualAccount() async {
    if (_creating) return;

    final app = Provider.of<AppDataProvider>(context, listen: false).data;
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    await showKycIdentitySheet<void>(
      context,
      initialFullName:
          profile.fullName ?? app?.user.fullName ?? app?.user.username,
      onSubmit: (data) async {
        context.loaderOverlay.show();
        setState(() => _creating = true);
        try {
          final generateType = data.type == IdentityType.bvn ? 'bvn' : 'nin';
          final res =
              await VirtualAccountService.verifyAndGenerateVirtualAccount(
                vNum: data.identityNumber,
                generateType: generateType,
                fullName: data.fullName,
              );
          final status = (res['status'] ?? '').toString();
          final msg = (res['msg'] ?? '').toString();

          if (status == 'successful') {
            try {
              await VirtualAccountService.createVirtualAccount(
                vNum: data.identityNumber,
                generateType: generateType,
              );
            } catch (_) {}
            if (mounted) {
              await Provider.of<AppDataProvider>(
                context,
                listen: false,
              ).refresh();
            }
            if (mounted) context.loaderOverlay.hide();
            if (!mounted) return Future.value();
            _showSuccessSheet(
              message: msg.isEmpty
                  ? 'Virtual account generated successfully'
                  : msg,
            );
          } else {
            if (mounted) context.loaderOverlay.hide();
            if (mounted) {
              _showFailureSheet(
                message: msg.isEmpty
                    ? 'Unable to generate account, please contact admin'
                    : msg,
              );
            }
          }
        } catch (e) {
          if (mounted) context.loaderOverlay.hide();
          if (mounted) {
            _showFailureSheet(
              message: e.toString().replaceFirst('Exception: ', ''),
            );
          }
        } finally {
          if (mounted) setState(() => _creating = false);
        }
        return Future.value();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context, listen: true);
    final banks = appData.data?.user.accounts ?? const <BankAccount>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Automated Funding'), centerTitle: true),
      body: LoaderOverlay(
        overlayColor: const Color.fromRGBO(128, 0, 128, 0.1),
        overlayWidgetBuilder: (context) => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: Builder(
          builder: (context) {
            if (banks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_balance,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No virtualaccount found yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generate an account to fund your wallet instantly.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 240,
                        child: ElevatedButton(
                          onPressed: _creating ? null : _createVirtualAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _creating ? 'Generating...' : 'Generate account',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: banks.length,
              itemBuilder: (context, index) {
                final bank = banks[index];
                return BankCard(bank: bank, useLightBrandStyle: true);
              },
            );
          },
        ),
      ),
    );
  }

  void _showSuccessSheet({required String message}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Account Generated',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Great!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFailureSheet({required String message}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 32),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Verification Failed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
