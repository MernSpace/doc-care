// notification_service.dart
//
// A wrapper around flutter_local_notifications covering:
//  - Setup / initialization (Android + iOS)
//  - Instant notifications
//  - Scheduled (one-off) notifications
//  - Automatic local timezone detection
//  - Repeating "per day" notifications (e.g. every Monday & Tuesday at 18:24)
//  - Checking / requesting notification permission (with app_settings fallback)
//  - Listing pending (scheduled) notifications
//  - Cancelling notifications (single / all)
//
// pubspec.yaml dependencies used:
//   flutter_local_notifications: ^19.1.0
//   timezone: ^0.10.1
//   app_settings: ^6.1.1
//   (optional) flutter_native_timezone or flutter_timezone, if you don't
//   want to hardcode a timezone name.
//
// Android manifest additions required (AndroidManifest.xml):
//   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
//   <uses-permission android:name="android.permission.VIBRATE"/>
//   <uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY"/>
//
//   <receiver android:exported="false"
//     android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
//   <receiver android:exported="false"
//     android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
//     <intent-filter>
//       <action android:name="android.intent.action.BOOT_COMPLETED"/>
//       <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
//       <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
//       <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
//     </intent-filter>
//   </receiver>
//   <receiver android:exported="false"
//     android:name="com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsReceiver"/>
//
// iOS (ios/Runner/AppDelegate.swift) additions required:
//   import flutter_local_notifications
//   FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
//     GeneratedPluginRegistrant.register(with: registry)
//   }
//   if #available(iOS 10.0, *) {
//     UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
//   }

