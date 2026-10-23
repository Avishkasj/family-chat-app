import 'package:flutter/material.dart';

import '../core/theme/extension.dart';

/// Asks for a short line of text. Returns the trimmed text, or null if the
/// user cancelled or left it empty.
///
/// The dialog owns its [TextEditingController] so it is only disposed after
/// the dialog's closing animation has finished.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String? hint,
  String initialValue = '',
  int maxLength = 80,
  TextCapitalization capitalization = TextCapitalization.sentences,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPromptDialog(
    title: title,
    actionLabel: actionLabel,
    hint: hint,
    initialValue: initialValue,
    maxLength: maxLength,
    capitalization: capitalization,
  ),
);

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.actionLabel,
    required this.hint,
    required this.initialValue,
    required this.maxLength,
    required this.capitalization,
  });

  final String title;
  final String actionLabel;
  final String? hint;
  final String initialValue;
  final int maxLength;
  final TextCapitalization capitalization;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    Navigator.pop(context, text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        textCapitalization: widget.capitalization,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: _submit,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
