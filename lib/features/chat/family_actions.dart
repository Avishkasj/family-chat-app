import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/extension.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/text_prompt_dialog.dart';

String callTitle(AppLocalizations l10n, CallType type) => switch (type) {
  CallType.breakfast => l10n.callBreakfast,
  CallType.lunch => l10n.callLunch,
  CallType.tea => l10n.callTea,
  CallType.dinner => l10n.callDinner,
  CallType.ready => l10n.callReady,
  CallType.comeHere => l10n.callComeHere,
  CallType.custom => l10n.callCustom,
};

String answerLabel(AppLocalizations l10n, CallAnswer answer) =>
    switch (answer) {
      CallAnswer.coming => l10n.answerComing,
      CallAnswer.soon => l10n.answerSoon,
      CallAnswer.skip => l10n.answerSkip,
    };

/// Quick family actions: meal / "come here" calls and polls.
Future<void> showFamilyActionsSheet(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) {
  final l10n = context.l10n;
  final chat = ref.read(chatServiceProvider);

  void call(CallType type, {String? title, String? note}) {
    chat.sendCall(
      conversationId,
      CallData(type: type, title: title ?? callTitle(l10n, type), note: note),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.callFamily, style: context.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.callFamilyHint,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.05,
              children: [
                for (final type in CallType.values.where(
                  (t) => t != CallType.custom,
                ))
                  _ActionTile(
                    emoji: type.emoji,
                    label: callTitle(l10n, type),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      call(type);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Text('\u{1F4E2}')),
              title: Text(l10n.customCall),
              onTap: () async {
                Navigator.pop(sheetContext);
                final title = await showTextPrompt(
                  context,
                  title: l10n.customCall,
                  hint: l10n.customCallHint,
                  actionLabel: l10n.send,
                );
                if (title != null) call(CallType.custom, title: title);
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: context.colorScheme.tertiaryContainer,
                child: Icon(
                  Icons.poll_outlined,
                  color: context.colorScheme.onTertiaryContainer,
                ),
              ),
              title: Text(l10n.createPoll),
              subtitle: Text(l10n.createPollHint),
              onTap: () {
                Navigator.pop(sheetContext);
                showPollComposer(context, ref, conversationId);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Poll composer
// ---------------------------------------------------------------------------

Future<void> showPollComposer(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _PollComposer(conversationId: conversationId),
);

class _PollComposer extends ConsumerStatefulWidget {
  const _PollComposer({required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<_PollComposer> createState() => _PollComposerState();
}

class _PollComposerState extends ConsumerState<_PollComposer> {
  static const _maxOptions = 12;
  final _question = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _multiple = false;

  @override
  void dispose() {
    _question.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  void _removeOption(int index) {
    final removed = _options[index];
    setState(() => _options.removeAt(index));
    // Dispose once the field using it has been removed from the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  bool get _valid =>
      _question.text.trim().isNotEmpty &&
      _options.where((o) => o.text.trim().isNotEmpty).length >= 2;

  void _send() {
    ref.read(chatServiceProvider).sendPoll(
      widget.conversationId,
      PollData(
        question: _question.text,
        options: _options.map((o) => o.text).toList(),
        multiple: _multiple,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.createPoll, style: context.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _question,
                autofocus: true,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.pollQuestion,
                  hintText: l10n.pollQuestionHint,
                ),
                onChanged: (_) => setState(() {}),
              ),
              for (var i = 0; i < _options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _options[i],
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: l10n.pollOption(i + 1),
                      suffixIcon: _options.length > 2
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => _removeOption(i),
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              if (_options.length < _maxOptions)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _options.add(TextEditingController())),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addOption),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.allowMultiple),
                value: _multiple,
                onChanged: (v) => setState(() => _multiple = v),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _valid ? _send : null,
                child: Text(l10n.sendPoll),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards shown in the chat
// ---------------------------------------------------------------------------

class _Voters extends StatelessWidget {
  const _Voters(this.ids);
  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    const size = 11.0;
    final shown = ids.take(5).toList();
    return SizedBox(
      height: size * 2,
      width: size * 2 + (shown.length - 1).clamp(0, 4) * size * 1.3,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * size * 1.3,
              child: MemberAvatar(memberId: shown[i], radius: size),
            ),
        ],
      ),
    );
  }
}

class PollCard extends ConsumerWidget {
  const PollCard({required this.message, required this.color, super.key});

  final ChatMessage message;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final poll = message.poll!;
    final me = ref.watch(myIdProvider);
    final responses = ref.watch(
      responsesProvider((
        conversationId: message.conversationId,
        ref: message.id,
      )),
    );
    final tally = PollTally.from(message, responses);
    final mine = tally.choicesOf(me);
    final total = tally.votes.length;
    final chat = ref.read(chatServiceProvider);
    final canVote = !tally.closed && message.status == MessageStatus.sent;

    void toggle(int option) {
      final next = {...mine};
      if (poll.multiple) {
        next.contains(option) ? next.remove(option) : next.add(option);
      } else {
        next
          ..clear()
          ..addAll(mine.contains(option) ? const <int>{} : {option});
      }
      chat.vote(message, next);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_outlined, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                tally.closed
                    ? l10n.pollClosed
                    : poll.multiple
                    ? l10n.pollChooseMany
                    : l10n.pollChooseOne,
                style: context.textTheme.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            poll.question,
            style: context.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < poll.options.length; i++)
            _PollOption(
              label: poll.options[i],
              voters: tally.votersFor(i),
              total: total,
              selected: mine.contains(i),
              multiple: poll.multiple,
              color: color,
              onTap: canVote ? () => toggle(i) : null,
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.votesCount(total),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ),
              if (!tally.closed && message.sender == me)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => chat.closePoll(message),
                  child: Text(l10n.closePoll),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({
    required this.label,
    required this.voters,
    required this.total,
    required this.selected,
    required this.multiple,
    required this.color,
    required this.onTap,
  });

  final String label;
  final List<String> voters;
  final int total;
  final bool selected;
  final bool multiple;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : voters.length / total;
    final icon = multiple
        ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
        : (selected ? Icons.radio_button_checked : Icons.radio_button_off);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label, style: TextStyle(color: color)),
                  ),
                  if (voters.isNotEmpty) _Voters(voters),
                  const SizedBox(width: 6),
                  Text(
                    '${voters.length}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CallCard extends ConsumerWidget {
  const CallCard({required this.message, required this.color, super.key});

  final ChatMessage message;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final call = message.call!;
    final me = ref.watch(myIdProvider);
    final responses = ref.watch(
      responsesProvider((
        conversationId: message.conversationId,
        ref: message.id,
      )),
    );
    final replies = CallReplies.from(responses);
    final mine = replies.answers[me];
    final isCaller = message.sender == me;
    final title = call.type == CallType.custom
        ? call.title
        : callTitle(l10n, call.type);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(call.type.emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (call.note != null && call.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(call.note!, style: TextStyle(color: color)),
            ),
          const SizedBox(height: 10),
          if (!isCaller)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final answer in CallAnswer.values)
                  ChoiceChip(
                    avatar: Text(answer.emoji),
                    showCheckmark: false,
                    label: Text(answerLabel(l10n, answer)),
                    selected: mine == answer,
                    onSelected: message.status == MessageStatus.sent
                        ? (_) => ref
                              .read(chatServiceProvider)
                              .respondToCall(
                                message,
                                answer,
                                answerLabel(l10n, answer),
                              )
                        : null,
                  ),
              ],
            ),
          if (replies.answers.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final answer in CallAnswer.values)
              if (replies.membersWith(answer).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(answer.emoji),
                      const SizedBox(width: 6),
                      _Voters(replies.membersWith(answer)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _AnswerNames(
                          ids: replies.membersWith(answer),
                          label: answerLabel(l10n, answer),
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
          ] else if (isCaller)
            Text(
              l10n.waitingForReplies,
              style: context.textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnswerNames extends ConsumerWidget {
  const _AnswerNames({
    required this.ids,
    required this.label,
    required this.color,
  });

  final List<String> ids;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myIdProvider);
    final names = ids
        .map(
          (id) => id == me
              ? context.l10n.you
              : ref.watch(memberProvider(id))?.displayName ?? '',
        )
        .join(', ');
    return Text(
      '$label · $names',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.labelMedium?.copyWith(color: color),
    );
  }
}
