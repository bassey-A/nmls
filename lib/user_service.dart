import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

// --- DATA MODELS FOR EACH USER ROLE ---
enum UserRole { unknown, student, lecturer, schoolAdmin }

class Student {
  final String id;
  final String name;
  final String email;
  final String programmeId;
  final Map<String, dynamic> enrollmentSummary;
  final DateTime? lastVisitedAnnouncements;
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
// ... (Lecturer and SchoolAdmin models remain the same)
class Lecturer {
  final String id;
  final String name;
  final String email;
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

class SchoolAdmin {
  final String id;
  final String name;
  final String email;
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
    if (_role != newRole || _isLoading) {
      _role = newRole;
      if (!_isLoading) {
         Fluttertoast.showToast(msg: "User role updated to $roleName");
      }
    }
    _isLoading = false;
    notifyListeners();
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
    _adminSubscription = null;
    _lecturerSubscription = null;
    _studentSubscription = null;
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
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
