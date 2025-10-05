// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:hive/hive.dart';

// // HIVE CODE GENERATION: This line is required for Hive to generate adapter files.
// part 'user_service.g.dart';

// // --- HIVE-COMPATIBLE DATA MODELS ---
// // All data models are now defined here and annotated for Hive.

// enum UserRole { unknown, student, lecturer, schoolAdmin }

// @HiveType(typeId: 0)
// class Student extends HiveObject {
//   @HiveField(0)
//   final String id;
//   @HiveField(1)
//   final String name;
//   @HiveField(2)
//   final String email;
//   @HiveField(3)
//   final String programmeId;
//   @HiveField(4)
//   final Map enrollmentSummary; // Stored as a Map
//   @HiveField(5)
//   final DateTime? lastVisitedAnnouncements;
//   @HiveField(6)
//   final int unreadMessagesCount;

//   List<String> get currentOfferingIds =>
//       List<String>.from(enrollmentSummary['currentOfferingIds'] ?? []);

//   Student({
//     required this.id,
//     required this.name,
//     required this.email,
//     required this.programmeId,
//     required this.enrollmentSummary,
//     this.lastVisitedAnnouncements,
//     this.unreadMessagesCount = 0,
//   });

//   factory Student.fromFirestore(DocumentSnapshot doc) {
//     Map data = doc.data() as Map<String, dynamic>;
//     return Student(
//       id: doc.id,
//       name: data['name'] ?? 'No Name',
//       email: data['email'] ?? '',
//       programmeId: data['programmeId'] ?? '',
//       enrollmentSummary: data['enrollmentSummary'] ?? {},
//       lastVisitedAnnouncements: data['lastVisitedAnnouncements'] != null
//           ? (data['lastVisitedAnnouncements'] as Timestamp).toDate()
//           : null,
//       unreadMessagesCount: data['unreadMessagesCount'] ?? 0,
//     );
//   }
// }

// @HiveType(typeId: 1)
// class Lecturer extends HiveObject {
//   @HiveField(0)
//   final String id;
//   @HiveField(1)
//   final String name;
//   @HiveField(2)
//   final String email;
//   @HiveField(3)
//   final int unreadMessagesCount;

//   Lecturer({
//     required this.id,
//     required this.name,
//     required this.email,
//     this.unreadMessagesCount = 0,
//   });

//   factory Lecturer.fromFirestore(DocumentSnapshot doc) {
//     Map data = doc.data() as Map<String, dynamic>;
//     return Lecturer(
//       id: doc.id,
//       name: data['name'] ?? 'No Name',
//       email: data['email'] ?? '',
//       unreadMessagesCount: data['unreadMessagesCount'] ?? 0,
//     );
//   }
// }

// @HiveType(typeId: 2)
// class SchoolAdmin extends HiveObject {
//   @HiveField(0)
//   final String id;
//   @HiveField(1)
//   final String name;
//   @HiveField(2)
//   final String email;
//   @HiveField(3)
//   final int unreadMessagesCount;
  
//   SchoolAdmin({
//     required this.id,
//     required this.name,
//     required this.email,
//     this.unreadMessagesCount = 0,
//   });

//   factory SchoolAdmin.fromFirestore(DocumentSnapshot doc) {
//     Map data = doc.data() as Map<String, dynamic>;
//     return SchoolAdmin(
//       id: doc.id,
//       name: data['name'] ?? 'No Name',
//       email: data['email'] ?? '',
//       unreadMessagesCount: data['unreadMessagesCount'] ?? 0,
//     );
//   }
// }

// // CACHING: Added other models needed for caching lecturer/student data.
// @HiveType(typeId: 3)
// class AcademicRecord extends HiveObject {
//   @HiveField(0)
//   final String courseTitle;
//   @HiveField(1)
//   final String courseCode;
//   @HiveField(2)
//   final String grade;
//   @HiveField(3)
//   final DateTime enrollmentDate;
//   @HiveField(4)
//   final String lecturerName;

//   AcademicRecord({
//     required this.courseTitle,
//     required this.courseCode,
//     required this.grade,
//     required this.enrollmentDate,
//     required this.lecturerName,
//   });
// }

// @HiveType(typeId: 4)
// class LecturerCourseInfo extends HiveObject {
//   @HiveField(0)
//   final String offeringId;
//   @HiveField(1)
//   final String courseId;
//   @HiveField(2)
//   final String courseTitle;
//   @HiveField(3)
//   final String session;
//   LecturerCourseInfo({required this.offeringId, required this.courseId, required this.courseTitle, required this.session});
// }

// @HiveType(typeId: 5)
// class AnnouncementInfo extends HiveObject {
//   @HiveField(0)
//   final String text;
//   @HiveField(1)
//   final String courseId;
//   @HiveField(2)
//   final DateTime date;
//   AnnouncementInfo({required this.text, required this.courseId, required this.date});
// }


