// features/dose_log/screens/dose_log_screen.dart
import 'package:flutter/material.dart';
import 'package:my_app/core/database/tables/medicines_model.dart';
import 'package:my_app/core/database/tables/medicines_schedules_table.dart';
import 'package:my_app/core/database/tables/db.dart';
import 'package:my_app/core/database/tables/dose_log_table.dart';
import 'package:my_app/core/notifications/notification_service.dart';

class DoseLogScreen extends StatefulWidget {
  const DoseLogScreen({super.key});

  @override
  State<DoseLogScreen> createState() => _DoseLogScreenState();
}

class _DoseLogScreenState extends State<DoseLogScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<DoseLogModel> _doses = [];
  List<MedicineModel> _medicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Actually sets up the notification channel + requests permission.
    // Safe to call more than once (init() is idempotent), so it's fine
    // here even if you also call NotificationService.instance.init() in
    // main(). Doing it here too means dose reminders still get scheduled
    // correctly even if this screen is reached before main() finishes
    // wiring things up, or hot-reload skipped main().
    _ensureNotificationsReady();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<DoseLogModel> get _upcomingDoses => _doses.where((d) => !d.taken).toList();
  List<DoseLogModel> get _takenDoses => _doses.where((d) => d.taken).toList();

  /// Initializes the notification plugin and, if permission hasn't been
  /// granted yet, asks for it. Without this, [scheduleDoseNotification]
  /// calls below will run but the OS will silently drop them because the
  /// plugin was never initialized / permission was never granted.
  Future<void> _ensureNotificationsReady() async {
    await NotificationService.instance.init();

    final enabled = await NotificationService.instance.areNotificationsEnabled();
    if (!enabled) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted && mounted) {
        // User declined (or previously declined, so no dialog was shown).
        // Let them know reminders won't fire and offer a way to fix it.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Enable notifications to get dose reminders'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => NotificationService.instance.openNotificationSettings(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final medicines = await DBHelper.instance.getMedicines();
      final schedules = await DBHelper.instance.getAllActiveSchedules();
      var doses = await DBHelper.instance.getDoseLogsForDay(DateTime.now());

      // Fill in any doses today's active schedules call for but that don't
      // have a log row yet (e.g. the first time the screen opens each day),
      // and schedule a notification for each newly created one.
      await _generateTodaysDosesFromSchedules(schedules, doses, medicines);
      doses = await DBHelper.instance.getDoseLogsForDay(DateTime.now());

      if (!mounted) return;
      setState(() {
        _medicines = medicines;
        _doses = doses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load doses: $e')),
      );
    }
  }

  /// Checks each active schedule against today's date/weekday and inserts a
  /// DoseLogModel for any (medicine, time) pair that's due today and doesn't
  /// already have a log row — so opening the screen "checks the schedule"
  /// and upcoming doses just appear, instead of being added by hand. Each
  /// newly created dose also gets a scheduled notification.
  Future<void> _generateTodaysDosesFromSchedules(
      List<MedicineScheduleModel> schedules,
      List<DoseLogModel> existingDoses,
      List<MedicineModel> medicines,
      ) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final todayLabel = _weekdayLabel(today.weekday);

    for (final schedule in schedules) {
      if (!schedule.isActive) continue;
      if (!schedule.days.contains(todayLabel)) continue;

      final scheduleStart = DateTime(
        schedule.startDate.year, schedule.startDate.month, schedule.startDate.day,
      );
      if (scheduleStart.isAfter(startOfDay)) continue;

      if (schedule.endDate != null) {
        final scheduleEnd = DateTime(
          schedule.endDate!.year, schedule.endDate!.month, schedule.endDate!.day,
        );
        if (scheduleEnd.isBefore(startOfDay)) continue;
      }

      final medicineMatch = medicines.where((m) => m.id == schedule.medicineId);
      final medicineName = medicineMatch.isEmpty ? 'your medicine' : medicineMatch.first.name;

      for (final time in schedule.times) {
        final alreadyLogged = existingDoses.any((d) =>
        d.medicineId == schedule.medicineId &&
            d.scheduledTime.hour == time.hour &&
            d.scheduledTime.minute == time.minute);
        if (alreadyLogged) continue;

        final now = DateTime.now();
        final scheduledTime = DateTime(
          startOfDay.year, startOfDay.month, startOfDay.day, time.hour, time.minute,
        );

        final doseId = await DBHelper.instance.insertDoseLog(DoseLogModel(
          medicineId: schedule.medicineId,
          scheduleId: schedule.id,
          scheduledTime: scheduledTime,
          createdAt: now,
          updatedAt: now,
        ));

        if (schedule.reminderEnabled) {
          await NotificationService.instance.scheduleDoseNotification(
            doseId: doseId,
            medicineName: medicineName,
            scheduledTime: scheduledTime,
          );
        }
      }
    }
  }

  String _weekdayLabel(int weekday) {
    // DateTime.weekday: Monday = 1 ... Sunday = 7 — matches kWeekdays order.
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[weekday - 1];
  }

  String _medicineName(int medicineId) {
    final match = _medicines.where((m) => m.id == medicineId);
    return match.isEmpty ? 'Unknown medicine' : match.first.name;
  }

  Future<void> _markTaken(DoseLogModel dose) async {
    final index = _doses.indexWhere((d) => d.id == dose.id);
    if (index == -1) return;

    // Optimistic update so the tap feels instant.
    setState(() => _doses[index] = dose.copyWith(taken: true, takenAt: DateTime.now()));

    try {
      await DBHelper.instance.markDoseTaken(dose.id!);
      // No point alarming them for a dose they've already taken.
      await NotificationService.instance.cancelDoseNotification(dose.id!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _doses[index] = dose); // revert on failure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update dose: $e')),
      );
    }
  }

  Future<void> _deleteDose(DoseLogModel dose) async {
    final removedIndex = _doses.indexWhere((d) => d.id == dose.id);
    if (removedIndex == -1) return;

    setState(() => _doses.removeAt(removedIndex));

    try {
      await DBHelper.instance.deleteDoseLog(dose.id!);
      await NotificationService.instance.cancelDoseNotification(dose.id!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _doses.insert(removedIndex, dose)); // revert on failure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete dose: $e')),
      );
    }
  }

  Future<void> _openAddModal() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddDoseModal(medicines: _medicines),
    );
    if (added == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dose Log'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'UPCOMING (${_upcomingDoses.length})', icon: const Icon(Icons.schedule_outlined)),
            Tab(text: 'TAKEN (${_takenDoses.length})', icon: const Icon(Icons.check_circle_outline)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _medicines.isEmpty ? null : _openAddModal,
        tooltip: _medicines.isEmpty ? 'Add a medicine first' : 'Log a dose',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _DoseList(
            doses: _upcomingDoses,
            emptyMessage: 'No upcoming doses',
            medicineName: _medicineName,
            onMarkTaken: _markTaken,
            onDelete: _deleteDose,
            onRefresh: _loadData,
          ),
          _DoseList(
            doses: _takenDoses,
            emptyMessage: 'No doses taken yet',
            medicineName: _medicineName,
            onMarkTaken: _markTaken,
            onDelete: _deleteDose,
            onRefresh: _loadData,
          ),
        ],
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Shared list body for a single tab (upcoming or taken).
/// -------------------------------------------------------------------------
class _DoseList extends StatelessWidget {
  const _DoseList({
    required this.doses,
    required this.emptyMessage,
    required this.medicineName,
    required this.onMarkTaken,
    required this.onDelete,
    required this.onRefresh,
  });

  final List<DoseLogModel> doses;
  final String emptyMessage;
  final String Function(int medicineId) medicineName;
  final void Function(DoseLogModel dose) onMarkTaken;
  final void Function(DoseLogModel dose) onDelete;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (doses.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 160),
            Center(child: Text(emptyMessage)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: doses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final dose = doses[index];
          return Dismissible(
            key: ValueKey(dose.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            onDismissed: (_) => onDelete(dose),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: dose.taken
                      ? Colors.green.withOpacity(0.15)
                      : Colors.orange.withOpacity(0.15),
                  child: Icon(
                    dose.taken ? Icons.check : Icons.schedule,
                    color: dose.taken ? Colors.green : Colors.orange,
                  ),
                ),
                title: Text(medicineName(dose.medicineId)),
                subtitle: Text(
                  '${dose.scheduledTime.hour.toString().padLeft(2, '0')}:'
                      '${dose.scheduledTime.minute.toString().padLeft(2, '0')}',
                ),
                trailing: dose.taken
                    ? const Text('Taken', style: TextStyle(color: Colors.green))
                    : OutlinedButton(
                  onPressed: () => onMarkTaken(dose),
                  child: const Text('Mark taken'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Modal to log a new dose — pick a medicine and a time.
/// -------------------------------------------------------------------------
class _AddDoseModal extends StatefulWidget {
  const _AddDoseModal({required this.medicines});

  final List<MedicineModel> medicines;

  @override
  State<_AddDoseModal> createState() => _AddDoseModalState();
}

class _AddDoseModalState extends State<_AddDoseModal> {
  MedicineModel? _selectedMedicine;
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _saving = false;

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _selectedTime);
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _save() async {
    if (_selectedMedicine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a medicine')),
      );
      return;
    }

    setState(() => _saving = true);

    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute,
    );

    // If the picked time-of-day has already passed today, treat it as
    // "tomorrow at that time" instead of silently scheduling a reminder
    // in the past (which NotificationService.scheduleDoseNotification
    // would just skip, leaving the user with no reminder at all).
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final dose = DoseLogModel(
      medicineId: _selectedMedicine!.id!,
      scheduledTime: scheduledTime,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final doseId = await DBHelper.instance.insertDoseLog(dose);
      await NotificationService.instance.scheduleDoseNotification(
        doseId: doseId,
        medicineName: _selectedMedicine!.name,
        scheduledTime: scheduledTime,
      );
      if (context.mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save dose: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Text('Log a dose', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 16),
          DropdownButtonFormField<MedicineModel>(
            value: _selectedMedicine,
            decoration: const InputDecoration(labelText: 'Medicine', border: OutlineInputBorder()),
            items: widget.medicines
                .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                .toList(),
            onChanged: (val) => setState(() => _selectedMedicine = val),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.access_time),
            label: Text('Time: ${_selectedTime.format(context)}'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _saving
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Log dose'),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}