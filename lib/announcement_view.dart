import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'user_service.dart';

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
    // Use listen: true so the view rebuilds if the user data changes (e.g., login/logout)
    final userService = Provider.of<UserService>(context);
    _initializeStream(userService);
  }

  void _initializeStream(UserService userService) {
    if (userService.isLoading) {
      // Don't set the stream while user data is still loading.
      return;
    }

    List<String>? offeringIds;
    if (userService.role == UserRole.student && userService.student != null) {
      offeringIds = userService.student!.enrollmentSummary['currentOfferingIds']?.cast<String>();
    } else if (userService.role == UserRole.lecturer && userService.lecturer != null) {
      // For lecturers, we need to fetch their offerings asynchronously first
      _fetchLecturerOfferingsAndSetStream(userService.lecturer!.id);
      return; // Return early, the stream will be set in the async method
    }
    
    // This will handle both students with courses and the case where a user has no offerings.
    _setStreamForOfferings(offeringIds);
  }

  Future<void> _fetchLecturerOfferingsAndSetStream(String lecturerId) async {
    // This is an async gap, so we need to check if the widget is still mounted.
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
     // Ensure the widget is still in the tree before calling setState
     if (mounted) {
      setState(() {
        // If there are no offering IDs, the query would fail. Instead, return an empty stream.
        if (offeringIds != null && offeringIds.isNotEmpty) {
          _announcementsStream = FirebaseFirestore.instance
              .collection('announcements')
              .where('courseOfferingId', whereIn: offeringIds)
              .orderBy('date', descending: true)
              .snapshots()
              .asyncMap((snapshot) async {
                // This asyncMap is powerful but can be heavy. It fetches course details for each announcement.
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
          // If offeringIds is null or empty, provide a stream with an empty list.
          _announcementsStream = Stream.value([]);
        }
      });
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Announcements')),
      body: StreamBuilder<List<Announcement>>(
        stream: _announcementsStream,
        builder: (context, snapshot) {
          // Show a loading indicator if the stream hasn't been initialized yet
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