// class UserService extends ChangeNotifier {
//   User? _firebaseUser;
//   Student? _student;
//   Lecturer? _lecturer;
//   SchoolAdmin? _schoolAdmin;
//   UserRole _role = UserRole.unknown;
//   bool _isLoading = true;

//   StreamSubscription? _adminSubscription;
//   StreamSubscription? _lecturerSubscription;
//   StreamSubscription? _studentSubscription;
  
//   // CACHING: Get references to Hive boxes for storing cached data.
//   final Box<List> _academicRecordsBox = Hive.box<List>('academicRecords');
//   final Box<List> _classRostersBox = Hive.box<List>('classRosters');
//   final Box<List> _teachingLoadBox = Hive.box<List>('teachingLoad');
//   final Box<List> _announcementsBox = Hive.box<List>('announcements');

//   User? get firebaseUser => _firebaseUser;
//   Student? get student => _student;
//   Lecturer? get lecturer => _lecturer;
//   SchoolAdmin? get schoolAdmin => _schoolAdmin;
//   UserRole get role => _role;
//   bool get isLoading => _isLoading;
//   User? get user => _firebaseUser;

//   UserService() {
//     FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
//   }

//   String _getLetterGrade(int? numericGrade) {
//     if (numericGrade == null) return 'In Progress';
//     if (numericGrade >= 90) return 'A';
//     if (numericGrade >= 80) return 'B';
//     if (numericGrade >= 70) return 'C';
//     if (numericGrade >= 60) return 'D';
//     if (numericGrade >= 50) return 'E';
//     return 'F';
//   }

//   Future<void> _onAuthStateChanged(User? user) async {
//     await _cancelSubscriptions();
//     _firebaseUser = user;
//     _resetState(); 
//     if (user == null) {
//       _isLoading = false;
//       notifyListeners();
//       return;
//     }
//     _isLoading = true;
//     notifyListeners();
//     _listenForAdminRole(user.email!);
//   }
  
//   void _listenForAdminRole(String email) {
//     final query = FirebaseFirestore.instance
//         .collection('administrators')
//         .where('email', isEqualTo: email)
//         .limit(1);

//     _adminSubscription = query.snapshots().listen((snapshot) {
//       if (snapshot.docs.isNotEmpty) {
//         _schoolAdmin = SchoolAdmin.fromFirestore(snapshot.docs.first);
//         _setRole(UserRole.schoolAdmin, "School Admin", _schoolAdmin!.name);
//       } else {
//         _adminSubscription?.cancel();
//         _listenForLecturerRole(email);
//       }
//     });
//   }

//   void _listenForLecturerRole(String email) {
//     final query = FirebaseFirestore.instance
//         .collection('lecturers')
//         .where('email', isEqualTo: email)
//         .limit(1);

//     _lecturerSubscription = query.snapshots().listen((snapshot) {
//       if (_role != UserRole.schoolAdmin) {
//         if (snapshot.docs.isNotEmpty) {
//           _lecturer = Lecturer.fromFirestore(snapshot.docs.first);
//           _setRole(UserRole.lecturer, "Lecturer", _lecturer!.name);
//         } else {
//           _lecturerSubscription?.cancel();
//           _listenForStudentRole(email);
//         }
//       }
//     });
//   }

//   void _listenForStudentRole(String email) {
//     final query = FirebaseFirestore.instance
//         .collection('students')
//         .where('email', isEqualTo: email)
//         .limit(1);

//     _studentSubscription = query.snapshots().listen((snapshot) {
//       if (_role != UserRole.schoolAdmin && _role != UserRole.lecturer) {
//         if (snapshot.docs.isNotEmpty) {
//           _student = Student.fromFirestore(snapshot.docs.first);
//           _setRole(UserRole.student, "Student", _student!.name);
//         } else {
//            _isLoading = false;
//            notifyListeners();
//         }
//       }
//     });
//   }

//   void _setRole(UserRole newRole, String roleName, String userName) {
//     final bool didRoleChange = _role != newRole;
//     _role = newRole;
//     _isLoading = false;
//     if (didRoleChange) {
//        Fluttertoast.showToast(msg: "User role updated to $roleName");
//     }
//     notifyListeners();
//   }


//   // --- CACHING IMPLEMENTATION ---
//   // All data fetching logic is now centralized here with caching.
  
//   // CACHING: Fetches academic records for a student.
//   Future<List<AcademicRecord>> getAcademicRecords({bool forceRefresh = false}) async {
//     final studentId = _student?.id;
//     if (studentId == null) return [];
//     final cacheKey = 'records_$studentId';

