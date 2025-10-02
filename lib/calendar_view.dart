import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'user_service.dart';

// --- DATA MODELS ---

class CalendarEvent {
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String id;
  final String courseOfferingId;
  final String courseId;
  final bool isRecurring;
  final String? recurrenceType;
  final DateTime? recurrenceEndDate;

  CalendarEvent({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.id,
    required this.courseOfferingId,
    required this.courseId,
    this.isRecurring = false,
    this.recurrenceType,
    this.recurrenceEndDate,
  });

  factory CalendarEvent.fromFirestore(DocumentSnapshot doc, String courseId) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CalendarEvent(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      courseOfferingId: data['courseOfferingId'] ?? '',
      courseId: courseId,
      isRecurring: data['isRecurring'] ?? false,
      recurrenceType: data['recurrenceType'],
      recurrenceEndDate: data['recurrenceEndDate'] != null
          ? (data['recurrenceEndDate'] as Timestamp).toDate()
          : null,
    );
  }
}

class LecturerCourseOffering {
  final String id;
  final String courseTitle;
  LecturerCourseOffering({required this.id, required this.courseTitle});
}

// --- MAIN WIDGET ---

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  Stream<QuerySnapshot> _eventsStream = Stream.empty();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<CalendarEvent>> _events = {};
  List<CalendarEvent> _selectedEvents = [];
  
  late UserService _userService;
  final Map<String, String> _courseIdCache = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userService = Provider.of<UserService>(context);
    _initializeStreamBasedOnRole();
  }
  
  void _initializeStreamBasedOnRole() {
    if (_userService.role == UserRole.student && _userService.student != null) {
      final offeringIds = _userService.student!.currentOfferingIds;
      _setStreamForOfferings(offeringIds);
    } else if (_userService.role == UserRole.lecturer && _userService.lecturer != null) {
      _fetchLecturerOfferingsAndSetStream();
    } else {
      _setStreamForOfferings(null);
    }
  }

  void _setStreamForOfferings(List<String>? offeringIds) {
    if (mounted) {
      setState(() {
        if (offeringIds != null && offeringIds!.isNotEmpty) {
          // Firestore 'whereIn' query is limited to 30 items. Chunk if necessary.
          if (offeringIds!.length > 30) {
            // Handle chunking if you expect more than 30 offerings. For now, we take the first 30.
            // A full solution would involve multiple streams.
            offeringIds = offeringIds!.sublist(0, 30);
          }
          _eventsStream = FirebaseFirestore.instance
              .collection('events')
              .where('courseOfferingId', whereIn: offeringIds)
              .snapshots();
        } else {
          _eventsStream = Stream.empty();
        }
      });
    }
  }

  Future<void> _fetchLecturerOfferingsAndSetStream() async {
    final snapshot = await FirebaseFirestore.instance
      .collection('courseOfferings')
      .where('lecturerId', isEqualTo: _userService.lecturer!.id)
      .where('sessionId', isEqualTo: '2025-2026')
      .get();
      
    final offeringIds = snapshot.docs.map((doc) => doc.id).toList();
    if (mounted) {
      _setStreamForOfferings(offeringIds);
    }
  }

  Future<Map<DateTime, List<CalendarEvent>>> _expandRecurringEvents(List<DocumentSnapshot> docs) async {
    final Map<DateTime, List<CalendarEvent>> newEvents = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
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
          final dayOnly = DateTime(currentDate.year, currentDate.month, currentDate.day);
          final eventInstance = CalendarEvent(
            id: eventRule.id, title: eventRule.title, courseOfferingId: eventRule.courseOfferingId, courseId: eventRule.courseId,
            startTime: DateTime(currentDate.year, currentDate.month, currentDate.day, eventRule.startTime.hour, eventRule.startTime.minute),
            endTime: DateTime(currentDate.year, currentDate.month, currentDate.day, eventRule.endTime.hour, eventRule.endTime.minute),
            isRecurring: true
          );
          if (newEvents[dayOnly] == null) newEvents[dayOnly] = [];
          newEvents[dayOnly]!.add(eventInstance);
          currentDate = currentDate.add(const Duration(days: 7));
        }
      } else {
        final dayOnly = DateTime(eventRule.startTime.year, eventRule.startTime.month, eventRule.startTime.day);
        if (newEvents[dayOnly] == null) newEvents[dayOnly] = [];
        newEvents[dayOnly]!.add(eventRule);
      }
    }
    return newEvents;
  }
  
  List<CalendarEvent> _getEventsForDay(DateTime day) {
    DateTime dayOnly = DateTime(day.year, day.month, day.day);
    return _events[dayOnly] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
      });
    }
  }
  
  Future<void> _showLecturerEventActions(CalendarEvent event) async {
     await showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (event.isRecurring)
                  const ListTile(
                    leading: Icon(Icons.info_outline, color: Colors.blue),
                    title: Text("This is a recurring event. Changes will affect the entire series."),
                  ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Event'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showAddOrEditEventDialog(event: event);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                  title: const Text('Delete Event'),
                  onTap: () {
                     Navigator.of(ctx).pop();
                    _confirmAndDeleteEvent(event);
                  },
                ),
              ],
            ),
          );
        },
      );
  }

  Future<void> _confirmAndDeleteEvent(CalendarEvent event) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "${event.title}"?${event.isRecurring ? '\n\nThis will delete the entire series.' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('events').doc(event.id).delete();
        Fluttertoast.showToast(msg: 'Event deleted successfully!');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to delete event: $e', backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _showAddOrEditEventDialog({CalendarEvent? event}) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: event?.title ?? '');
    TimeOfDay? startTime = event != null ? TimeOfDay.fromDateTime(event.startTime) : null;
    TimeOfDay? endTime = event != null ? TimeOfDay.fromDateTime(event.endTime) : null;
    LecturerCourseOffering? selectedCourse;
    bool isRecurring = event?.isRecurring ?? false;
    DateTime? recurrenceEndDate = event?.recurrenceEndDate;
    final eventDate = event?.startTime ?? _selectedDay ?? DateTime.now();
    final offerings = await _fetchLecturerCourseOfferings();

    if (event != null && offerings.isNotEmpty) {
      selectedCourse = offerings.firstWhere((o) => o.id == event.courseOfferingId, orElse: () => offerings.first);
    }
    
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(event == null ? 'Add Event' : 'Edit Event'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if(offerings.isNotEmpty)
                        DropdownButtonFormField<LecturerCourseOffering>(
                          initialValue: selectedCourse, //value -> initialValue
                          isExpanded: true,
                          items: offerings.map((offering) => DropdownMenuItem(value: offering, child: Text(offering.courseTitle, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (value) => setDialogState(() => selectedCourse = value),
                          decoration: const InputDecoration(labelText: 'Course'),
                           validator: (value) => value == null ? 'Please select a course' : null,
                        ),
                      TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Event Title'), validator: (value) => (value == null || value.isEmpty) ? 'Please enter a title' : null),
                      const SizedBox(height: 16),
                      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.access_time), title: Text(startTime == null ? 'Select Start Time' : startTime!.format(context)), onTap: () async {
                        final time = await showTimePicker(context: context, initialTime: startTime ?? TimeOfDay.now());
                        if (time != null) setDialogState(() => startTime = time);
                      }),
                      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.access_time_filled), title: Text(endTime == null ? 'Select End Time' : endTime!.format(context)), onTap: () async {
                        final time = await showTimePicker(context: context, initialTime: endTime ?? startTime ?? TimeOfDay.now());
                        if (time != null) setDialogState(() => endTime = time);
                      }),
                      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text("Repeat this event"), value: isRecurring, onChanged: (val) => setDialogState(() => isRecurring = val ?? false)),
                      if (isRecurring)
                        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.date_range), title: Text(recurrenceEndDate == null ? 'Select Repeat End Date' : DateFormat.yMMMd().format(recurrenceEndDate!)), onTap: () async {
                          final date = await showDatePicker(context: context, initialDate: recurrenceEndDate ?? eventDate.add(const Duration(days: 30)), firstDate: eventDate, lastDate: DateTime(2030));
                          if (date != null) setDialogState(() => recurrenceEndDate = date);
                        }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => _saveEvent(
                    context: context, formKey: formKey, event: event, title: titleController.text, startTime: startTime, endTime: endTime, eventDate: eventDate,
                    selectedCourse: selectedCourse, isRecurring: isRecurring, recurrenceEndDate: recurrenceEndDate,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<LecturerCourseOffering>> _fetchLecturerCourseOfferings() async {
    if (_userService.lecturer == null) return [];
    List<LecturerCourseOffering> offerings = [];
    final snapshot = await FirebaseFirestore.instance
        .collection('courseOfferings').where('lecturerId', isEqualTo: _userService.lecturer!.id).where('sessionId', isEqualTo: '2025-2026').get();
    for (var doc in snapshot.docs) {
      final courseDoc = await FirebaseFirestore.instance.collection('courses').doc(doc.data()['courseId']).get();
      if (courseDoc.exists) {
        offerings.add(LecturerCourseOffering(id: doc.id, courseTitle: courseDoc.data()?['title'] ?? 'Unknown Course'));
      }
    }
    return offerings;
  }
  
  void _saveEvent({
    required BuildContext context, required GlobalKey<FormState> formKey, required CalendarEvent? event, required String title,
    required TimeOfDay? startTime, required TimeOfDay? endTime, required DateTime eventDate, required LecturerCourseOffering? selectedCourse,
    required bool isRecurring, required DateTime? recurrenceEndDate,
  }) async {
      if (!formKey.currentState!.validate()) return;
      if (startTime == null || endTime == null || selectedCourse == null) {
          Fluttertoast.showToast(msg: 'Please fill all required fields.');
          return;
      }
      if(isRecurring && recurrenceEndDate == null){
         Fluttertoast.showToast(msg: 'Please select an end date for recurring events.');
         return;
      }
      
      final startDateTime = DateTime(eventDate.year, eventDate.month, eventDate.day, startTime.hour, startTime.minute);
      final endDateTime = DateTime(eventDate.year, eventDate.month, eventDate.day, endTime.hour, endTime.minute);

      if (endDateTime.isBefore(startDateTime)) {
          Fluttertoast.showToast(msg: 'End time cannot be before start time.');
          return;
      }

      final eventData = {
          'title': title, 'startTime': Timestamp.fromDate(startDateTime), 'endTime': Timestamp.fromDate(endDateTime), 'courseOfferingId': selectedCourse.id,
          'isRecurring': isRecurring, 'recurrenceType': isRecurring ? 'weekly' : null, 'recurrenceEndDate': isRecurring ? Timestamp.fromDate(recurrenceEndDate!) : null,
      };

      try {
          if (event == null) { await FirebaseFirestore.instance.collection('events').add(eventData); } 
          else { await FirebaseFirestore.instance.collection('events').doc(event.id).update(eventData); }
          
          if (!mounted) return;
          Navigator.of(context).pop();
          Fluttertoast.showToast(msg: 'Event ${event == null ? 'added' : 'updated'} successfully!');
      } catch (e) {
          if (!mounted) return;
          Fluttertoast.showToast(msg: 'Failed to save event: $e', backgroundColor: Colors.red);
      }
  }

  // --- METHODS ADDED BACK ---
  
  Widget _buildCalendar() {
    return Card(
      margin: const EdgeInsets.all(12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar<CalendarEvent>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: _onDaySelected,
          calendarFormat: CalendarFormat.month,
          eventLoader: _getEventsForDay,
          headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false, titleTextStyle: TextStyle(fontSize: 18.0)),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(200), shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
            markerDecoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary, shape: BoxShape.circle),
            todayTextStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
          onPageChanged: (focusedDay) => _focusedDay = focusedDay,
        ),
      ),
    );
  }

  Widget _buildEventListHeader() {
     final headerText = _selectedDay != null ? 'Schedule for ${DateFormat.yMMMd().format(_selectedDay!)}' : 'Select a date';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(headerText, style: Theme.of(context).textTheme.titleLarge),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<UserService>(
        builder: (context, userService, child) {
          if (userService.isLoading) return const Center(child: CircularProgressIndicator());
          if (userService.role == UserRole.unknown) return const Center(child: Text("Please log in to view the calendar."));
          
          return StreamBuilder<QuerySnapshot>(
            stream: _eventsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

              return FutureBuilder<Map<DateTime, List<CalendarEvent>>>(
                future: snapshot.hasData ? _expandRecurringEvents(snapshot.data!.docs) : Future.value({}),
                builder: (context, eventMapSnapshot) {
                  if (eventMapSnapshot.connectionState == ConnectionState.waiting && _events.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  _events = eventMapSnapshot.data ?? _events;
                  
                  if(_selectedDay != null){
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                        if(mounted) setState(() => _selectedEvents = _getEventsForDay(_selectedDay!));
                     });
                   }
                  
                  return Column(
                    children: [
                      _buildCalendar(),
                      const SizedBox(height: 8.0),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Divider()),
                      _buildEventListHeader(),
                      Expanded(child: _buildEventList()),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: _userService.role == UserRole.lecturer ? FloatingActionButton.extended(
        onPressed: () => _showAddOrEditEventDialog(),
        label: const Text('Add Event'),
        icon: const Icon(Icons.add),
      ) : null,
    );
  }

  Widget _buildEventList() {
    if (_selectedEvents.isEmpty) {
      return const Center(child: Text("No classes or events scheduled for this day.", style: TextStyle(fontSize: 16, color: Colors.grey)));
    }
    _selectedEvents.sort((a,b) => a.startTime.compareTo(b.startTime));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _selectedEvents.length,
      itemBuilder: (context, index) {
        final event = _selectedEvents[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary)]),
            title: Text(event.title),
            subtitle: Text('${event.courseId} • ${DateFormat.jm().format(event.startTime)} - ${DateFormat.jm().format(event.endTime)}'),
            onTap: _userService.role == UserRole.lecturer ? () => _showLecturerEventActions(event) : null,
          ),
        );
      },
    );
  }
}
