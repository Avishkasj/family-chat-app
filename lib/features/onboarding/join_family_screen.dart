import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/extension.dart';
import '../../services/discovery_service.dart';
import '../../shared/handshake.dart';
import '../../shared/protocol.dart';

class JoinFamilyScreen extends ConsumerStatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen> {
  StreamSubscription<List<DiscoveredHub>>? _scan;
  List<DiscoveredHub> _hubs = const [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }

  void _startScan() {
    _scan?.cancel();
    setState(() => _scanning = true);
    _scan = ref
        .read(appServicesProvider)
        .discovery
        .scan(timeout: const Duration(seconds: 8))
        .listen(
          (hubs) {
            if (mounted) setState(() => _hubs = hubs);
          },
          onDone: () {
            if (mounted) setState(() => _scanning = false);
          },
        );
  }

  void _open(DiscoveredHub hub) => context.push(Routes.joinCode, extra: hub);

  Future<void> _manual() async {
    final hub = await showDialog<DiscoveredHub>(
      context: context,
      builder: (context) => const _ManualAddressDialog(),
    );
    if (hub != null && mounted) _open(hub);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinTitle)),
      body: SafeArea(
        child: Column(
          children: [
            if (_scanning) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _scanning || _hubs.isNotEmpty
                          ? l10n.searching
                          : l10n.noHubsFound,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final hub in _hubs)
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: context.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.home_rounded,
                            color: context.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(hub.familyName),
                        subtitle: Text(
                          hub.hubName.isEmpty
                              ? hub.host
                              : '${hub.hubName} · ${hub.host}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(hub),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!_scanning)
                    FilledButton.tonalIcon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.scanAgain),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  TextButton(
                    onPressed: _manual,
                    child: Text(l10n.enterAddressManually),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualAddressDialog extends StatefulWidget {
  const _ManualAddressDialog();

  @override
  State<_ManualAddressDialog> createState() => _ManualAddressDialogState();
}

class _ManualAddressDialogState extends State<_ManualAddressDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    var host = input;
    var port = kHubPort;
    final match = RegExp(r'^(.+):(\d+)$').firstMatch(input);
    if (match != null && !input.contains('::')) {
      host = match.group(1)!;
      port = int.parse(match.group(2)!);
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final hello = await probeHub(host, port);
      if (!mounted) return;
      Navigator.of(context).pop(
        DiscoveredHub(
          host: host,
          port: port,
          familyId: hello.familyId,
          familyName: hello.familyName,
          hubName: hello.hubName,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.couldNotReachHub;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.enterAddressManually),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: l10n.hubAddressLabel,
          hintText: l10n.hubAddressHint,
          errorText: _error,
        ),
        onSubmitted: (_) => _connect(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _connect,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.connect),
        ),
      ],
    );
  }
}