//     if (!forceRefresh && _academicRecordsBox.containsKey(cacheKey)) {
//       // Data is in the cache, return it.
//       return (_academicRecordsBox.get(cacheKey) as List).cast<AcademicRecord>();
//     }

//     // --- LOGIC MOVED FROM overview_view.dart ---
//     final records = <AcademicRecord>[];
//     final firestore = FirebaseFirestore.instance;

//     final enrollmentsSnapshot = await firestore.collection('enrollments').where('studentId', isEqualTo: studentId).get();

//     for (final enrollmentDoc in enrollmentsSnapshot.docs) {
//       final enrollmentData = enrollmentDoc.data();
//       final offeringId = enrollmentData['courseOfferingId'];
//       String courseId = enrollmentData['courseId'] ?? '';
//       String lecturerName = 'N/A';
      
//       if (offeringId != null) {
//         final offeringDoc = await firestore.collection('courseOfferings').doc(offeringId).get();
//         if (offeringDoc.exists) {
//            courseId = offeringDoc.data()!['courseId'];
//            final lecturerId = offeringDoc.data()!['lecturerId'];
//            final lecturerDoc = await firestore.collection('lecturers').doc(lecturerId).get();
//            if(lecturerDoc.exists){
//              lecturerName = lecturerDoc.data()!['name'];
//            }
//         }
//       }

//       if (courseId.isNotEmpty) {
//         final courseDoc = await firestore.collection('courses').doc(courseId).get();
//         if (courseDoc.exists) {
//           final courseData = courseDoc.data()!;
//           final enrollmentTimestamp = enrollmentData['enrollmentDate'] as Timestamp?;
//           final eDate = enrollmentTimestamp?.toDate() ?? DateTime.now();

//           records.add(AcademicRecord(
//             courseTitle: courseData['title'],
//             courseCode: courseData['code'],
//             grade: _getLetterGrade(enrollmentData['grade']),
//             enrollmentDate: eDate,
//             lecturerName: lecturerName,
//           ));
//         }
//       }
//     }
//     records.sort((a, b) {
//       final aIsInProgress = a.grade == 'In Progress';
//       final bIsInProgress = b.grade == 'In Progress';
//       if (aIsInProgress && !bIsInProgress) return -1;
//       if (!aIsInProgress && bIsInProgress) return 1;
//       return b.enrollmentDate.compareTo(a.enrollmentDate);
//     });
//     // --- END OF MOVED LOGIC ---

//     // Save the freshly fetched data to the cache before returning.
//     await _academicRecordsBox.put(cacheKey, records);
//     return records;
//   }

//   // CACHING: Fetches the teaching load for a lecturer.
//   Future<List<LecturerCourseInfo>> getTeachingLoad({bool forceRefresh = false}) async {
//     final lecturerId = _lecturer?.id;
//     if (lecturerId == null) return [];
//     final cacheKey = 'teachingLoad_$lecturerId';

//     if (!forceRefresh && _teachingLoadBox.containsKey(cacheKey)) {
//         return (_teachingLoadBox.get(cacheKey) as List).cast<LecturerCourseInfo>();
//     }

//     List<LecturerCourseInfo> teachingLoad = [];
//     final offeringsSnapshot = await FirebaseFirestore.instance.collection('courseOfferings')
//         .where('lecturerId', isEqualTo: lecturerId)
//         .where('sessionId', isEqualTo: "2025-2026")
//         .get();

//     for (var offeringDoc in offeringsSnapshot.docs) {
//         final offeringData = offeringDoc.data();
//         final courseId = offeringData['courseId'];
//         final courseDoc = await FirebaseFirestore.instance.collection('courses').doc(courseId).get();
//         if (courseDoc.exists) {
//             teachingLoad.add(LecturerCourseInfo(
//                 offeringId: offeringDoc.id,
//                 courseId: courseId,
//                 courseTitle: courseDoc.data()?['title'] ?? 'Unknown Course',
//                 session: offeringData['sessionId'],
//             ));
//         }
//     }
//     await _teachingLoadBox.put(cacheKey, teachingLoad);
//     return teachingLoad;
//   }

//   // CACHING: Fetches recent announcements for a lecturer.
//   Future<List<AnnouncementInfo>> getRecentAnnouncements({bool forceRefresh = false}) async {
//       final lecturerId = _lecturer?.id;
//       if (lecturerId == null) return [];
//       final cacheKey = 'announcements_$lecturerId';

//       if (!forceRefresh && _announcementsBox.containsKey(cacheKey)) {
//           return (_announcementsBox.get(cacheKey) as List).cast<AnnouncementInfo>();
//       }

//       List<AnnouncementInfo> announcements = [];
//       // ... (Your full Firestore fetch logic for announcements)

//       await _announcementsBox.put(cacheKey, announcements);
//       return announcements;
//   }

