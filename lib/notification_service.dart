// notification_service.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class NotificationService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  UserService? _userService;

  StreamSubscription? _announcementSub;
  StreamSubscription? _messageSub;

  int _unreadAnnouncements = 0;
  int get unreadAnnouncements => _unreadAnnouncements;

  int _unreadMessages = 0;
  int get unreadMessages => _unreadMessages;
  
  void startListening(UserService userService) {
    if (_userService != null) {
      _userService!.removeListener(_onUserChanged);
    }
    _userService = userService;
    _userService!.addListener(_onUserChanged);
    _onUserChanged();
  }
    
  void _onUserChanged() {
    stopListening();
    debugPrint("stopListening completed");
    if (_userService == null) return;
    final role = _userService!.role;
    final student = _userService!.student;
    final lecturer = _userService!.lecturer;
    final schoolAdmin = _userService!.schoolAdmin;

    if (role == UserRole.student && student != null) {
      _listenForStudentAnnouncements(student);
      _listenForMessages(student.id, 'students');
    } else if (role == UserRole.lecturer && lecturer != null) {
      _listenForMessages(lecturer.id, 'lecturers');
    } else if (role == UserRole.schoolAdmin && schoolAdmin != null) {
      _listenForMessages(schoolAdmin.id, 'administrators');
    }
  }

  void _listenForStudentAnnouncements(Student student) {
    if (student.currentOfferingIds.isEmpty) return;
    
    final lastVisited = student.lastVisitedAnnouncements ?? DateTime.fromMillisecondsSinceEpoch(0);
    final query = _db
        .collection('announcements')
        .where('courseOfferingId', whereIn: student.currentOfferingIds)
        .where('date', isGreaterThan: Timestamp.fromDate(lastVisited));

    _announcementSub = query.snapshots().listen((snapshot) {
      debugPrint("Announcement snapshot received with ${snapshot.size} new announcements");
      _unreadAnnouncements = snapshot.size;
      notifyListeners();
    }, onError: (error) {
      debugPrint("Error listening to announcements: $error");
    });
  }

  void _listenForMessages(String userId, String collectionName) {
    _messageSub = _db.collection(collectionName).doc(userId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _unreadMessages = snapshot.data()?['unreadMessagesCount'] ?? 0;
      } else {
        _unreadMessages = 0;
      }
      notifyListeners();
    });
  }

  Future<void> clearAnnouncementsCount() async {
    if (_unreadAnnouncements == 0 || _userService?.student == null) return;
    
    _unreadAnnouncements = 0;
    notifyListeners();
    
    await _db.collection('students').doc(_userService!.student!.id).update({
      'lastVisitedAnnouncements': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearMessagesCount() async {
     if (_unreadMessages == 0 || _userService == null) return;
     _unreadMessages = 0;
     notifyListeners();

     String? userId;
     String? collectionName;
     if (_userService!.role == UserRole.student) {
       userId = _userService!.student?.id;
       collectionName = 'students';
     } else if (_userService!.role == UserRole.lecturer) {
       userId = _userService!.lecturer?.id;
       collectionName = 'lecturers';
     } else if (_userService!.role == UserRole.schoolAdmin) {
       userId = _userService!.schoolAdmin?.id;
       collectionName = 'administrators';
     }
     
     if (userId != null && collectionName != null) {
        await _db.collection(collectionName).doc(userId).update({
          'unreadMessagesCount': 0,
        });
     }
  }

  void stopListening() {
    _announcementSub?.cancel();
    _messageSub?.cancel();
    _announcementSub = null; 
    _messageSub = null;
    _unreadAnnouncements = 0;
    _unreadMessages = 0;
  }

  @override
  void dispose() {
    debugPrint("Disposing NotificationService.");
    _userService?.removeListener(_onUserChanged);
    stopListening();
    super.dispose();
  }
}
