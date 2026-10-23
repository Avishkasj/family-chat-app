import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/router/routes.dart';
import '../../core/theme/extension.dart';
import '../../widgets/profile_photo_picker.dart';

class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _family = TextEditingController();
  Uint8List? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _family.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final services = ref.read(appServicesProvider);
    final router = ref.read(routerProvider);
    try {
      await services.chat.updateProfile(name: _name.text, avatar: _photo);
      await services.createFamily(familyName: _family.text.trim());
      await services.notifications.requestPermission();
      router
        ..go(Routes.home)
        ..push('${Routes.hub}?first=1');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.hubError('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createFamilyTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                l10n.createFamilyBody,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ProfilePhotoPicker(
                  photo: _photo,
                  onChanged: (photo) => setState(() => _photo = photo),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: l10n.yourName,
                  hintText: l10n.yourNameHint,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.nameRequired : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _family,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: l10n.familyName,
                  hintText: l10n.familyNameHint,
                  prefixIcon: const Icon(Icons.home_outlined),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.familyNameRequired : null,
                onFieldSubmitted: (_) => _create(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(l10n.creating),
                        ],
                      )
                    : Text(l10n.createAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