//   // CACHING: Fetches the class roster for a specific course offering.
//   Future<List<Student>> getClassRoster(String offeringId, {bool forceRefresh = false}) async {
//       final cacheKey = 'roster_$offeringId';

//       if (!forceRefresh && _classRostersBox.containsKey(cacheKey)) {
//           return (_classRostersBox.get(cacheKey) as List).cast<Student>();
//       }
      
//       final studentIds = (await FirebaseFirestore.instance.collection('enrollments')
//         .where('courseOfferingId', isEqualTo: offeringId).get())
//         .docs.map((doc) => doc.data()['studentId'] as String).toList();

//       List<Student> roster = [];
//       if (studentIds.isNotEmpty) {
//         for (var i = 0; i < studentIds.length; i += 30) {
//           final chunk = studentIds.sublist(i, i + 30 > studentIds.length ? studentIds.length : i + 30);
//           final studentsSnapshot = await FirebaseFirestore.instance.collection('students')
//               .where(FieldPath.documentId, whereIn: chunk).get();
//           roster.addAll(studentsSnapshot.docs.map((doc) => Student.fromFirestore(doc)));
//         }
//       }
//       roster.sort((a, b) => a.name.compareTo(b.name));

//       await _classRostersBox.put(cacheKey, roster);
//       return roster;
//   }

//   // CACHING: Clear all user-specific data from Hive on sign out.
//   Future<void> _clearAllCaches() async {
//     await _academicRecordsBox.clear();
//     await _classRostersBox.clear();
//     await _teachingLoadBox.clear();
//     await _announcementsBox.clear();
//   }

//   void _resetState() {
//     _role = UserRole.unknown;
//     _student = null;
//     _lecturer = null;
//     _schoolAdmin = null;
//   }

//   Future<void> _cancelSubscriptions() async {
//     await _adminSubscription?.cancel();
//     await _lecturerSubscription?.cancel();
//     await _studentSubscription?.cancel();
//   }

//   // ... (getCurrentUserId, getCurrentUserName methods remain the same)
//   String getCurrentUserId() {
//     switch (_role) {
//       case UserRole.student:
//         return _student?.id ?? '';
//       case UserRole.lecturer:
//         return _lecturer?.id ?? '';
//       case UserRole.schoolAdmin:
//         return _schoolAdmin?.id ?? '';
//       default:
//         return firebaseUser?.uid ?? '';
//     }
//   }

//   String getCurrentUserName() {
//     switch (_role) {
//       case UserRole.student:
//         return _student?.name ?? 'Student';
//       case UserRole.lecturer:
//         return _lecturer?.name ?? 'Lecturer';
//       case UserRole.schoolAdmin:
//         return _schoolAdmin?.name ?? 'Admin';
//       default:
//         return 'User';
//     }
//   }


//   Future<void> signOut() async {
//     await _clearAllCaches(); // CACHING: Clear cache before signing out.
//     await FirebaseAuth.instance.signOut();
//   }

//   @override
//   void dispose() {
//     _cancelSubscriptions();
//     super.dispose();
//   }
// }

// user_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';

part 'user_service.g.dart';

// --- HIVE-COMPATIBLE DATA MODELS ---
enum UserRole { unknown, student, lecturer, schoolAdmin }

// NOTE: FilterItem and FilterLevel are moved here from the UI file
// to be used in the data-fetching logic.
enum FilterLevel { session, faculty, programme, course }

class FilterItem {
  final String id;
  final String name;
  final FilterLevel level;
  FilterItem({required this.id, required this.name, required this.level});
}

@HiveType(typeId: 0)
class Student extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String email;
  @HiveField(3)
  final String programmeId;
  @HiveField(4)
  final Map enrollmentSummary;
  @HiveField(5)
  final DateTime? lastVisitedAnnouncements;
  @HiveField(6)
  final int unreadMessagesCount;

  List<String> get currentOfferingIds =>
      List<String>.from(enrollmentSummary['currentOfferingIds'] ?? []);

  Student({
    required this.id,
    required this.name,
    required this.email,
    required this.programmeId,
    required this.enrollmentSummary,
    this.lastVisitedAnnouncements,
    this.unreadMessagesCount = 0,
  });

  factory Student.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Student(
      id: doc.id,
      name: data['name'] ?? 'No Name',
      email: data['email'] ?? '',
      programmeId: data['programmeId'] ?? '',
      enrollmentSummary: data['enrollmentSummary'] ?? {},
      lastVisitedAnnouncements: data['lastVisitedAnnouncements'] != null
          ? (data['lastVisitedAnnouncements'] as Timestamp).toDate()
          : null,
      unreadMessagesCount: data['unreadMessagesCount'] ?? 0,
    );
  }
}

