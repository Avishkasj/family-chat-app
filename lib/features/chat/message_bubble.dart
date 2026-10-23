import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/extension.dart';
import '../../data/models.dart';
import '../../shared/crypto.dart';
import '../../widgets/member_avatar.dart';
import 'family_actions.dart';

class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    required this.showSender,
    required this.firstInRun,
    super.key,
  });

  final ChatMessage message;
  final bool isMine;
  final bool showSender;
  final bool firstInRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final background = isMine
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    final foreground = isMine ? scheme.onPrimaryContainer : scheme.onSurface;
    final radius = const Radius.circular(18);
    final tail = firstInRun ? const Radius.circular(4) : radius;
    final attachment = message.deleted ? null : message.attachment;
    final text = message.deleted ? null : message.text;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMine ? 56 : 10,
        firstInRun ? 6 : 2,
        isMine ? 10 : 56,
        0,
      ),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showActions(context, ref),
          onTap: message.status == MessageStatus.failed
              ? () => ref.read(chatServiceProvider).retry(message)
              : null,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.only(
                topLeft: isMine ? radius : tail,
                topRight: isMine ? tail : radius,
                bottomLeft: radius,
                bottomRight: radius,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSender && !isMine) _SenderName(message.sender),
                if (message.deleted)
                  _Deleted(color: foreground)
                else if (message.poll != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 280),
                    child: PollCard(message: message, color: foreground),
                  )
                else if (message.call != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 280),
                    child: CallCard(message: message, color: foreground),
                  )
                else if (attachment != null && attachment.isImage)
                  _ImageContent(message: message, attachment: attachment)
                else if (attachment != null)
                  _FileContent(
                    message: message,
                    attachment: attachment,
                    color: foreground,
                  ),
                if (text != null && text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Text(
                      text,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                _Footer(message: message, isMine: isMine, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final chat = ref.read(chatServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!message.deleted && (message.text?.isNotEmpty ?? false))
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(l10n.copyText),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.text!));
                  Navigator.pop(sheetContext);
                  messenger.showSnackBar(SnackBar(content: Text(l10n.copied)));
                },
              ),
            if (message.status == MessageStatus.failed)
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: Text(l10n.retry),
                onTap: () {
                  Navigator.pop(sheetContext);
                  chat.retry(message);
                },
              ),
            if (isMine && !message.deleted)
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: Text(l10n.deleteForEveryone),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    await chat.deleteForEveryone(message);
                  } catch (_) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.notConnectedAction)),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.deleteForMe),
              onTap: () {
                Navigator.pop(sheetContext);
                chat.deleteForMe(message);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SenderName extends ConsumerWidget {
  const _SenderName(this.senderId);
  final String senderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(memberProvider(senderId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Text(
        member?.displayName ?? '',
        style: context.textTheme.labelLarge?.copyWith(
          color: avatarColor(senderId, context.colorScheme),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Deleted extends StatelessWidget {
  const _Deleted({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 16, color: color.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.l10n.messageDeleted,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.message,
    required this.isMine,
    required this.color,
  });

  final ChatMessage message;
  final bool isMine;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final muted = color.withValues(alpha: 0.6);
    final (IconData icon, Color iconColor, String label) =
        switch (message.status) {
          MessageStatus.pending => (
            Icons.schedule_rounded,
            muted,
            context.l10n.sending,
          ),
          MessageStatus.sent => (Icons.done_rounded, muted, ''),
          MessageStatus.failed => (
            Icons.error_outline_rounded,
            context.colorScheme.error,
            context.l10n.failedToSend,
          ),
        };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 10, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMine && label.isNotEmpty) ...[
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(color: iconColor),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            context.formatTime(message.timestamp),
            style: context.textTheme.labelSmall?.copyWith(color: muted),
          ),
          if (isMine) ...[
            const SizedBox(width: 4),
            Icon(icon, size: 14, color: iconColor),
          ],
        ],
      ),
    );
  }
}

Future<void> _download(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    await ref.read(chatServiceProvider).download(message);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.fileFailed)));
  }
}

class _ImageContent extends ConsumerWidget {
  const _ImageContent({required this.message, required this.attachment});

  final ChatMessage message;
  final Attachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = message.localPath;
    final available = path != null && File(path).existsSync();
    final progress = ref.watch(transferProgressProvider)[message.id];
    final width = (attachment.width ?? 1).toDouble();
    final height = (attachment.height ?? 1).toDouble();
    final aspect = (width / height).clamp(0.5, 2.0);
    final thumb = attachment.thumbnail;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    Widget image;
    if (available) {
      image = Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: (280 * dpr).round(),
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    } else if (thumb != null) {
      image = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Image.memory(unb64(thumb), fit: BoxFit.cover),
      );
    } else {
      image = ColoredBox(color: context.colorScheme.surfaceContainerHighest);
    }

    Widget? overlay;
    if (progress != null) {
      overlay = CircularProgressIndicator(
        value: progress == 0 ? null : progress,
        backgroundColor: Colors.black26,
      );
    } else if (!available && message.sender != ref.watch(myIdProvider)) {
      overlay = IconButton.filled(
        style: IconButton.styleFrom(backgroundColor: Colors.black54),
        icon: Icon(
          message.transfer == TransferState.failed
              ? Icons.refresh_rounded
              : Icons.download_rounded,
          color: Colors.white,
        ),
        onPressed: () => _download(context, ref, message),
      );
    }

    return GestureDetector(
      onTap: available ? () => context.push(Routes.viewer, extra: path) : null,
      child: SizedBox(
        width: 280,
        child: AspectRatio(
          aspectRatio: aspect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (overlay != null) Center(child: overlay),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileContent extends ConsumerWidget {
  const _FileContent({
    required this.message,
    required this.attachment,
    required this.color,
  });

  final ChatMessage message;
  final Attachment attachment;
  final Color color;

  IconData get _icon {
    final mime = attachment.mime;
    if (mime.startsWith('video/')) return Icons.movie_outlined;
    if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.contains('zip') || mime.contains('compressed')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.description_outlined;
  }

  Future<void> _open(BuildContext context, String path) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final result = await OpenFilex.open(path, type: attachment.mime);
    if (result.type != ResultType.done) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotOpenFile)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final path = message.localPath;
    final available = path != null && File(path).existsSync();
    final progress = ref.watch(transferProgressProvider)[message.id];

    Widget trailing;
    if (progress != null) {
      trailing = SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(
          value: progress == 0 ? null : progress,
          strokeWidth: 3,
        ),
      );
    } else if (available) {
      trailing = Icon(Icons.open_in_new_rounded, color: color);
    } else {
      trailing = Icon(
        message.transfer == TransferState.failed
            ? Icons.refresh_rounded
            : Icons.download_rounded,
        color: color,
      );
    }

    return InkWell(
      onTap: progress != null
          ? null
          : available
          ? () => _open(context, path)
          : () => _download(context, ref, message),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(_icon, color: color),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    message.transfer == TransferState.failed
                        ? l10n.fileFailed
                        : formatBytes(attachment.size),
                    style: context.textTheme.labelSmall?.copyWith(
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}
