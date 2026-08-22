// features/schedule/screens/medicine_schedules_screen.dart
import 'package:flutter/material.dart';
import 'package:my_app/core/database/tables/medicines_model.dart';
import 'package:my_app/core/database/tables/medicines_schedules_table.dart';
import 'package:my_app/core/database/tables/db.dart';
import 'package:my_app/main.dart' show routeObserver; // <-- adjust this import to wherever routeObserver is defined

const List<String> kWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// -------------------------------------------------------------------------
/// Top-level screen: "All Schedules" + "Add Schedule" tabs.
/// Replaces the old standalone AddMedicineScheduleScreen as the entry point.
/// -------------------------------------------------------------------------
class MedicineSchedulesScreen extends StatefulWidget {
  const MedicineSchedulesScreen({super.key});

  @override
  State<MedicineSchedulesScreen> createState() => _MedicineSchedulesScreenState();
}

class _MedicineSchedulesScreenState extends State<MedicineSchedulesScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late final TabController _tabController;

  List<MedicineScheduleModel> _schedules = [];
  List<MedicineModel> _medicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes so we know when the user comes back to this
    // screen (e.g. after pushing an "Add Medicine" screen and popping back).
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    super.dispose();
  }

  /// Called by RouteObserver when a route pushed on top of this one has been
  /// popped and this screen is visible again. This is what catches "user
  /// added a medicine on another screen and came back here".
  @override
  void didPopNext() {
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final medicines = await DBHelper.instance.getMedicines();
      // NOTE: only active schedules — there's no getAllSchedules() in db.dart.
      // Add one (same as getAllActiveSchedules but without the where clause)
      // if you want paused/inactive schedules to show up here too.
      final schedules = await DBHelper.instance.getAllActiveSchedules();
      if (!mounted) return;
      setState(() {
        _medicines = medicines;
        _schedules = schedules;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load schedules: $e')),
      );
    }
  }

  void _onScheduleSaved() {
    _loadAll();
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F9FB),
        elevation: 0,
        foregroundColor: const Color(0xFF1F2A37),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ALL SCHEDULES', icon: Icon(Icons.event_note_outlined)),
            Tab(text: 'ADD SCHEDULE', icon: Icon(Icons.add_circle_outline)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _AllSchedulesTab(
            schedules: _schedules,
            medicines: _medicines,
            onChanged: _loadAll,
          ),
          _AddScheduleTab(
            medicines: _medicines,
            onSaved: _onScheduleSaved,
            onRefreshMedicines: _loadAll,
            isRefreshing: _isLoading,
          ),
        ],
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Tab 1 — list of schedules with Edit / Delete actions.
/// -------------------------------------------------------------------------
class _AllSchedulesTab extends StatelessWidget {
  const _AllSchedulesTab({
    required this.schedules,
    required this.medicines,
    required this.onChanged,
  });

  final List<MedicineScheduleModel> schedules;
  final List<MedicineModel> medicines;
  final VoidCallback onChanged;

