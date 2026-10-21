import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:favouritesub/models/kyc_identity.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/providers/profile_provider.dart';
import 'package:favouritesub/widgets/my_textfield.dart';

Future<T?> showKycIdentitySheet<T>(
  BuildContext context, {
  String? initialFullName,
  Future<T> Function(KycIdentityData data)? onSubmit,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) =>
        _KycIdentitySheet(initialFullName: initialFullName, onSubmit: onSubmit),
  );
}

class _KycIdentitySheet extends StatefulWidget {
  final String? initialFullName;
  final Future Function(KycIdentityData data)? onSubmit;

  const _KycIdentitySheet({
    required this.initialFullName,
    required this.onSubmit,
  });

  @override
  State<_KycIdentitySheet> createState() => _KycIdentitySheetState();
}

class _KycIdentitySheetState extends State<_KycIdentitySheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _dobCtrl = TextEditingController();

  IdentityType _type = IdentityType.bvn;
  // Reserved for the DOB field when identity providers require it.
  // ignore: unused_field
  DateTime? _dob;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    final app = Provider.of<AppDataProvider>(context, listen: false).data;
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    final fromProvider =
        profile.fullName ?? app?.user.fullName ?? app?.user.username;
    _nameCtrl.text = widget.initialFullName ?? (fromProvider ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  bool get _isValid {
    final nameOk = _nameCtrl.text.trim().isNotEmpty;
    final id = _idCtrl.text.trim();
    final int requiredLen = 11;
    final idOk = id.length == requiredLen;

    return nameOk && idOk && !_submitting;
  }

  // Reserved for identity providers that require date of birth.
  // ignore: unused_element
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(now.year - 120, 1, 1);
    final last = DateTime(now.year - 10, 12, 31);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (selected != null) {
      setState(() {
        _dob = selected;
        _dobCtrl.text = _fmtDate(selected);
      });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _handleSubmit() async {
    if (!_isValid) return;
    setState(() => _submitting = true);
    final data = KycIdentityData(
      fullName: _nameCtrl.text.trim(),
      type: _type,
      identityNumber: _idCtrl.text.trim(),
    );
    try {
      if (widget.onSubmit != null) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        await widget.onSubmit!(data);
      } else {
        if (mounted) Navigator.of(context).pop(data);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Identity Verification',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Verify your identity to create a virtual account',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoBanner(),
                const SizedBox(height: 16),
                Text(
                  'Full Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                MyTextfield(
                  textController: _nameCtrl,
                  hintText: 'As shown on your ID',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Identity Type',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                _TypeSelector(
                  selected: _type,
                  onChanged: (val) {
                    setState(() {
                      _type = val;
                      _idCtrl.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Identity Number',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                MyTextfield(
                  textController: _idCtrl,
                  hintText: _type == IdentityType.bvn
                      ? 'Enter 11-digit BVN'
                      : 'Enter 11-digit NIN',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _idCtrl.text.isEmpty
                        ? 'Must be 11 digits'
                        : (_idCtrl.text.length == 11
                              ? 'Looks good'
                              : 'Still ${11 - _idCtrl.text.length} digits to go'),
                    style: TextStyle(
                      fontSize: 12,
                      color: _idCtrl.text.length == 11
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValid ? _handleSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isValid
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Proceed'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final IdentityType selected;
  final ValueChanged<IdentityType> onChanged;
  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _Choice(
              label: 'BVN',
              icon: Icons.shield_outlined,
              selected: selected == IdentityType.bvn,
              onTap: () => onChanged(IdentityType.bvn),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Choice(
              label: 'NIN',
              icon: Icons.badge,
              selected: selected == IdentityType.nin,
              onTap: () => onChanged(IdentityType.nin),
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Choice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info_outline, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Please provide valid information. Verification is limited to 3 attempts daily. Repeated invalid attempts may lead to restrictions.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
