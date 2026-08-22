// ---------------------------------------------------------------------------
// MedicineModel
// Mirrors the toMap()/fromMap() pattern used by UserModel so it plugs
// straight into the same sqflite-based DBHelper.
// ---------------------------------------------------------------------------
class MedicineModel {
  final int? id;
  final String name;
  final String doseUnit; // e.g. "500 mg", "10 ml", "1 tablet"
  final String form; // e.g. Tablet, Capsule, Syrup, Injection, Drops...
  final String? note;
  final String? imagePath; // optional local file path to a photo of the medicine
  final DateTime startedAt;
  final DateTime? endAt; // null = ongoing / no end date set
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicineModel({
    this.id,
    required this.name,
    required this.doseUnit,
    required this.form,
    this.note,
    this.imagePath,
    required this.startedAt,
    this.endAt,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// sqflite has no native bool/DateTime column types, so booleans are
  /// stored as 0/1 and dates as ISO-8601 strings.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'doseUnit': doseUnit,
      'form': form,
      'note': note,
      'imagePath': imagePath,
      'startedAt': startedAt.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MedicineModel.fromMap(Map<String, dynamic> map) {
    return MedicineModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      doseUnit: map['doseUnit'] as String,
      form: map['form'] as String,
      note: map['note'] as String?,
      imagePath: map['imagePath'] as String?,
      startedAt: DateTime.parse(map['startedAt'] as String),
      endAt: map['endAt'] == null ? null : DateTime.parse(map['endAt'] as String),
      isActive: (map['isActive'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  MedicineModel copyWith({
    int? id,
    String? name,
    String? doseUnit,
    String? form,
    String? note,
    String? imagePath,
    DateTime? startedAt,
    DateTime? endAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      name: name ?? this.name,
      doseUnit: doseUnit ?? this.doseUnit,
      form: form ?? this.form,
      note: note ?? this.note,
      imagePath: imagePath ?? this.imagePath,
      startedAt: startedAt ?? this.startedAt,
      endAt: endAt ?? this.endAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}