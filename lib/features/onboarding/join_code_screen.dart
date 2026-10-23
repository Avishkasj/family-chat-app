import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/extension.dart';
import '../../services/discovery_service.dart';
import '../../shared/crypto.dart';
import '../../shared/handshake.dart';
import '../../shared/protocol.dart';
import '../../widgets/profile_photo_picker.dart';

class JoinCodeScreen extends ConsumerStatefulWidget {
  const JoinCodeScreen({required this.hub, super.key});

  final DiscoveredHub hub;

  @override
  ConsumerState<JoinCodeScreen> createState() => _JoinCodeScreenState();
}

class _JoinCodeScreenState extends ConsumerState<JoinCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  Uint8List? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final l10n = context.l10n;
    final services = ref.read(appServicesProvider);
    final hub = widget.hub;
    final code = normalizeInviteCode(_code.text);
    try {
      // Verify the code before saving anything.
      final connection = await connectToHub(
        host: hub.host,
        port: hub.port,
        inviteCode: code,
        keys: services.keys,
        expectedFamilyId: hub.familyId,
      );
      await connection.channel.close();
      await services.chat.updateProfile(name: _name.text, avatar: _photo);
      await services.chat.configure(
        host: hub.host,
        port: hub.port,
        familyId: hub.familyId,
        familyName: hub.familyName,
        inviteCode: code,
        isHubOwner: false,
      );
      await services.notifications.requestPermission();
      // The router redirects to the chats once configured.
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final message = switch (e) {
        HubAuthException(reason: AuthFailure.badCode) => l10n.wrongInviteCode,
        HubAuthException(reason: AuthFailure.removed) => l10n.removedFromFamily,
        _ => l10n.joinFailed,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinFamilyNamed(widget.hub.familyName))),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
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
              const SizedBox(height: 16),
              Text(l10n.enterInviteCode, style: context.textTheme.bodyMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                style: context.textTheme.titleMedium?.copyWith(
                  letterSpacing: 2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  labelText: l10n.inviteCode,
                  hintText: 'ABCD-EFGH-JKMN-PQRS',
                  prefixIcon: const Icon(Icons.key_rounded),
                ),
                validator: (v) =>
                    isValidInviteCode(v ?? '') ? null : l10n.inviteCodeInvalid,
                onFieldSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _join,
                child: _busy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(l10n.joining),
                        ],
                      )
                    : Text(l10n.joinAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
