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

  List<String> get currentOfferingIds =>
      List<String>.from(enrollmentSummary['currentOfferingIds'] ?? []);

  Student({
    required this.id,
    required this.name,
    required this.email,
    required this.programmeId,
    required this.enrollmentSummary,
  });

  factory Student.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Student(
        id: doc.id,
        name: data['name'] ?? 'No Name',
        email: data['email'] ?? '',
        programmeId: data['programmeId'] ?? '',
        enrollmentSummary: data['enrollmentSummary'] ?? {});
  }
}

class Lecturer {
  final String id;
  final String name;
  final String email;
  Lecturer({required this.id, required this.name, required this.email});

  factory Lecturer.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Lecturer(
        id: doc.id,
        name: data['name'] ?? 'No Name',
        email: data['email'] ?? '');
  }
}

class SchoolAdmin {
  final String id;
  final String name;
  final String email;
  SchoolAdmin({required this.id, required this.name, required this.email});

  factory SchoolAdmin.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return SchoolAdmin(
        id: doc.id,
        name: data['name'] ?? 'No Name',
        email: data['email'] ?? '');
  }
}

// --- THE USER SERVICE (MODIFIED FOR REAL-TIME UPDATES) ---

class UserService extends ChangeNotifier {
  User? _firebaseUser;
  Student? _student;
  Lecturer? _lecturer;
  SchoolAdmin? _schoolAdmin;
  UserRole _role = UserRole.unknown;
  bool _isLoading = true;

  // MODIFIED: Added stream subscriptions to manage real-time listeners
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
    // Cancel all previous listeners to prevent memory leaks
    await _cancelSubscriptions();

    _firebaseUser = user;
    _resetState(); // Reset all local user data

    if (user == null) {
      // If user is null, they are logged out. Finalize state.
      _isLoading = false;
      notifyListeners();
      return;
    }

    // User is logged in, start checking roles in order of priority.
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
        // If not an admin, stop listening to admin changes and check for lecturer
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
      // Only proceed if a role hasn't already been determined (i.e., not an admin)
      if (_role != UserRole.schoolAdmin) {
        if (snapshot.docs.isNotEmpty) {
          _lecturer = Lecturer.fromFirestore(snapshot.docs.first);
          _setRole(UserRole.lecturer, "Lecturer", _lecturer!.name);
        } else {
          // If not a lecturer, stop listening and check for student
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
      // Only proceed if a higher role hasn't been found
      if (_role != UserRole.schoolAdmin && _role != UserRole.lecturer) {
        if (snapshot.docs.isNotEmpty) {
          _student = Student.fromFirestore(snapshot.docs.first);
          _setRole(UserRole.student, "Student", _student!.name);
        } else {
          // If no document found at all, role remains unknown, stop loading.
          // The AuthService handles creating the default student document on first sign-in.
           _isLoading = false;
           notifyListeners();
        }
      }
    });
  }

  /// Centralized method to set the user's role and data and notify listeners.
  void _setRole(UserRole newRole, String roleName, String userName) {
    // Only show toast and update if the role has actually changed
    if (_role != newRole || _isLoading) {
      _role = newRole;
      if (!_isLoading) { // Don't show toast on initial load
         Fluttertoast.showToast(msg: "User role updated to $roleName");
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Resets all user-specific data.
  void _resetState() {
    _role = UserRole.unknown;
    _student = null;
    _lecturer = null;
    _schoolAdmin = null;
  }

  /// Cancels all active Firestore subscriptions.
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
    // Auth state listener will handle the rest
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