  String _medicineName(int medicineId) {
    final match = medicines.where((m) => m.id == medicineId);
    return match.isEmpty ? 'Unknown medicine' : match.first.name;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _confirmDelete(BuildContext context, MedicineScheduleModel schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete schedule'),
        content: Text(
          'Delete the schedule for "${_medicineName(schedule.medicineId)}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DBHelper.instance.deleteSchedule(schedule.id!);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule deleted'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete schedule: $e')),
        );
      }
    }
  }

  Future<void> _openEditModal(BuildContext context, MedicineScheduleModel schedule) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditScheduleModal(schedule: schedule, medicines: medicines),
    );
    if (updated == true) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => onChanged(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
            Icon(Icons.event_busy_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'No schedules added yet',
                style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: schedules.length,
        itemBuilder: (context, index) {
          final schedule = schedules[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _medicineName(schedule.medicineId),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (!schedule.reminderEnabled)
                        Icon(Icons.notifications_off_outlined, size: 16, color: Colors.grey.shade500),
                      IconButton(
                        onPressed: () => _openEditModal(context, schedule),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        splashRadius: 20,
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        onPressed: () => _confirmDelete(context, schedule),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: Colors.redAccent,
                        splashRadius: 20,
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: schedule.days
                        .map((d) => Chip(
                      label: Text(d, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: schedule.times
                        .map((t) => Chip(
                      avatar: const Icon(Icons.access_time, size: 14),
                      label: Text(t.format(context), style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'From ${_formatDate(schedule.startDate)}'
                        '${schedule.endDate != null ? ' to ${_formatDate(schedule.endDate!)}' : ''}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Tab 2 — the add-schedule form (same UI as before, relocated).
/// -------------------------------------------------------------------------
class _AddScheduleTab extends StatelessWidget {
  const _AddScheduleTab({
    required this.medicines,
    required this.onSaved,
    required this.onRefreshMedicines,
    required this.isRefreshing,
  });

  final List<MedicineModel> medicines;
  final VoidCallback onSaved;
  final VoidCallback onRefreshMedicines;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Just added a medicine elsewhere and don't see it in the
          // dropdown below? Tap this to reload the medicine list.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Don't see your medicine below?",
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
                TextButton.icon(
                  onPressed: isRefreshing ? null : onRefreshMedicines,
                  icon: isRefreshing
                      ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ScheduleForm(
            medicines: medicines,
            submitLabel: 'Save Schedule',
            onSubmit: (schedule) async {
              await DBHelper.instance.insertSchedule(schedule);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Schedule saved')),
                );
              }
              onSaved();
            },
          ),
        ],
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Edit modal — opened from the list, pre-filled with the selected schedule.
/// -------------------------------------------------------------------------
class _EditScheduleModal extends StatelessWidget {
  const _EditScheduleModal({required this.schedule, required this.medicines});

  final MedicineScheduleModel schedule;
  final List<MedicineModel> medicines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Edit schedule',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ScheduleForm(
                  medicines: medicines,
                  initial: schedule,
                  submitLabel: 'Update Schedule',
                  onSubmit: (updated) async {
                    await DBHelper.instance.updateSchedule(updated);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Schedule updated')),
                      );
                      Navigator.pop(context, true);
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Shared form used by both the Add tab and the Edit modal.
/// Pass `initial` to pre-fill for editing; leave it null to add a new one.
/// -------------------------------------------------------------------------
class _ScheduleForm extends StatefulWidget {
  const _ScheduleForm({
    required this.medicines,
    this.initial,
    required this.onSubmit,
    required this.submitLabel,
  });

  final List<MedicineModel> medicines;
  final MedicineScheduleModel? initial;
  final Future<void> Function(MedicineScheduleModel schedule) onSubmit;
  final String submitLabel;

  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  MedicineModel? _selectedMedicine;
  late List<TimeOfDay> _times;
  late Set<String> _selectedDays;
  late DateTime _startDate;
  DateTime? _endDate;
  late bool _isActive;
  late bool _reminderEnabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    if (s != null) {
      final match = widget.medicines.where((m) => m.id == s.medicineId);
      _selectedMedicine = match.isEmpty ? null : match.first;
    }
    _times = List.of(s?.times ?? []);
    _selectedDays = Set.of(s?.days ?? {});
    _startDate = s?.startDate ?? DateTime.now();
    _endDate = s?.endDate;
    _isActive = s?.isActive ?? true;
    _reminderEnabled = s?.reminderEnabled ?? true;
  }

  @override
  void didUpdateWidget(covariant _ScheduleForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent reloaded its medicines list (e.g. a new medicine was
    // added elsewhere) and the currently selected medicine no longer
    // matches an entry by identity, re-resolve it by id so the dropdown
    // doesn't silently keep pointing at a stale object.
    if (_selectedMedicine != null &&
        !widget.medicines.any((m) => identical(m, _selectedMedicine))) {
      final match = widget.medicines.where((m) => m.id == _selectedMedicine!.id);
      _selectedMedicine = match.isEmpty ? null : match.first;
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time != null) setState(() => _times.add(time));
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _handleSubmit() async {
    if (_selectedMedicine == null || _times.isEmpty || _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before the start date')),
      );
      return;
    }

    setState(() => _saving = true);

    final now = DateTime.now();
    final schedule = MedicineScheduleModel(
      id: widget.initial?.id,
      medicineId: _selectedMedicine!.id!,
      times: List.of(_times),
      days: Set.of(_selectedDays),
      startDate: _startDate,
      endDate: _endDate,
      isActive: _isActive,
      reminderEnabled: _reminderEnabled,
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await widget.onSubmit(schedule);
      if (!mounted) return;
      if (widget.initial == null) {
        setState(() {
          _selectedMedicine = null;
          _times = [];
          _selectedDays = {};
          _startDate = DateTime.now();
          _endDate = null;
          _isActive = true;
          _reminderEnabled = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save schedule: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Medicine', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<MedicineModel>(
          value: _selectedMedicine,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: widget.medicines
              .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
              .toList(),
          onChanged: (val) => setState(() => _selectedMedicine = val),
        ),
        const SizedBox(height: 20),
        const Text('Days', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: kWeekdays.map((day) {
            final selected = _selectedDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: selected,
              onSelected: (val) {
                setState(() {
                  val ? _selectedDays.add(day) : _selectedDays.remove(day);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text('Times', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ..._times.asMap().entries.map((e) => Chip(
              label: Text(e.value.format(context)),
              onDeleted: () => setState(() => _times.removeAt(e.key)),
            )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add time'),
              onPressed: _pickTime,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Duration', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDate(isStart: true),
                child: Text('Start: ${_formatDate(_startDate)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDate(isStart: false),
                child: Text(_endDate == null ? 'End: not set' : 'End: ${_formatDate(_endDate!)}'),
              ),
            ),
            if (_endDate != null)
              IconButton(
                onPressed: () => setState(() => _endDate = null),
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Clear end date',
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active'),
          value: _isActive,
          onChanged: (val) => setState(() => _isActive = val),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reminders enabled'),
          value: _reminderEnabled,
          onChanged: (val) => setState(() => _reminderEnabled = val),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _handleSubmit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _saving
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(widget.submitLabel),
            ),
          ),
        ),
      ],
    );
  }
}