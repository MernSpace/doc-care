// features/schedule/models/medicine_schedule_model.dart
import 'package:flutter/material.dart';

class MedicineScheduleModel {
  final int? id;
  final int medicineId; // FK -> MedicineModel.id
  final List<TimeOfDay> times;
  final Set<String> days; // e.g. {'Mon', 'Wed', 'Fri'}
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool reminderEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicineScheduleModel({
    this.id,
    required this.medicineId,
    required this.times,
    required this.days,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.reminderEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// TimeOfDay -> "HH:mm", stored as a comma-separated string.
  static String _encodeTimes(List<TimeOfDay> times) {
    return times
        .map((t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
        .join(',');
  }

  static List<TimeOfDay> _decodeTimes(String raw) {
    if (raw.isEmpty) return [];
    return raw.split(',').map((s) {
      final parts = s.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }).toList();
  }

  static String _encodeDays(Set<String> days) => days.join(',');

  static Set<String> _decodeDays(String raw) =>
      raw.isEmpty ? <String>{} : raw.split(',').toSet();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'medicineId': medicineId,
      'times': _encodeTimes(times),
      'days': _encodeDays(days),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MedicineScheduleModel.fromMap(Map<String, dynamic> map) {
    return MedicineScheduleModel(
      id: map['id'] as int?,
      medicineId: map['medicineId'] as int,
      times: _decodeTimes(map['times'] as String),
      days: _decodeDays(map['days'] as String),
      startDate: DateTime.parse(map['startDate'] as String),
      endDate:
      map['endDate'] == null ? null : DateTime.parse(map['endDate'] as String),
      isActive: (map['isActive'] as int) == 1,
      reminderEnabled: (map['reminderEnabled'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  MedicineScheduleModel copyWith({
    int? id,
    int? medicineId,
    List<TimeOfDay>? times,
    Set<String>? days,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    bool? reminderEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicineScheduleModel(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      times: times ?? this.times,
      days: days ?? this.days,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}