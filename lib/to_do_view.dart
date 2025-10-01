import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'user_service.dart';
import 'calendar_view.dart'; // Re-uses CalendarEvent model
import 'notification_service.dart'; // <-- MODIFIED: Added import

class ToDoPage extends StatefulWidget {
  const ToDoPage({super.key});

  @override
  State<ToDoPage> createState() => _ToDoPageState();
}

class _ToDoPageState extends State<ToDoPage> {
  Stream<List<CalendarEvent>>? _eventsStream;
  final Map<String, String> _courseIdCache = {};

  // <-- MODIFIED: Added initState to clear the notification badge
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Note: You will need to add a 'clearCalendarCount' method to your NotificationService
      // Provider.of<NotificationService>(context, listen: false).clearCalendarCount();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userService = Provider.of<UserService>(context);
    _initializeStreamBasedOnRole(userService);
  }

  void _initializeStreamBasedOnRole(UserService userService) {
    if (userService.isLoading) return;

    if (userService.role == UserRole.student && userService.student != null) {
      final offeringIds = userService.student!.currentOfferingIds;
      _setEventsStream(offeringIds);
    } else if (userService.role == UserRole.lecturer && userService.lecturer != null) {
      _fetchLecturerOfferingsAndSetStream(userService.lecturer!.id);
    } else {
      _setEventsStream(null);
    }
  }

  Future<void> _fetchLecturerOfferingsAndSetStream(String lecturerId) async {
    final snapshot = await FirebaseFirestore.instance
      .collection('courseOfferings')
      .where('lecturerId', isEqualTo: lecturerId)
      .where('sessionId', isEqualTo: '2025-2026')
      .get();
      
    final offeringIds = snapshot.docs.map((doc) => doc.id).toList();
    
    if (mounted) {
       _setEventsStream(offeringIds);
    }
  }

  void _setEventsStream(List<String>? offeringIds) {
    if (mounted) {
      setState(() {
        if (offeringIds != null && offeringIds.isNotEmpty) {
          _eventsStream = FirebaseFirestore.instance
              .collection('events')
              .where('courseOfferingId', whereIn: offeringIds)
              .snapshots()
              .asyncMap((snapshot) async {
                final now = DateTime.now();
                List<CalendarEvent> allInstances = [];
                
                for (var doc in snapshot.docs) {
                    final data = doc.data();
                    final offeringId = data['courseOfferingId'];

                    if (!_courseIdCache.containsKey(offeringId)) {
                      final offeringDoc = await FirebaseFirestore.instance.collection('courseOfferings').doc(offeringId).get();
                      _courseIdCache[offeringId] = offeringDoc.data()?['courseId'] ?? '???';
                    }
                    final courseId = _courseIdCache[offeringId]!;
                    
                    final eventRule = CalendarEvent.fromFirestore(doc, courseId);

                    if (eventRule.isRecurring && eventRule.recurrenceType == 'weekly' && eventRule.recurrenceEndDate != null) {
                        DateTime currentDate = eventRule.startTime;
                        while (currentDate.isBefore(eventRule.recurrenceEndDate!) || isSameDay(currentDate, eventRule.recurrenceEndDate!)) {
                            if (currentDate.isAfter(now)) {
                                allInstances.add(CalendarEvent(
                                    id: eventRule.id, title: eventRule.title, courseOfferingId: eventRule.courseOfferingId,
                                    courseId: eventRule.courseId,
                                    startTime: currentDate,
                                    endTime: DateTime(currentDate.year, currentDate.month, currentDate.day, eventRule.endTime.hour, eventRule.endTime.minute),
                                    isRecurring: true
                                ));
                            }
                            currentDate = currentDate.add(const Duration(days: 7));
                        }
                    } else {
                        if(eventRule.startTime.isAfter(now)){
                           allInstances.add(eventRule);
                        }
                    }
                }
                
                allInstances.sort((a, b) => a.startTime.compareTo(b.startTime));
                return allInstances.take(10).toList();
              });
        } else {
           _eventsStream = Stream.value([]);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<UserService>(
        builder: (context, userService, child) {
          if (userService.isLoading || _eventsStream == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userService.role == UserRole.unknown) {
             return const Center(
              child: Text('log in to view upcoming events.', style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }
          return StreamBuilder<List<CalendarEvent>>(
            stream: _eventsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error: ${snapshot.error}'),
                ));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text('No upcoming events or deadlines.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                );
              }

              final events = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.event, color: Colors.teal),
                      title: Text(event.title),
                      subtitle: Text('${event.courseId} • ${DateFormat.yMMMd().format(event.startTime)} at ${DateFormat.jm().format(event.startTime)}'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
