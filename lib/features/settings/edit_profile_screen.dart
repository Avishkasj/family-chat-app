import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/extension.dart';
import '../../widgets/profile_photo_picker.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  Uint8List? _photo;
  bool _photoChanged = false;

  @override
  void initState() {
    super.initState();
    final me = ref.read(meProvider);
    _name = TextEditingController(text: me?.name ?? '');
    _photo = me?.avatar;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(chatServiceProvider)
        .updateProfile(
          name: _name.text,
          avatar: _photoChanged ? _photo : null,
          removeAvatar: _photoChanged && _photo == null,
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProfile),
        actions: [TextButton(onPressed: _save, child: Text(l10n.save))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ProfilePhotoPicker(
                photo: _photo,
                onChanged: (photo) => setState(() {
                  _photo = photo;
                  _photoChanged = true;
                }),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.yourName,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? l10n.nameRequired : null,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.profileVisibility,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
