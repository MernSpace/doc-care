import 'package:flutter/material.dart';
import 'package:my_app/core/database/tables/medicines_model.dart';
import 'package:my_app/core/database/tables/db.dart';
import 'package:my_app/core/constants/app_colors.dart';

const List<Map<String, dynamic>> kMedicineForms = [
  {'label': 'Tablet', 'icon': Icons.medication_outlined},
  {'label': 'Capsule', 'icon': Icons.medication_liquid_outlined},
  {'label': 'Syrup', 'icon': Icons.local_drink_outlined},
  {'label': 'Injection', 'icon': Icons.vaccines_outlined},
  {'label': 'Drops', 'icon': Icons.water_drop_outlined},
  {'label': 'Cream', 'icon': Icons.spa_outlined},
  {'label': 'Inhaler', 'icon': Icons.air_outlined},
  {'label': 'Other', 'icon': Icons.category_outlined},
];

/// -------------------------------------------------------------------------
/// Top-level screen: "All Medicines" + "Add Medicine" tabs.
/// This replaces the old standalone AddMedicineScreen as the entry point —
/// push/route to `MedicinesScreen` instead.
/// -------------------------------------------------------------------------
class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({Key? key}) : super(key: key);

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<MedicineModel> _medicines = [];
  bool _isLoadingList = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMedicines();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    setState(() => _isLoadingList = true);
    try {
      // NOTE: adjust the method name below to match your DBHelper API.
      final list = await DBHelper.instance.getMedicines();
      if (!mounted) return;
      setState(() {
        _medicines = list;
        _isLoadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingList = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load medicines: $e')),
      );
    }
  }

  void _onMedicineSaved() {
    _loadMedicines();
    _tabController.animateTo(0); // jump to "All Medicines" after a save
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
          labelColor: kBrandColor,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: kBrandColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'ALL MEDICINES', icon: Icon(Icons.list_alt_outlined)),
            Tab(text: 'ADD MEDICINE', icon: Icon(Icons.add_circle_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AllMedicinesTab(
            medicines: _medicines,
            isLoading: _isLoadingList,
            onChanged: _loadMedicines,
          ),
          _AddMedicineTab(onSaved: _onMedicineSaved),
        ],
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Tab 1 — list of saved medicines with Edit / Delete actions.
/// -------------------------------------------------------------------------
class _AllMedicinesTab extends StatelessWidget {
  const _AllMedicinesTab({
    required this.medicines,
    required this.isLoading,
    required this.onChanged,
  });

  final List<MedicineModel> medicines;
  final bool isLoading;
  final VoidCallback onChanged;

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  IconData _iconForForm(String form) {
    return kMedicineForms.firstWhere(
          (f) => f['label'] == form,
      orElse: () => kMedicineForms.last,
    )['icon'] as IconData;
  }

  Future<void> _confirmDelete(BuildContext context, MedicineModel medicine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete medicine'),
        content: Text('Are you sure you want to delete "${medicine.name}"?'),
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
      // NOTE: adjust to match your DBHelper API + MedicineModel's id field.
      await DBHelper.instance.deleteMedicine(medicine.id!);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicine deleted'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete medicine: $e')),
        );
      }
    }
  }

  Future<void> _openEditModal(BuildContext context, MedicineModel medicine) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditMedicineModal(medicine: medicine),
    );
    if (updated == true) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: kBrandColor));
    }

    if (medicines.isEmpty) {
      return RefreshIndicator(
        color: kBrandColor,
        onRefresh: () async => onChanged(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
            Icon(Icons.medication_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'No medicines added yet',
                style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: kBrandColor,
      onRefresh: () async => onChanged(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: medicines.length,
        itemBuilder: (context, index) {
          final medicine = medicines[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: kBrandColor.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kBrandColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconForForm(medicine.form), color: kBrandColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              medicine.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (medicine.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${medicine.form} · ${medicine.doseUnit}',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From ${_formatDate(medicine.startedAt)}'
                            '${medicine.endAt != null ? ' to ${_formatDate(medicine.endAt!)}' : ''}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                      ),
                      if (medicine.note != null && medicine.note!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          medicine.note!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      onPressed: () => _openEditModal(context, medicine),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: kBrandColor,
                      splashRadius: 20,
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      onPressed: () => _confirmDelete(context, medicine),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.redAccent,
                      splashRadius: 20,
                      tooltip: 'Delete',
                    ),
                  ],
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
/// Tab 2 — the add-medicine form (same UI as before, just relocated).
/// -------------------------------------------------------------------------
class _AddMedicineTab extends StatelessWidget {
  const _AddMedicineTab({required this.onSaved});

  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: kBrandColor.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Medicine details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MedicineForm(
                    submitLabel: 'SAVE MEDICINE',
                    onSubmit: (medicine) async {
                      // NOTE: adjust to match your DBHelper API.
                      await DBHelper.instance.insertMedicine(medicine);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Medicine saved successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                      onSaved();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Edit modal — opened from the list, pre-filled with the selected medicine.
/// -------------------------------------------------------------------------
class _EditMedicineModal extends StatelessWidget {
  const _EditMedicineModal({required this.medicine});

  final MedicineModel medicine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F9FB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SingleChildScrollView(
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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Edit medicine',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
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
              _MedicineForm(
                initial: medicine,
                submitLabel: 'UPDATE MEDICINE',
                onSubmit: (updated) async {
                  // NOTE: adjust to match your DBHelper API.
                  await DBHelper.instance.updateMedicine(updated);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Medicine updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pop(context, true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Shared form body used by both the Add tab and the Edit modal.
/// Pass `initial` to pre-fill for editing; leave it null to add a new one.
/// -------------------------------------------------------------------------
class _MedicineForm extends StatefulWidget {
  const _MedicineForm({
    this.initial,
    required this.onSubmit,
    required this.submitLabel,
  });

  final MedicineModel? initial;
  final Future<void> Function(MedicineModel medicine) onSubmit;
  final String submitLabel;

  @override
  State<_MedicineForm> createState() => _MedicineFormState();
}

class _MedicineFormState extends State<_MedicineForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _doseUnitController;
  late final TextEditingController _noteController;

  late String _selectedForm;
  late DateTime _startedAt;
  DateTime? _endAt;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _nameController = TextEditingController(text: m?.name ?? '');
    _doseUnitController = TextEditingController(text: m?.doseUnit ?? '');
    _noteController = TextEditingController(text: m?.note ?? '');
    _selectedForm = m?.form ?? kMedicineForms.first['label'] as String;
    _startedAt = m?.startedAt ?? DateTime.now();
    _endAt = m?.endAt;
    _isActive = m?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseUnitController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startedAt : (_endAt ?? _startedAt);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: kBrandColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startedAt = picked;
        if (_endAt != null && _endAt!.isBefore(_startedAt)) {
          _endAt = null;
        }
      } else {
        _endAt = picked;
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

  /// Only used after adding a new medicine, so the form is ready for the
  /// next entry. Editing doesn't reset — the modal just closes.
  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _doseUnitController.clear();
    _noteController.clear();
    setState(() {
      _selectedForm = kMedicineForms.first['label'] as String;
      _startedAt = DateTime.now();
      _endAt = null;
      _isActive = true;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endAt != null && _endAt!.isBefore(_startedAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before the start date')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final medicine = MedicineModel(
      id: widget.initial?.id, // NOTE: requires MedicineModel to have an `id` field.
      name: _nameController.text.trim(),
      doseUnit: _doseUnitController.text.trim(),
      form: _selectedForm,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      startedAt: _startedAt,
      endAt: _endAt,
      isActive: _isActive,
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await widget.onSubmit(medicine);
      if (!mounted) return;
      if (widget.initial == null) {
        _resetForm(); // adding: clear the form for the next entry
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save medicine: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MedicineTextField(
            controller: _nameController,
            label: 'Medicine name',
            icon: Icons.medication_outlined,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the medicine name';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _MedicineTextField(
            controller: _doseUnitController,
            label: 'Dose (e.g. 500 mg, 1 tablet)',
            icon: Icons.straighten_outlined,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the dose';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _selectedForm,
            decoration: InputDecoration(
              labelText: 'Medicine Type',
              prefixIcon: Icon(
                kMedicineForms.firstWhere((f) => f['label'] == _selectedForm)['icon']
                as IconData,
                color: kBrandColor,
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFFF6FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBrandColor, width: 1.4),
              ),
            ),
            items: kMedicineForms
                .map((f) => DropdownMenuItem<String>(
              value: f['label'] as String,
              child: Text(f['label'] as String),
            ))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedForm = value);
            },
          ),
          const SizedBox(height: 14),
          _MedicineTextField(
            controller: _noteController,
            label: 'Note (optional)',
            icon: Icons.notes_outlined,
            textInputAction: TextInputAction.done,
            maxLines: 3,
            validator: (_) => null,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DatePickerField(
                  label: 'Started at',
                  value: _formatDate(_startedAt),
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DatePickerField(
                  label: 'End at (optional)',
                  value: _endAt == null ? 'Not set' : _formatDate(_endAt!),
                  onTap: () => _pickDate(isStart: false),
                  onClear: _endAt == null ? null : () => setState(() => _endAt = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.toggle_on_outlined, size: 18, color: kBrandColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Active reminder',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
              Switch(
                value: _isActive,
                activeColor: kBrandColor,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrandColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                widget.submitLabel,
                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable input field.
// ---------------------------------------------------------------------------
class _MedicineTextField extends StatelessWidget {
  const _MedicineTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kBrandColor, size: 20),
        filled: true,
        fillColor: const Color(0xFFF6FAFC),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kBrandColor, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tappable "date field" that opens the native date picker.
// ---------------------------------------------------------------------------
class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: kBrandColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close, size: 14, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}