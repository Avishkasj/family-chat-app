// Headless FamNest hub for an always-on home computer or Raspberry Pi.
//
//   dart run bin/famnest_hub.dart --data ./hub-data --family "The Smiths"
//
// All data stays in the --data directory on this machine.
import 'dart:async';
import 'dart:io';

import 'package:famnest/shared/crypto.dart';
import 'package:famnest/shared/hub/hub_server.dart';
import 'package:famnest/shared/hub/hub_store.dart';
import 'package:famnest/shared/protocol.dart';

const _usage = '''
FamNest headless hub

Options:
  --data <dir>       Where the hub keeps its database and files (default: ./famnest-hub)
  --family <name>    Family name, used when creating a new hub
  --port <port>      TCP port (default: $kHubPort)
  --rotate-code      Issue a new invite code (everyone must re-enter it)
  --help             Show this help
''';

Future<void> main(List<String> args) async {
  String? option(String name) {
    final index = args.indexOf(name);
    return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
  }

  if (args.contains('--help')) {
    stdout.write(_usage);
    return;
  }

  final dataDir = option('--data') ?? 'famnest-hub';
  final port = int.tryParse(option('--port') ?? '') ?? kHubPort;
  Directory(dataDir).createSync(recursive: true);
  if (!Platform.isWindows) {
    await Process.run('chmod', ['700', dataDir]);
  }

  final store = HubStore.open(dataDir);
  if (!store.isInitialized) {
    final family = option('--family') ?? 'My Family';
    store.initialize(familyName: family, hubName: Platform.localHostname);
    stdout.writeln('Created new family hub "$family".');
  } else if (args.contains('--rotate-code')) {
    store.rotateInviteCode();
    stdout.writeln('Issued a new invite code.');
  }

  final server = HubServer(
    store,
    port: port,
    log: (message) => stdout.writeln('[${DateTime.now().toIso8601String()}] $message'),
  );
  await server.start();
  final advertiser = await _advertiseMdns(store, port);

  stdout
    ..writeln('')
    ..writeln('  Family:       ${store.familyName}')
    ..writeln('  Invite code:  ${formatInviteCode(store.inviteCode)}')
    ..writeln('  Addresses:    ${await _localAddresses()} (port $port)')
    ..writeln('')
    ..writeln('Keep this window open. Press Ctrl+C to stop.');

  late final StreamSubscription<ProcessSignal> sigint;
  sigint = ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('Stopping hub...');
    advertiser?.kill();
    await server.stop();
    store.close();
    await sigint.cancel();
    exit(0);
  });
}

/// Advertises the hub via the OS's mDNS responder when one is available
/// (Bonjour on macOS, Avahi on Linux). UDP discovery works regardless.
Future<Process?> _advertiseMdns(HubStore store, int port) async {
  final txt = ['fid=${store.familyId}', 'fn=${store.familyName}'];
  final name = 'FamNest ${store.familyName}';
  try {
    if (Platform.isMacOS) {
      return await Process.start('dns-sd', [
        '-R', name, kServiceType, 'local', '$port', ...txt,
      ]);
    }
    if (Platform.isLinux) {
      return await Process.start('avahi-publish-service', [
        name, kServiceType, '$port', ...txt,
      ]);
    }
  } catch (_) {
    stdout.writeln('mDNS advertising unavailable; UDP discovery still works.');
  }
  return null;
}

Future<String> _localAddresses() async {
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  final addresses = [
    for (final i in interfaces)
      for (final a in i.addresses)
        if (!a.isLoopback) a.address,
  ];
  return addresses.isEmpty ? 'unknown' : addresses.join(', ');
}
