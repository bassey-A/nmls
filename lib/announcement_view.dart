import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'user_service.dart';
// import 'notification_service.dart'; // <-- MODIFIED: Added import

class Announcement {
  final String text;
  final String courseId;
  final DateTime date;

  Announcement({required this.text, required this.courseId, required this.date});

  factory Announcement.fromFirestore(DocumentSnapshot doc, String courseId) {
    final data = doc.data() as Map<String, dynamic>;
    return Announcement(
      text: data['text'] ?? '',
      courseId: courseId,
      date: (data['date'] as Timestamp).toDate(),
    );
  }
}

class AnnouncementPage extends StatefulWidget {
  const AnnouncementPage({super.key});

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  Stream<List<Announcement>>? _announcementsStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // We only need to initialize the stream here now
    final userService = Provider.of<UserService>(context);
    _initializeStream(userService);
  }

  void _initializeStream(UserService userService) {
    if (userService.isLoading) {
      return;
    }

    List<String>? offeringIds;
    if (userService.role == UserRole.student && userService.student != null) {
      offeringIds = userService.student!.currentOfferingIds;
    } else if (userService.role == UserRole.lecturer && userService.lecturer != null) {
      _fetchLecturerOfferingsAndSetStream(userService.lecturer!.id);
      return; 
    }
    
    _setStreamForOfferings(offeringIds);
  }

  Future<void> _fetchLecturerOfferingsAndSetStream(String lecturerId) async {
    if (!mounted) return;

    final offeringsSnapshot = await FirebaseFirestore.instance
        .collection('courseOfferings')
        .where('lecturerId', isEqualTo: lecturerId)
        .get();
    
    final offeringIds = offeringsSnapshot.docs.map((doc) => doc.id).toList();
    
    if (mounted) {
      _setStreamForOfferings(offeringIds);
    }
  }

  void _setStreamForOfferings(List<String>? offeringIds) {
     if (mounted) {
      setState(() {
        if (offeringIds != null && offeringIds.isNotEmpty) {
          _announcementsStream = FirebaseFirestore.instance
              .collection('announcements')
              .where('courseOfferingId', whereIn: offeringIds)
              .orderBy('date', descending: true)
              .snapshots()
              .asyncMap((snapshot) async {
                List<Announcement> announcements = [];
                for (var doc in snapshot.docs) {
                  final data = doc.data();
                  final offeringDoc = await FirebaseFirestore.instance.collection('courseOfferings').doc(data['courseOfferingId']).get();
                  final courseId = offeringDoc.data()?['courseId'] ?? '???';
                  announcements.add(Announcement.fromFirestore(doc, courseId));
                }
                return announcements;
              });
        } else {
          _announcementsStream = Stream.value([]);
        }
      });
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Announcement>>(
        stream: _announcementsStream,
        builder: (context, snapshot) {
          if (_announcementsStream == null || snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No announcements for your courses.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final announcements = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: ListTile(
                  leading: const Icon(Icons.campaign_outlined, color: Colors.amber),
                  title: Text(announcement.text),
                  subtitle: Text(
                    '${announcement.courseId} - ${DateFormat.yMMMd().add_jm().format(announcement.date)}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
