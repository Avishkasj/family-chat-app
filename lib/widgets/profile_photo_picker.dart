import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/providers.dart';
import '../core/theme/extension.dart';

/// Lets the user choose a small profile photo (kept on-device and shared
/// only with the family, encrypted).
class ProfilePhotoPicker extends StatelessWidget {
  const ProfilePhotoPicker({
    required this.photo,
    required this.onChanged,
    super.key,
    this.radius = 52,
  });

  final Uint8List? photo;
  final ValueChanged<Uint8List?> onChanged;
  final double radius;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final lock = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(appLockProvider);
    final image = await lock.whileExternal(
      () => ImagePicker().pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.front,
      ),
    );
    if (image == null) return;
    onChanged(await image.readAsBytes());
  }

  Future<void> _showOptions(BuildContext context) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGallery),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(context, ImageSource.gallery);
              },
            ),
            if (photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.removePhoto),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onChanged(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final image = photo;
    return Semantics(
      button: true,
      label: image == null ? context.l10n.addPhoto : context.l10n.changePhoto,
      child: GestureDetector(
        onTap: () => _showOptions(context),
        child: Stack(
          children: [
            CircleAvatar(
              radius: radius,
              backgroundColor: scheme.primaryContainer,
              backgroundImage: image == null ? null : MemoryImage(image),
              child: image == null
                  ? Icon(
                      Icons.person_rounded,
                      size: radius,
                      color: scheme.onPrimaryContainer,
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: radius * 0.32,
                backgroundColor: scheme.primary,
                child: Icon(
                  Icons.photo_camera,
                  size: radius * 0.32,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
