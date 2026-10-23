import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/extension.dart';
import '../../data/models.dart';
import '../../demo/demo_mode.dart';
import '../../services/chat_service.dart';
import '../../shared/protocol.dart';
import '../../widgets/connection_banner.dart';
import '../../widgets/member_avatar.dart';
import 'family_actions.dart';
import 'message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _pageSize = 60;

  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final ChatService _chat;
  int _limit = _pageSize;

  @override
  void initState() {
    super.initState();
    _chat = ref.read(chatServiceProvider);
    _chat.activeConversationId = widget.conversationId;
    _chat.markRead(widget.conversationId);
    _scroll.addListener(_onScroll);
    if (kDemoMode && demoConfig?.sheet == 'actions') {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showFamilyActionsSheet(context, ref, widget.conversationId),
      );
    }
  }

  @override
  void dispose() {
    if (_chat.activeConversationId == widget.conversationId) {
      _chat.activeConversationId = null;
    }
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // The list is reversed: maxScrollExtent is the oldest message.
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      final total = ref.read(databaseProvider).messageCount(
        widget.conversationId,
      );
      if (_limit < total) setState(() => _limit += _pageSize);
    }
  }

  void _send() {
    final text = _text.text;
    if (text.trim().isEmpty) return;
    _text.clear();
    unawaited(_chat.sendText(widget.conversationId, text));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendFiles(Future<void> Function() action) async {
    try {
      // Pickers briefly leave the app; don't trigger the app lock.
      await ref.read(appLockProvider).whileExternal(action);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.somethingWentWrong('$e'))),
      );
    }
  }

  Future<void> _pickPhotos() => _sendFiles(() async {
    final images = await ImagePicker().pickMultiImage(
      maxWidth: 2560,
      maxHeight: 2560,
      imageQuality: 85,
    );
    for (final image in images) {
      await _chat.sendFile(
        widget.conversationId,
        File(image.path),
        name: image.name,
        asImage: true,
      );
    }
  });

  Future<void> _takePhoto() => _sendFiles(() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2560,
      maxHeight: 2560,
      imageQuality: 85,
    );
    if (image == null) return;
    await _chat.sendFile(
      widget.conversationId,
      File(image.path),
      name: image.name,
      asImage: true,
    );
  });

  Future<void> _pickFiles() => _sendFiles(() async {
    final files = await FilePicker.pickFiles();
    for (final picked in files) {
      final size = await picked.length() ?? 0;
      if (size > kMaxFileSize) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.fileTooLarge(picked.name))),
          );
        }
        continue;
      }
      var path = picked.path;
      File? temp;
      if (path == null) {
        // Content URIs (Android): copy to a temporary file first.
        final dir = await getTemporaryDirectory();
        temp = File(p.join(dir.path, 'pick_${DateTime.now().microsecondsSinceEpoch}'));
        final sink = temp.openWrite();
        await sink.addStream(picked.readAsByteStream());
        await sink.close();
        path = temp.path;
      }
      try {
        await _chat.sendFile(
          widget.conversationId,
          File(path),
          name: picked.name,
        );
      } finally {
        if (temp != null && temp.existsSync()) temp.deleteSync();
      }
    }
  });

  void _showAttachSheet() {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachOption(
                icon: Icons.photo_library_rounded,
                label: l10n.attachPhoto,
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhotos();
                },
              ),
              _AttachOption(
                icon: Icons.photo_camera_rounded,
                label: l10n.attachCamera,
                color: Colors.pink,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _takePhoto();
                },
              ),
              _AttachOption(
                icon: Icons.poll_rounded,
                label: l10n.poll,
                color: Colors.teal,
                onTap: () {
                  Navigator.pop(sheetContext);
                  showPollComposer(context, ref, widget.conversationId);
                },
              ),
              _AttachOption(
                icon: Icons.insert_drive_file_rounded,
                label: l10n.attachFile,
                color: Colors.indigo,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickFiles();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = widget.conversationId;
    final conversation = ref.watch(conversationProvider(id));
    final me = ref.watch(myIdProvider);
    final messages = ref.watch(
      messagesProvider((conversationId: id, limit: _limit)),
    );

    // Keep the conversation marked as read while it's open.
    ref.listen(conversationProvider(id), (previous, next) {
      if ((next?.unread ?? 0) > 0) _chat.markRead(id);
    });

    if (conversation == null) {
      return Scaffold(appBar: AppBar());
    }
    final isGroup = conversation.type == ConversationType.group;
    final canSend = !isGroup || conversation.members.contains(me);
    final showSenders = conversation.type != ConversationType.direct;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => context.push(Routes.chatInfo(id)),
          child: Row(
            children: [
              ConversationAvatar(conversation: conversation, radius: 20),
              const SizedBox(width: 12),
              Expanded(child: _ChatTitle(conversation: conversation)),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: isGroup || conversation.isFamily
                ? l10n.groupInfo
                : l10n.contactInfo,
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => context.push(Routes.chatInfo(id)),
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      l10n.emptyChat,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final i = messages.length - 1 - index;
                      final message = messages[i];
                      final previous = i > 0 ? messages[i - 1] : null;
                      final newDay =
                          previous == null ||
                          !isSameDay(previous.timestamp, message.timestamp);
                      final firstInRun =
                          newDay || previous.sender != message.sender;
                      return Column(
                        children: [
                          if (newDay) _DaySeparator(message.timestamp),
                          MessageBubble(
                            message: message,
                            isMine: message.sender == me,
                            showSender: showSenders && firstInRun,
                            firstInRun: firstInRun,
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (canSend)
            _Composer(
              controller: _text,
              onSend: _send,
              onAttach: _showAttachSheet,
              onQuickActions: () => showFamilyActionsSheet(context, ref, id),
              onTyping: () => _chat.notifyTyping(id),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.leftGroup,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatTitle extends ConsumerWidget {
  const _ChatTitle({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(myIdProvider);
    final title = ref.watch(conversationTitleProvider(conversation.id));
    final typing = ref.watch(typingProvider)[conversation.id] ?? const {};
    final online = ref.watch(onlineProvider);

    String subtitle;
    var highlight = false;
    if (typing.isNotEmpty) {
      highlight = true;
      if (conversation.type == ConversationType.direct) {
        subtitle = l10n.typing;
      } else if (typing.length == 1) {
        final name =
            ref.watch(memberProvider(typing.first))?.displayName ?? '';
        subtitle = l10n.typingOne(name);
      } else {
        subtitle = l10n.typingMany;
      }
    } else if (conversation.type == ConversationType.direct) {
      final peer = conversation.peerOf(me);
      if (peer != null && online.contains(peer)) {
        subtitle = l10n.online;
        highlight = true;
      } else {
        subtitle = context.formatLastSeen(
          peer == null ? null : ref.watch(memberProvider(peer))?.lastSeen,
        );
      }
    } else {
      final count = conversation.type == ConversationType.family
          ? ref.watch(familyMembersProvider).length + 1
          : conversation.members.length;
      subtitle = l10n.membersCount(count);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodySmall?.copyWith(
            color: highlight
                ? context.colorScheme.primary
                : context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator(this.day);
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            context.formatDay(day),
            style: context.textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onQuickActions,
    required this.onTyping,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onQuickActions;
  final VoidCallback onTyping;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText) widget.onTyping();
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: l10n.attach,
                onPressed: widget.onAttach,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
              IconButton(
                tooltip: l10n.familyActions,
                onPressed: widget.onQuickActions,
                icon: const Icon(Icons.bolt_rounded),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 6,
                  maxLength: 8000,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: l10n.messageHint,
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: l10n.send,
                onPressed: _hasText ? widget.onSend : null,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