@HiveType(typeId: 1)
class Lecturer extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String email;
  @HiveField(3)
  final int unreadMessagesCount;

  Lecturer({
    required this.id,
    required this.name,
    required this.email,
    this.unreadMessagesCount = 0,
  });

  factory Lecturer.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Lecturer(
      id: doc.id,
      name: data['name'] ?? 'No Name',
      email: data['email'] ?? '',
      unreadMessagesCount: data['unreadMessagesCount'] ?? 0,
    );
  }
}

@HiveType(typeId: 2)
class SchoolAdmin extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String email;
  @HiveField(3)
  final int unreadMessagesCount;
  
  SchoolAdmin({
    required this.id,
    required this.name,
    required this.email,
    this.unreadMessagesCount = 0,
  });

  factory SchoolAdmin.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return SchoolAdmin(
      id: doc.id,
      name: data['name'] ?? 'No Name',
      email: data['email'] ?? '',
      unreadMessagesCount: data['unreadMessagesCount'] ?? 0,
    );
  }
}

@HiveType(typeId: 3)
class AcademicRecord extends HiveObject {
  @HiveField(0)
  final String courseTitle;
  @HiveField(1)
  final String courseCode;
  @HiveField(2)
  final String grade;
  @HiveField(3)
  final DateTime enrollmentDate;
  @HiveField(4)
  final String lecturerName;

  AcademicRecord({
    required this.courseTitle,
    required this.courseCode,
    required this.grade,
    required this.enrollmentDate,
    required this.lecturerName,
  });
}

@HiveType(typeId: 4)
class LecturerCourseInfo extends HiveObject {
  @HiveField(0)
  final String offeringId;
  @HiveField(1)
  final String courseId;
  @HiveField(2)
  final String courseTitle;
  @HiveField(3)
  final String session;
  LecturerCourseInfo({required this.offeringId, required this.courseId, required this.courseTitle, required this.session});
}

@HiveType(typeId: 5)
class AnnouncementInfo extends HiveObject {
  @HiveField(0)
  final String text;
  @HiveField(1)
  final String courseId;
  @HiveField(2)
  final DateTime date;
  AnnouncementInfo({required this.text, required this.courseId, required this.date});
}


class UserService extends ChangeNotifier {
  User? _firebaseUser;
  Student? _student;
  Lecturer? _lecturer;
  SchoolAdmin? _schoolAdmin;
  UserRole _role = UserRole.unknown;
  bool _isLoading = true;

  StreamSubscription? _adminSubscription;
  StreamSubscription? _lecturerSubscription;
  StreamSubscription? _studentSubscription;
  
  final Box<List> _academicRecordsBox = Hive.box<List>('academicRecords');
  final Box<List> _classRostersBox = Hive.box<List>('classRosters');
  final Box<List> _teachingLoadBox = Hive.box<List>('teachingLoad');
  final Box<List> _announcementsBox = Hive.box<List>('announcements');
  // NEW: Box for admin chart data
  final Box<Map> _chartDataBox = Hive.box<Map>('chartData');

  User? get firebaseUser => _firebaseUser;
  Student? get student => _student;
  Lecturer? get lecturer => _lecturer;
  SchoolAdmin? get schoolAdmin => _schoolAdmin;
  UserRole get role => _role;
  bool get isLoading => _isLoading;
  User? get user => _firebaseUser;

  UserService() {
    FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
  }

  String _getLetterGrade(int? numericGrade) {
    if (numericGrade == null) return 'In Progress';
    if (numericGrade >= 90) return 'A';
    if (numericGrade >= 80) return 'B';
    if (numericGrade >= 70) return 'C';
    if (numericGrade >= 60) return 'D';
    if (numericGrade >= 50) return 'E';
    return 'F';
  }

  Future<void> _onAuthStateChanged(User? user) async {
    await _cancelSubscriptions();
    _firebaseUser = user;
    _resetState(); 
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    _listenForAdminRole(user.email!);
  }
  