import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// -----------------------------------------------------------------
  /// 1. SETUP / INIT
  /// -----------------------------------------------------------------
  /// Call this once, early in main() (after WidgetsFlutterBinding.ensureInitialized()).
  Future<void> init({
    void Function(NotificationResponse response)? onNotificationTap,
  }) async {
    if (_initialized) return;

    // Initialize timezone database and set the local location automatically.
    await _configureLocalTimeZone();

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // we ask permission explicitly, see below
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onNotificationTap?.call(response);
      },
    );

    _initialized = true;
  }

  /// Detects the device's local timezone and configures the `timezone`
  /// package with it, so scheduled notifications fire at the correct
  /// local time (item "3.1 Get local timezone automatically" in the article).
  ///
  /// Note: flutter_local_notifications no longer ships timezone lookup
  /// helpers directly; use a package like `flutter_timezone` to get the
  /// device's IANA timezone name, then feed it here. If you'd rather not
  /// add that dependency, replace `deviceTimezone` with a hardcoded IANA
  /// name (see https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  /// as referenced in the article).
  Future<void> _configureLocalTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      // If you added `flutter_timezone`, this is the idiomatic way:
      //   final String deviceTimezone = await FlutterTimezone.getLocalTimezone();
      // Fallback below just uses UTC if you haven't wired that up yet.
      const String deviceTimezone = 'UTC';
      tz.setLocalLocation(tz.getLocation(deviceTimezone));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  /// -----------------------------------------------------------------
  /// 2. PERMISSIONS
  /// -----------------------------------------------------------------
  /// Explicitly request notification permission (Android 13+ / iOS).
  /// Returns true if granted.
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    } else if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted =
      await androidImpl?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  /// Checks whether notifications are currently enabled for the app.
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidImpl?.areNotificationsEnabled() ?? false;
    } else if (Platform.isIOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final settings = await iosImpl?.checkPermissions();
      return settings?.isEnabled ?? false;
    }
    return false;
  }

  /// If the user previously tapped "Don't allow", the OS won't show the
  /// permission dialog again. Use this to send them to the app's
  /// notification settings screen instead (per the article's
  /// "Grant notification access" section).
  Future<void> openNotificationSettings() async {
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }

  /// -----------------------------------------------------------------
  /// 3. INSTANT NOTIFICATIONS
  /// -----------------------------------------------------------------
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'instant_channel',
    String channelName = 'Instant Notifications',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Shown immediately when triggered',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// -----------------------------------------------------------------
  /// 4. SCHEDULED (ONE-OFF) NOTIFICATIONS
  /// -----------------------------------------------------------------
  /// Schedules a single notification to fire at [scheduledDate].
  /// Remember: every scheduled notification needs a unique [id].
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String channelId = 'scheduled_channel',
    String channelName = 'Scheduled Notifications',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifications scheduled for a specific date/time',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// -----------------------------------------------------------------
  /// 4B. DOSE REMINDERS (medicine-tracking app helper)
  /// -----------------------------------------------------------------
  /// Schedules a reminder for a single dose. Uses the dose's own database
  /// row id as the notification id, so there's a stable 1:1 mapping and
  /// [cancelDoseNotification] can look it back up with no extra bookkeeping.
  Future<void> scheduleDoseNotification({
    required int doseId,
    required String medicineName,
    required DateTime scheduledTime,
  }) async {
    // Guard against scheduling a reminder for a time that's already passed
    // (e.g. the dose was generated late in the day) — zonedSchedule with a
    // past TZDateTime either throws or fires immediately depending on
    // platform, neither of which is what you want here.
    if (scheduledTime.isBefore(DateTime.now())) return;

    await scheduleNotification(
      id: doseId,
      title: 'Time to take your medicine',
      body: 'It is time to take $medicineName.',
      scheduledDate: scheduledTime,
      channelId: 'dose_reminder_channel',
      channelName: 'Dose Reminders',
    );
  }

  /// Cancels the reminder for a specific dose (e.g. once it's been marked
  /// taken, or the dose log entry was deleted).
  Future<void> cancelDoseNotification(int doseId) async {
    await cancelNotification(doseId);
  }

  /// -----------------------------------------------------------------
  /// 5. REPEATING "PER DAY" NOTIFICATIONS
  /// -----------------------------------------------------------------
  /// Schedules a notification that repeats weekly on a specific
  /// [weekday] (1 = Monday ... 7 = Sunday) at [hour]:[minute].
  /// To reproduce the article's example ("only Monday and Tuesday at
  /// 18:24"), call this twice with DateTime.monday and DateTime.tuesday,
  /// using two different unique IDs.
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int weekday, // use DateTime.monday .. DateTime.sunday
    required int hour,
    required int minute,
    String? payload,
    String channelId = 'weekly_channel',
    String channelName = 'Weekly Notifications',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifications that repeat weekly on a given day',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledDate = _nextInstanceOfWeekdayTime(weekday, hour, minute);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Convenience helper: schedule the same notification content on several
  /// weekdays at once, auto-generating unique IDs from [baseId].
  /// Example: scheduleOnMultipleDays(baseId: 100, weekdays: [DateTime.monday, DateTime.tuesday], hour: 18, minute: 24, title: 'Reminder', body: 'Time to check in!');
  Future<void> scheduleOnMultipleDays({
    required int baseId,
    required List<int> weekdays,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {
    for (var i = 0; i < weekdays.length; i++) {
      await scheduleWeeklyNotification(
        id: baseId + i, // each weekday gets its own unique ID
        title: title,
        body: body,
        weekday: weekdays[i],
        hour: hour,
        minute: minute,
        payload: payload,
      );
    }
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    tz.TZDateTime scheduled = tz.TZDateTime.now(tz.local);
    scheduled = tz.TZDateTime(
      tz.local,
      scheduled.year,
      scheduled.month,
      scheduled.day,
      hour,
      minute,
    );

    while (scheduled.weekday != weekday || scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// -----------------------------------------------------------------
  /// 6. PENDING NOTIFICATIONS
  /// -----------------------------------------------------------------
  /// Returns all notifications that are currently scheduled but haven't
  /// fired yet — useful for showing the user their active reminders.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }

  /// -----------------------------------------------------------------
  /// 7. CANCELLING NOTIFICATIONS
  /// -----------------------------------------------------------------
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }
}