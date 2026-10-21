import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../providers/app_data_provider.dart';
import '../widgets/my_textfield.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:favouritesub/widgets/primary_result_sheet.dart';
import 'package:favouritesub/services/edit_profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = Provider.of<ProfileProvider>(context, listen: false);
    final app = Provider.of<AppDataProvider>(context, listen: false);
    final user = app.data?.user;
    _name.text =
        (user?.fullName?.trim().isNotEmpty == true
                ? user!.fullName!
                : (p.fullName ?? ''))
            .trim();
    _phone.text =
        (user?.phone?.trim().isNotEmpty == true
                ? user!.phone!
                : (p.phone ?? ''))
            .trim();
    _address.text = (p.address ?? '').trim();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: LoaderOverlay(
        overlayColor: const Color.fromRGBO(0, 0, 0, 0.08),
        overlayWidgetBuilder: (_) => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                MyTextfield(textController: _name, hintText: 'Full name'),
                const SizedBox(height: 12),
                MyTextfield(
                  textController: _phone,
                  hintText: 'Phone',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                MyTextfield(textController: _address, hintText: 'Address'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    context.loaderOverlay.show();
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final address = _address.text.trim();

    if (name.isEmpty || phone.isEmpty || address.isEmpty) {
      context.loaderOverlay.hide();
      setState(() => _saving = false);
      await showPrimaryResultSheet(
        context,
        title: 'Incomplete',
        message: 'Please fill all fields',
        icon: Icons.error_outline,
        color: Colors.redAccent,
      );
      return;
    }
    try {
      final res = await EditProfileService.updateProfile(
        fullName: name,
        phone: phone,
        address: address,
      );
      if (!mounted) return;
      context.loaderOverlay.hide();
      setState(() => _saving = false);
      final err = res['error']?.toString();
      if (err != null && err.isNotEmpty) {
        await showPrimaryResultSheet(
          context,
          title: 'Update failed',
          message: err,
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
        return;
      }

      await Provider.of<ProfileProvider>(
        context,
        listen: false,
      ).update(fullName: name, phone: phone, address: address);
      await showPrimaryResultSheet(
        context,
        title: 'Profile updated',
        message:
            res['message']?.toString() ??
            'Your profile has been updated successfully.',
        icon: Icons.check_circle,
        color: Colors.green,
        primaryButtonLabel: 'Done',
        onPrimaryPressed: () => Navigator.pop(context),
      );
    } catch (e) {
      if (!mounted) return;
      context.loaderOverlay.hide();
      setState(() => _saving = false);
      await showPrimaryResultSheet(
        context,
        title: 'Update failed',
        message: e.toString().replaceFirst('Exception: ', ''),
        icon: Icons.error_outline,
        color: Colors.redAccent,
      );
    }
  }
}
