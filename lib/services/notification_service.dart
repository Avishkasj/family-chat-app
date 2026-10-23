import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/models.dart';
import '../l10n/app_localizations.dart';

/// A notification the user tapped, or one of its action buttons.
class NotificationTap {
  const NotificationTap({
    required this.conversationId,
    this.messageId,
    this.answer,
  });

  final String conversationId;
  final String? messageId;

  /// Set when the user answered a family call from the notification.
  final CallAnswer? answer;
}

/// Local (on-device) notifications. No push service or internet connection
/// is involved.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationTap> _taps = StreamController.broadcast();
  bool _ready = false;

  static const _messagesChannel = 'famnest_messages';
  static const _callsChannel = 'famnest_calls';
  static const _callCategory = 'famnest_call';
  static const _answerPrefix = 'answer:';
  static const _brand = Color(0xFF0F7B6C);

  /// Notifications (or action buttons) the user tapped.
  Stream<NotificationTap> get taps => _taps.stream;

  /// The notification that launched the app, if any.
  NotificationTap? launchTap;

  /// Strings in the device language (services have no BuildContext).
  static AppLocalizations get l10n {
    final locale = PlatformDispatcher.instance.locale;
    final supported = AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == locale.languageCode,
    );
    return lookupAppLocalizations(supported ? locale : const Locale('en'));
  }

  static String callTitle(CallType type) => switch (type) {
    CallType.breakfast => l10n.callBreakfast,
    CallType.lunch => l10n.callLunch,
    CallType.tea => l10n.callTea,
    CallType.dinner => l10n.callDinner,
    CallType.ready => l10n.callReady,
    CallType.comeHere => l10n.callComeHere,
    CallType.custom => l10n.callCustom,
  };

  static String answerLabel(CallAnswer answer) => switch (answer) {
    CallAnswer.coming => l10n.answerComing,
    CallAnswer.soon => l10n.answerSoon,
    CallAnswer.skip => l10n.answerSkip,
  };

  Future<void> initialize() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@drawable/ic_stat_famnest'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            notificationCategories: [
              DarwinNotificationCategory(
                _callCategory,
                actions: [
                  for (final answer in CallAnswer.values)
                    DarwinNotificationAction.plain(
                      '$_answerPrefix${answer.name}',
                      '${answer.emoji} ${answerLabel(answer)}',
                      options: {DarwinNotificationActionOption.foreground},
                    ),
                ],
              ),
            ],
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final tap = _parse(response.payload, response.actionId);
          if (tap != null) _taps.add(tap);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final response = launch?.notificationResponse;
        launchTap = _parse(response?.payload, response?.actionId);
      }
      _ready = true;
    } catch (_) {
      // Notifications are optional (e.g. unsupported desktop platform).
    }
  }

  static NotificationTap? _parse(String? payload, String? actionId) {
    if (payload == null || payload.isEmpty) return null;
    final parts = payload.split('\n');
    final answer = actionId != null && actionId.startsWith(_answerPrefix)
        ? CallAnswer.parse(actionId.substring(_answerPrefix.length))
        : null;
    return NotificationTap(
      conversationId: parts[0],
      messageId: parts.length > 1 ? parts[1] : null,
      answer: answer,
    );
  }

  Future<void> requestPermission() async {
    if (!_ready) return;
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static int _idFor(String key) => key.hashCode & 0x7fffffff;

  static const _darwinAlert = DarwinNotificationDetails(
    presentAlert: true,
    presentBanner: true,
    presentList: true,
    presentSound: true,
  );

  /// A regular message; replaces the previous notification of the chat.
  Future<void> showMessage({
    required String conversationId,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: _idFor(conversationId),
      title: title,
      body: body,
      payload: conversationId,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _messagesChannel,
          l10n.notificationChannelMessages,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          groupKey: 'famnest.$conversationId',
          color: _brand,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          threadIdentifier: conversationId,
        ),
      ),
    );
  }

  /// A new poll.
  Future<void> showPoll({
    required String conversationId,
    required String messageId,
    required String sender,
    required String question,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: _idFor(messageId),
      title: '\u{1F4CA} ${l10n.notificationNewPoll(sender)}',
      body: question,
      payload: '$conversationId\n$messageId',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _messagesChannel,
          l10n.notificationChannelMessages,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          color: _brand,
        ),
        iOS: _darwinAlert,
      ),
    );
  }

  /// A family call ("Lunch is ready!") with one-tap answer buttons.
  Future<void> showCall({
    required String conversationId,
    required String messageId,
    required String sender,
    required CallData call,
  }) async {
    if (!_ready) return;
    final note = call.note;
    await _plugin.show(
      id: _idFor(messageId),
      title: '${call.type.emoji} ${call.title}',
      body: note == null || note.isEmpty
          ? l10n.notificationCallFrom(sender)
          : '$sender: $note',
      payload: '$conversationId\n$messageId',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _callsChannel,
          l10n.notificationChannelCalls,
          channelDescription: l10n.notificationChannelCallsHint,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.reminder,
          color: _brand,
          actions: [
            for (final answer in CallAnswer.values)
              AndroidNotificationAction(
                '$_answerPrefix${answer.name}',
                '${answer.emoji} ${answerLabel(answer)}',
                showsUserInterface: true,
              ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          categoryIdentifier: _callCategory,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
    );
  }

  Future<void> clear(String conversationId) async {
    if (!_ready) return;
    await _plugin.cancel(id: _idFor(conversationId));
  }

  Future<void> clearMessage(String messageId) async {
    if (!_ready) return;
    await _plugin.cancel(id: _idFor(messageId));
  }

  Future<void> clearAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }
}
