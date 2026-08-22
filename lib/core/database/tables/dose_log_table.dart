// features/dose_log/models/dose_log_model.dart

class DoseLogModel {
  final int? id;
  final int medicineId; // FK -> MedicineModel.id
  final int? scheduleId; // FK -> MedicineScheduleModel.id (nullable for ad-hoc doses)
  final DateTime scheduledTime;
  final bool taken;
  final DateTime? takenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  DoseLogModel({
    this.id,
    required this.medicineId,
    this.scheduleId,
    required this.scheduledTime,
    this.taken = false,
    this.takenAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'medicineId': medicineId,
      'scheduleId': scheduleId,
      'scheduledTime': scheduledTime.toIso8601String(),
      'taken': taken ? 1 : 0,
      'takenAt': takenAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DoseLogModel.fromMap(Map<String, dynamic> map) {
    return DoseLogModel(
      id: map['id'] as int?,
      medicineId: map['medicineId'] as int,
      scheduleId: map['scheduleId'] as int?,
      scheduledTime: DateTime.parse(map['scheduledTime'] as String),
      taken: (map['taken'] as int) == 1,
      takenAt: map['takenAt'] == null ? null : DateTime.parse(map['takenAt'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  DoseLogModel copyWith({
    int? id,
    int? medicineId,
    int? scheduleId,
    DateTime? scheduledTime,
    bool? taken,
    DateTime? takenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoseLogModel(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      scheduleId: scheduleId ?? this.scheduleId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      taken: taken ?? this.taken,
      takenAt: takenAt ?? this.takenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}