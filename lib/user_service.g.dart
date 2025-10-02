// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_service.dart';

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
      programmeId: fields[3] as String,
      enrollmentSummary: (fields[4] as Map).cast<dynamic, dynamic>(),
      lastVisitedAnnouncements: fields[5] as DateTime?,
      unreadMessagesCount: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Student obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.programmeId)
      ..writeByte(4)
      ..write(obj.enrollmentSummary)
      ..writeByte(5)
      ..write(obj.lastVisitedAnnouncements)
      ..writeByte(6)
      ..write(obj.unreadMessagesCount);
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

class LecturerAdapter extends TypeAdapter<Lecturer> {
  @override
  final int typeId = 1;

  @override
  Lecturer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Lecturer(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
      unreadMessagesCount: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Lecturer obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.unreadMessagesCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LecturerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SchoolAdminAdapter extends TypeAdapter<SchoolAdmin> {
  @override
  final int typeId = 2;

  @override
  SchoolAdmin read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SchoolAdmin(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
      unreadMessagesCount: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SchoolAdmin obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.unreadMessagesCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchoolAdminAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AcademicRecordAdapter extends TypeAdapter<AcademicRecord> {
  @override
  final int typeId = 3;

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

class LecturerCourseInfoAdapter extends TypeAdapter<LecturerCourseInfo> {
  @override
  final int typeId = 4;

  @override
  LecturerCourseInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LecturerCourseInfo(
      offeringId: fields[0] as String,
      courseId: fields[1] as String,
      courseTitle: fields[2] as String,
      session: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LecturerCourseInfo obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.offeringId)
      ..writeByte(1)
      ..write(obj.courseId)
      ..writeByte(2)
      ..write(obj.courseTitle)
      ..writeByte(3)
      ..write(obj.session);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LecturerCourseInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AnnouncementInfoAdapter extends TypeAdapter<AnnouncementInfo> {
  @override
  final int typeId = 5;

  @override
  AnnouncementInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AnnouncementInfo(
      text: fields[0] as String,
      courseId: fields[1] as String,
      date: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AnnouncementInfo obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.courseId)
      ..writeByte(2)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnouncementInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
