// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudentAdapter extends TypeAdapter<Student> {
  @override
  final int typeId = 0;

  @override
  Student read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Student(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Student obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AcademicRecordAdapter extends TypeAdapter<AcademicRecord> {
  @override
  final int typeId = 1;

  @override
  AcademicRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AcademicRecord(
      courseTitle: fields[0] as String,
      courseCode: fields[1] as String,
      grade: fields[2] as String,
      enrollmentDate: fields[3] as DateTime,
      lecturerName: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AcademicRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.courseTitle)
      ..writeByte(1)
      ..write(obj.courseCode)
      ..writeByte(2)
      ..write(obj.grade)
      ..writeByte(3)
      ..write(obj.enrollmentDate)
      ..writeByte(4)
      ..write(obj.lecturerName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AcademicRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
