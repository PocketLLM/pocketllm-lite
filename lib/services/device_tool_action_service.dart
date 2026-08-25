import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import 'network_policy_service.dart';
import 'storage_service.dart';

abstract class DeviceToolActionService {
  Future<void> copyToClipboard(String text);
  Future<Map<String, dynamic>> createNote(String title, String content);
  Future<int> scheduleReminder(String title, String body, DateTime when);
  Future<void> openWebUrl(Uri uri);
  Future<void> openEmailDraft({
    required String recipient,
    required String subject,
    required String body,
  });
}

class PlatformDeviceToolActionService implements DeviceToolActionService {
  final StorageService? _storage;
  final NetworkPolicyService _networkPolicy;
  final FlutterLocalNotificationsPlugin _notifications;
  bool _notificationsInitialized = false;

  PlatformDeviceToolActionService({
    StorageService? storage,
    NetworkPolicyService? networkPolicy,
    FlutterLocalNotificationsPlugin? notifications,
  })  : _storage = storage,
        _networkPolicy = networkPolicy ?? NetworkPolicyService(),
        _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  @override
  Future<void> copyToClipboard(String text) async {
    if (text.trim().isEmpty) throw ArgumentError('Clipboard text is empty.');
    await Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Future<Map<String, dynamic>> createNote(
    String title,
    String content,
  ) async {
    final storage = _storage;
    if (storage == null) {
      throw StateError('Local note storage is unavailable.');
    }
    return storage.createLocalNote(title: title, content: content);
  }

  @override
  Future<int> scheduleReminder(
    String title,
    String body,
    DateTime when,
  ) async {
    if (!when.isAfter(DateTime.now())) {
      throw ArgumentError('Reminder time must be in the future.');
    }
    await _initializeNotifications();
    final permissionGranted = await _requestNotificationPermission();
    if (!permissionGranted) {
      throw StateError('Notification permission was not granted.');
    }

    tz.initializeTimeZones();
    final id = DateTime.now().microsecondsSinceEpoch.remainder(0x7fffffff);
    await _notifications.zonedSchedule(
      id,
      title.trim(),
      body.trim(),
      tz.TZDateTime.from(when.toUtc(), tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pocketllm_reminders',
          'PocketLLM reminders',
          channelDescription: 'User-confirmed reminders created in chat',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return id;
  }

  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('launcher_icon'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    final initialized = await _notifications.initialize(settings);
    if (initialized == false) {
      throw StateError('Local notifications could not be initialized.');
    }
    _notificationsInitialized = true;
  }

  Future<bool> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (Platform.isIOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> openWebUrl(Uri uri) async {
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw ArgumentError('Only HTTP and HTTPS URLs are supported.');
    }
    final policy = _networkPolicy.evaluateConnection(
      uri: uri,
      purpose: ConnectionPurpose.externalNavigation,
      trigger: 'tool_open_url',
      infoSent: 'No app data; URL opened in the system browser',
    );
    if (!policy.allowed) {
      throw StateError(policy.reason ?? 'External navigation was blocked.');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('No application could open the URL.');
    }
  }

  @override
  Future<void> openEmailDraft({
    required String recipient,
    required String subject,
    required String body,
  }) async {
    final email = recipient.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw ArgumentError('Recipient must be a valid email address.');
    }
    final query = <String, String>{'subject': subject, 'body': body}
        .entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
    final uri = Uri.parse('mailto:${Uri.encodeComponent(email)}?$query');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('No email composer is available.');
    }
  }
}