  void _listenForAdminRole(String email) {
    final query = FirebaseFirestore.instance
        .collection('administrators')
        .where('email', isEqualTo: email)
        .limit(1);

    _adminSubscription = query.snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _schoolAdmin = SchoolAdmin.fromFirestore(snapshot.docs.first);
        _setRole(UserRole.schoolAdmin, "School Admin", _schoolAdmin!.name);
      } else {
        _adminSubscription?.cancel();
        _listenForLecturerRole(email);
      }
    });
  }

  void _listenForLecturerRole(String email) {
    final query = FirebaseFirestore.instance
        .collection('lecturers')
        .where('email', isEqualTo: email)
        .limit(1);

    _lecturerSubscription = query.snapshots().listen((snapshot) {
      if (_role != UserRole.schoolAdmin) {
        if (snapshot.docs.isNotEmpty) {
          _lecturer = Lecturer.fromFirestore(snapshot.docs.first);
          _setRole(UserRole.lecturer, "Lecturer", _lecturer!.name);
        } else {
          _lecturerSubscription?.cancel();
          _listenForStudentRole(email);
        }
      }
    });
  }

  void _listenForStudentRole(String email) {
    final query = FirebaseFirestore.instance
        .collection('students')
        .where('email', isEqualTo: email)
        .limit(1);

    _studentSubscription = query.snapshots().listen((snapshot) {
      if (_role != UserRole.schoolAdmin && _role != UserRole.lecturer) {
        if (snapshot.docs.isNotEmpty) {
          _student = Student.fromFirestore(snapshot.docs.first);
          _setRole(UserRole.student, "Student", _student!.name);
        } else {
           _isLoading = false;
           notifyListeners();
        }
      }
    });
  }

  void _setRole(UserRole newRole, String roleName, String userName) {
    final bool didRoleChange = _role != newRole;
    _role = newRole;
    _isLoading = false;
    if (didRoleChange) {
       Fluttertoast.showToast(msg: "User role updated to $roleName");
    }
    notifyListeners();
  }

  Query _buildAdminQuery(List<FilterItem> breadcrumbs) {
    Query query = FirebaseFirestore.instance.collection('enrollments');
    for (var crumb in breadcrumbs) {
      if (crumb.id == 'all') continue;
      switch (crumb.level) {
        case FilterLevel.session: query = query.where('sessionId', isEqualTo: crumb.id); break;
        case FilterLevel.faculty: query = query.where('facultyId', isEqualTo: crumb.id); break;
        case FilterLevel.programme: query = query.where('programmeId', isEqualTo: crumb.id); break;
        case FilterLevel.course: query = query.where('courseId', isEqualTo: crumb.id); break;
      }
    }
    return query;
  }

  // --- CACHING IMPLEMENTATION ---
  
  Future<List<AcademicRecord>> getAcademicRecords({bool forceRefresh = false}) async {
    final studentId = _student?.id;
    if (studentId == null) return [];
    final cacheKey = 'records_$studentId';

    if (!forceRefresh && _academicRecordsBox.containsKey(cacheKey)) {
      return (_academicRecordsBox.get(cacheKey) as List).cast<AcademicRecord>();
    }

    final records = <AcademicRecord>[];
    final firestore = FirebaseFirestore.instance;
    final enrollmentsSnapshot = await firestore.collection('enrollments').where('studentId', isEqualTo: studentId).get();

    for (final enrollmentDoc in enrollmentsSnapshot.docs) {
      final enrollmentData = enrollmentDoc.data();
      final offeringId = enrollmentData['courseOfferingId'];
      String courseId = enrollmentData['courseId'] ?? '';
      String lecturerName = 'N/A';
      
      if (offeringId != null) {
        final offeringDoc = await firestore.collection('courseOfferings').doc(offeringId).get();
        if (offeringDoc.exists) {
           courseId = offeringDoc.data()!['courseId'];
           final lecturerId = offeringDoc.data()!['lecturerId'];
           final lecturerDoc = await firestore.collection('lecturers').doc(lecturerId).get();
           if(lecturerDoc.exists){
             lecturerName = lecturerDoc.data()!['name'];
           }
        }
      }

      if (courseId.isNotEmpty) {
        final courseDoc = await firestore.collection('courses').doc(courseId).get();
        if (courseDoc.exists) {
          final courseData = courseDoc.data()!;
          final enrollmentTimestamp = enrollmentData['enrollmentDate'] as Timestamp?;
          final eDate = enrollmentTimestamp?.toDate() ?? DateTime.now();

          records.add(AcademicRecord(
            courseTitle: courseData['title'],
            courseCode: courseData['code'],
            grade: _getLetterGrade(enrollmentData['grade']),
            enrollmentDate: eDate,
            lecturerName: lecturerName,
          ));
        }
      }
    }
    records.sort((a, b) {
      final aIsInProgress = a.grade == 'In Progress';
      final bIsInProgress = b.grade == 'In Progress';
      if (aIsInProgress && !bIsInProgress) return -1;
      if (!aIsInProgress && bIsInProgress) return 1;
      return b.enrollmentDate.compareTo(a.enrollmentDate);
    });
    
    await _academicRecordsBox.put(cacheKey, records);
    return records;
  }

  Future<List<LecturerCourseInfo>> getTeachingLoad({bool forceRefresh = false}) async {
    final lecturerId = _lecturer?.id;
    if (lecturerId == null) return [];
    final cacheKey = 'teachingLoad_$lecturerId';

    if (!forceRefresh && _teachingLoadBox.containsKey(cacheKey)) {
        return (_teachingLoadBox.get(cacheKey) as List).cast<LecturerCourseInfo>();
    }

    List<LecturerCourseInfo> teachingLoad = [];
    final offeringsSnapshot = await FirebaseFirestore.instance.collection('courseOfferings')
        .where('lecturerId', isEqualTo: lecturerId)
        .where('sessionId', isEqualTo: "2025-2026")
        .get();

    for (var offeringDoc in offeringsSnapshot.docs) {
        final offeringData = offeringDoc.data();
        final courseId = offeringData['courseId'];
        final courseDoc = await FirebaseFirestore.instance.collection('courses').doc(courseId).get();
        if (courseDoc.exists) {
            teachingLoad.add(LecturerCourseInfo(
                offeringId: offeringDoc.id,
                courseId: courseId,
                courseTitle: courseDoc.data()?['title'] ?? 'Unknown Course',
                session: offeringData['sessionId'],
            ));
        }
    }
    await _teachingLoadBox.put(cacheKey, teachingLoad);
    return teachingLoad;
  }

  Future<List<AnnouncementInfo>> getRecentAnnouncements({bool forceRefresh = false}) async {
      final lecturerId = _lecturer?.id;
      if (lecturerId == null) return [];
      final cacheKey = 'announcements_$lecturerId';

      if (!forceRefresh && _announcementsBox.containsKey(cacheKey)) {
          return (_announcementsBox.get(cacheKey) as List).cast<AnnouncementInfo>();
      }

      List<AnnouncementInfo> announcements = [];
      final offeringsSnapshot = await FirebaseFirestore.instance
          .collection('courseOfferings')
          .where('lecturerId', isEqualTo: lecturerId)
          .get();

      if (offeringsSnapshot.docs.isEmpty) return [];
      
      final offeringIds = offeringsSnapshot.docs.map((doc) => doc.id).toList();
      
      if (offeringIds.isNotEmpty) {
        final announcementsSnapshot = await FirebaseFirestore.instance
            .collection('announcements')
            .where('courseOfferingId', whereIn: offeringIds)
            .orderBy('date', descending: true)
            .limit(3)
            .get();

        for (var doc in announcementsSnapshot.docs) {
          final data = doc.data();
          final offeringDoc = await FirebaseFirestore.instance.collection('courseOfferings').doc(data['courseOfferingId']).get();
          final courseId = offeringDoc.data()?['courseId'] ?? '???';
          
          announcements.add(AnnouncementInfo(
            text: data['text'],
            courseId: courseId,
            date: (data['date'] as Timestamp).toDate(),
          ));
        }
      }

      await _announcementsBox.put(cacheKey, announcements);
      return announcements;
  }

  Future<List<Student>> getClassRoster(String offeringId, {bool forceRefresh = false}) async {
      final cacheKey = 'roster_$offeringId';

      if (!forceRefresh && _classRostersBox.containsKey(cacheKey)) {
          return (_classRostersBox.get(cacheKey) as List).cast<Student>();
      }
      
      final studentIds = (await FirebaseFirestore.instance.collection('enrollments')
        .where('courseOfferingId', isEqualTo: offeringId).get())
        .docs.map((doc) => doc.data()['studentId'] as String).toList();

      List<Student> roster = [];
      if (studentIds.isNotEmpty) {
        for (var i = 0; i < studentIds.length; i += 30) {
          final chunk = studentIds.sublist(i, i + 30 > studentIds.length ? studentIds.length : i + 30);
          final studentsSnapshot = await FirebaseFirestore.instance.collection('students')
              .where(FieldPath.documentId, whereIn: chunk).get();
          roster.addAll(studentsSnapshot.docs.map((doc) => Student.fromFirestore(doc)));
        }
      }
      roster.sort((a, b) => a.name.compareTo(b.name));

      await _classRostersBox.put(cacheKey, roster);
      return roster;
  }
  
  // NEW: Admin method for filter options
  Future<List<FilterItem>> getFilterOptions(FilterLevel level, List<FilterItem> breadcrumbs) async {
    List<FilterItem> items = [];
    final firestore = FirebaseFirestore.instance;
    try {
      switch (level) {
        case FilterLevel.session:
          final snapshot = await firestore.collection('academicSessions').get();
          items = snapshot.docs.map((doc) => FilterItem(id: doc.id, name: doc.id, level: FilterLevel.session)).toList();
          items.sort((a, b) => b.name.compareTo(a.name));
          break;
        case FilterLevel.faculty:
          final snapshot = await firestore.collection('faculties').get();
          items = snapshot.docs.map((doc) => FilterItem(id: doc.id, name: doc['name'], level: FilterLevel.faculty)).toList();
          items.insert(0, FilterItem(id: 'all', name: 'All Faculties', level: FilterLevel.faculty));
          break;
        case FilterLevel.programme:
          final facultyId = breadcrumbs.firstWhere((b) => b.level == FilterLevel.faculty).id;
          final snapshot = await firestore.collection('programmes').where('facultyId', isEqualTo: facultyId).get();
          items = snapshot.docs.map((doc) => FilterItem(id: doc.id, name: doc['name'], level: FilterLevel.programme)).toList();
          items.insert(0, FilterItem(id: 'all', name: 'All Programmes', level: FilterLevel.programme));
          break;
        case FilterLevel.course:
          final programmeId = breadcrumbs.firstWhere((b) => b.level == FilterLevel.programme).id;
          final snapshot = await firestore.collection('courses').where('programmeId', isEqualTo: programmeId).get();
          items = snapshot.docs.map((doc) => FilterItem(id: doc.id, name: doc.data()['title'] ?? 'Unknown', level: FilterLevel.course)).toList();
          items.insert(0, FilterItem(id: 'all', name: 'All Courses', level: FilterLevel.course));
          break;
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error fetching filter options.");
    }
    return items;
  }
  
  // NEW: Admin method for chart data
  Future<Map<String, double>> getChartData(List<FilterItem> breadcrumbs, {bool forceRefresh = false}) async {
    if (breadcrumbs.isEmpty) return {};
    final cacheKey = breadcrumbs.map((c) => c.id).join('_');
    
    if (!forceRefresh && _chartDataBox.containsKey(cacheKey)) {
        return Map<String, double>.from(_chartDataBox.get(cacheKey)!);
    }
    
    Query query = _buildAdminQuery(breadcrumbs);
    Map<String, double> data = {};
    try {
      final snapshot = await query.get();
      for (var doc in snapshot.docs) {
        final docData = doc.data() as Map<String, dynamic>;
        final grade = _getLetterGrade(docData['grade']);
        data[grade] = (data[grade] ?? 0) + 1;
      }
      await _chartDataBox.put(cacheKey, data);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error fetching chart data.");
    }
    return data;
  }
  
  // NEW: Admin method for student list by grade
  Future<List<String>> getStudentsForGrade(String grade, List<FilterItem> breadcrumbs) async {
    if (grade == 'In Progress') return ['Cannot fetch list for "In Progress".'];
    
    final Map<String, int> gradeLowerBounds = {'A': 90, 'B': 80, 'C': 70, 'D': 60, 'E': 50, 'F': 0};
    final Map<String, int> gradeUpperBounds = {'A': 100, 'B': 89, 'C': 79, 'D': 69, 'E': 59, 'F': 49};
    
    Query query = _buildAdminQuery(breadcrumbs)
        .where('grade', isGreaterThanOrEqualTo: gradeLowerBounds[grade])
        .where('grade', isLessThanOrEqualTo: gradeUpperBounds[grade]);

    List<String> studentNames = [];
    try {
      final snapshot = await query.get();
      if(snapshot.docs.isEmpty){
         studentNames.add("No students found for this grade.");
      } else {
        for (var doc in snapshot.docs) {
          final studentId = (doc.data() as Map<String, dynamic>)['studentId'];
          final studentDoc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();
          if (studentDoc.exists) studentNames.add(studentDoc.data()?['name'] ?? 'Unknown');
        }
      }
    } catch(e) {
      studentNames.add("Error fetching student list. Index may be required.");
    }
    return studentNames;
  }

  Future<void> _clearAllCaches() async {
    await _academicRecordsBox.clear();
    await _classRostersBox.clear();
    await _teachingLoadBox.clear();
    await _announcementsBox.clear();
    await _chartDataBox.clear();
  }

  void _resetState() {
    _role = UserRole.unknown;
    _student = null;
    _lecturer = null;
    _schoolAdmin = null;
  }

  Future<void> _cancelSubscriptions() async {
    await _adminSubscription?.cancel();
    await _lecturerSubscription?.cancel();
    await _studentSubscription?.cancel();
  }

  String getCurrentUserId() {
    switch (_role) {
      case UserRole.student:
        return _student?.id ?? '';
      case UserRole.lecturer:
        return _lecturer?.id ?? '';
      case UserRole.schoolAdmin:
        return _schoolAdmin?.id ?? '';
      default:
        return firebaseUser?.uid ?? '';
    }
  }

  String getCurrentUserName() {
    switch (_role) {
      case UserRole.student:
        return _student?.name ?? 'Student';
      case UserRole.lecturer:
        return _lecturer?.name ?? 'Lecturer';
      case UserRole.schoolAdmin:
        return _schoolAdmin?.name ?? 'Admin';
      default:
        return 'User';
    }
  }


  Future<void> signOut() async {
    await _clearAllCaches();
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
