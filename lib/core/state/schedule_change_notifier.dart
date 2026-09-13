// core/state/schedule_change_notifier.dart
import 'package:flutter/foundation.dart';

/// Fires whenever a schedule is added, updated, or deleted, so any screen
/// that derives data from schedules (like DoseLogScreen, which generates
/// today's doses from active schedules) can refresh itself — regardless of
/// whether navigation between screens is via push/pop, bottom-nav tabs, or
/// anything else. Screens just add/remove a listener; they don't need to
/// know who triggered the change or how they got here.
class ScheduleChangeNotifier extends ChangeNotifier {
  ScheduleChangeNotifier._();
  static final ScheduleChangeNotifier instance = ScheduleChangeNotifier._();

  /// Call this after any successful insert/update/delete of a schedule.
  void notifyScheduleChanged() => notifyListeners();
}