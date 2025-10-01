import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fl_chart/fl_chart.dart' as fl;
import 'user_service.dart';
import 'package:intl/intl.dart';

// --- SHARED ROLE-BASED LOGIC ---

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserService>(
      builder: (context, userService, child) {
        if (userService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (userService.role == UserRole.schoolAdmin && userService.schoolAdmin != null) {
          return const SchoolAdminDashboard();
        } else if (userService.role == UserRole.lecturer && userService.lecturer != null) {
          return LecturerOverviewDashboard(lecturer: userService.lecturer!);
        } else if (userService.role == UserRole.student && userService.student != null) {
          return StudentAcademicRecordView(student: userService.student!);
        }

        return const Center(child: Text("Please log in to see your overview."));
      },
    );
  }
}

// --- SCHOOL ADMIN DASHBOARD ---

enum FilterLevel { session, faculty, programme, course }

class FilterItem {
  final String id;
  final String name;
  final FilterLevel level;
  FilterItem({required this.id, required this.name, required this.level});
}

class SchoolAdminDashboard extends StatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  State<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> {
  // Chart and filter state
  Map<String, double> _gradeData = {};
  bool _isLoading = false;
  String _chartTitle = "Please select a filter to begin";

  // State for the drill-down filter
  List<FilterItem> _filterBreadcrumbs = [];
  List<FilterItem> _currentOptions = [];
  bool _isFilterLoading = true;
  FilterLevel _currentLevel = FilterLevel.session;

  // Interaction state
  int _touchedIndex = -1;
  List<String> _studentGradeList = [];
  bool _isStudentListLoading = false;
  String _selectedGradeForStudentList = '';

  final Map<String, Color> gradeColorMap = {
    'A': Colors.green.shade400, 'B': Colors.blue.shade400, 'C': Colors.yellow.shade600,
    'D': Colors.orange.shade400, 'E': Colors.red.shade400, 'F': const Color.fromARGB(255, 216, 8, 8),
    'In Progress': Colors.grey.shade500,
  };

  @override
  void initState() {
    super.initState();
    _fetchOptionsForLevel();
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

  Future<void> _fetchOptionsForLevel() async {
    if (!mounted) return;
    setState(() { _isFilterLoading = true; _currentOptions = []; });

    List<FilterItem> items = [];
    final firestore = FirebaseFirestore.instance;

    try {
      switch (_currentLevel) {
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
          final facultyId = _filterBreadcrumbs.firstWhere((b) => b.level == FilterLevel.faculty).id;
          final snapshot = await firestore.collection('programmes').where('facultyId', isEqualTo: facultyId).get();
          items = snapshot.docs.map((doc) => FilterItem(id: doc.id, name: doc['name'], level: FilterLevel.programme)).toList();
          items.insert(0, FilterItem(id: 'all', name: 'All Programmes', level: FilterLevel.programme));
          break;
        case FilterLevel.course:
          final programmeId = _filterBreadcrumbs.firstWhere((b) => b.level == FilterLevel.programme).id;
          final snapshot = await firestore.collection('courses').where('programmeId', isEqualTo: programmeId).get();
          items = snapshot.docs.map((doc) => FilterItem(id: doc.id, name: doc.data()['title'] ?? 'Unknown', level: FilterLevel.course)).toList();
          items.insert(0, FilterItem(id: 'all', name: 'All Courses', level: FilterLevel.course));
          break;
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error fetching filter options.");
    }

    if (mounted) setState(() { _currentOptions = items; _isFilterLoading = false; });
  }
  
  Future<void> _fetchChartData() async {
    if (_filterBreadcrumbs.isEmpty) return;
    setState(() { _isLoading = true; _studentGradeList.clear(); _touchedIndex = -1; });
    
    Query query = _buildQuery();
    String title = _buildTitle();

    Map<String, double> data = {};
    try {
      final snapshot = await query.get();
      for (var doc in snapshot.docs) {
        final docData = doc.data() as Map<String, dynamic>;
        final grade = _getLetterGrade(docData['grade']);
        data[grade] = (data[grade] ?? 0) + 1;
      }
      if (mounted) setState(() { _gradeData = data; _chartTitle = "Grades: $title"; });
    } catch (e) {
      Fluttertoast.showToast(msg: "Error fetching chart data.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudentsForGrade(String grade) async {
    if (grade == 'In Progress') {
      setState(() => _studentGradeList = ['Cannot fetch list for "In Progress".']);
      return;
    }
    setState(() => _isStudentListLoading = true);
    
    final Map<String, int> gradeLowerBounds = {'A': 90, 'B': 80, 'C': 70, 'D': 60, 'E': 50, 'F': 0};
    final Map<String, int> gradeUpperBounds = {'A': 100, 'B': 89, 'C': 79, 'D': 69, 'E': 59, 'F': 49};
    
    Query query = _buildQuery()
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
    } finally {
      if(mounted) setState(() { _studentGradeList = studentNames; _isStudentListLoading = false; });
    }
  }
  
  Query _buildQuery() {
    Query query = FirebaseFirestore.instance.collection('enrollments');
    for (var crumb in _filterBreadcrumbs) {
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

  String _buildTitle() {
    return _filterBreadcrumbs.lastOrNull?.name ?? 'Overview';
  }

  void _onBreadcrumbTapped(int index) {
    setState(() {
      _filterBreadcrumbs.removeRange(index, _filterBreadcrumbs.length);
      _currentLevel = FilterLevel.values[index];
      _touchedIndex = -1;
      _studentGradeList.clear();
      _gradeData.clear();
      _chartTitle = "Select filter(s)";
    });
    if(_filterBreadcrumbs.isNotEmpty) _fetchChartData();
    _fetchOptionsForLevel();
  }

  void _onFilterOptionTapped(FilterItem item) {
    setState(() {
      _filterBreadcrumbs.add(item);
      _touchedIndex = -1;
      _studentGradeList.clear();
      if (item.id != 'all' && _currentLevel != FilterLevel.course) {
        _currentLevel = FilterLevel.values[_currentLevel.index + 1];
        _fetchOptionsForLevel();
      } else {
        _currentOptions = [];
      }
    });
    _fetchChartData();
  }

  List<fl.PieChartSectionData> _getFLChartSections(List<MapEntry<String, double>> sortedEntries) {
    return List.generate(sortedEntries.length, (i) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 22.0 : 14.0;
      final radius = isTouched ? 70.0 : 60.0;
      final entry = sortedEntries[i];
      return fl.PieChartSectionData(
        color: gradeColorMap[entry.key] ?? Colors.blueGrey.shade200, value: entry.value,
        title: '${entry.value.toInt()}', radius: radius,
        titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final userService = Provider.of<UserService>(context, listen: false);
    const gradeOrder = ['A', 'B', 'C', 'D', 'E', 'F', 'In Progress'];
    final sortedGradeEntries = _gradeData.entries.toList()..sort((a, b) => gradeOrder.indexOf(a.key).compareTo(gradeOrder.indexOf(b.key)));
    final totalStudents = _gradeData.values.fold(0.0, (prev, element) => prev + element).toInt();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Text("Welcome, ${userService.schoolAdmin?.name ?? 'Admin'}", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text("Student Grades", style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            
            _DrillDownFilter(
              breadcrumbs: _filterBreadcrumbs,
              options: _currentOptions,
              isLoading: _isFilterLoading,
              onBreadcrumbTapped: _onBreadcrumbTapped,
              onOptionTapped: _onFilterOptionTapped,
              currentLevel: _currentLevel,
            ),
            
            const SizedBox(height: 32),
            Center(child: Text(_chartTitle, style: Theme.of(context).textTheme.titleMedium)),
            const SizedBox(height: 16),
            
            _isLoading
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 64.0), child: Center(child: CircularProgressIndicator()))
                : _gradeData.isEmpty
                    ? Padding(padding: const EdgeInsets.symmetric(vertical: 64.0), child: Center(child: Text(_filterBreadcrumbs.isEmpty ? "" : "No grade data found.")))
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: fl.PieChart(
                                    fl.PieChartData(
                                      pieTouchData: fl.PieTouchData(
                                        touchCallback: (event, pieTouchResponse) {
                                          if (event is fl.FlTapUpEvent && pieTouchResponse?.touchedSection != null) {
                                            setState(() {
                                              final tappedIndex = pieTouchResponse?.touchedSection!.touchedSectionIndex;
                                              if (tappedIndex == _touchedIndex) {
                                                _touchedIndex = -1;
                                                _studentGradeList.clear();
                                              } else {
                                                _touchedIndex = tappedIndex!;
                                                final gradeKey = sortedGradeEntries[_touchedIndex].key;
                                                _selectedGradeForStudentList = gradeKey;
                                                _fetchStudentsForGrade(gradeKey);
                                              }
                                            });
                                          }
                                        },
                                      ),
                                      borderData: fl.FlBorderData(show: false),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 40,
                                      sections: _getFLChartSections(sortedGradeEntries),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 28),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...sortedGradeEntries.map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Indicator(
                                        color: gradeColorMap[entry.key] ?? Colors.grey,
                                        text: "${entry.key} (${entry.value.toInt()})",
                                      ),
                                    );
                                  }).toList(),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Total: $totalStudents",
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          if (_touchedIndex != -1)
                            _isStudentListLoading
                                ? const Center(child: CircularProgressIndicator())
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Students with Grade '$_selectedGradeForStudentList'", style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: 8),
                                      _studentGradeList.isEmpty
                                          ? const Text("No students found.")
                                          : ListView.builder(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: _studentGradeList.length,
                                              itemBuilder: (context, index) {
                                                return Card(
                                                  elevation: 1,
                                                  child: ListTile(
                                                    dense: true,
                                                    leading: CircleAvatar(child: Text(_studentGradeList[index].substring(0,1))),
                                                    title: Text(_studentGradeList[index]),
                                                  ),
                                                );
                                              },
                                            ),
                                    ],
                                  )
                        ],
                      ),
          ],
        ),
      ),
    );
  }
}

// --- NEW WIDGET: Collapsible DrillDownFilter ---
class _DrillDownFilter extends StatefulWidget {
  const _DrillDownFilter({
    required this.breadcrumbs,
    required this.options,
    required this.isLoading,
    required this.onBreadcrumbTapped,
    required this.onOptionTapped,
    required this.currentLevel,
  });

  final List<FilterItem> breadcrumbs;
  final List<FilterItem> options;
  final bool isLoading;
  final void Function(int) onBreadcrumbTapped;
  final void Function(FilterItem) onOptionTapped;
  final FilterLevel currentLevel;

  @override
  State<_DrillDownFilter> createState() => _DrillDownFilterState();
}

class _DrillDownFilterState extends State<_DrillDownFilter> {
  bool _isExpanded = true;

  String get _currentLevelTitle {
    if (widget.breadcrumbs.isEmpty) return "Select a Session";

    if (widget.breadcrumbs.last.id == 'all') {
      if (widget.breadcrumbs.length > 1) {
        return "Showing All for ${widget.breadcrumbs[widget.breadcrumbs.length - 2].name}";
      }
      return "Showing All";
    }

    switch (widget.currentLevel) {
      case FilterLevel.faculty: return "Select a Faculty";
      case FilterLevel.programme: return "Select a Programme";
      case FilterLevel.course: return "Select a Course";
      default: return "Selection Complete";
    }
  }

  bool get _canExpand {
    if (widget.breadcrumbs.isEmpty) return true;
    if (widget.breadcrumbs.last.id == 'all') return false;
    if (widget.breadcrumbs.last.level == FilterLevel.course) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.breadcrumbs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Wrap(
                  spacing: 4.0, runSpacing: 4.0, alignment: WrapAlignment.start,
                  children: [
                    InkWell(onTap: () => widget.onBreadcrumbTapped(0), child: const Icon(Icons.home, size: 20, color: Colors.grey)),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0), child: Icon(Icons.chevron_right, size: 16, color: Colors.grey)),
                    ...List.generate(widget.breadcrumbs.length, (index) {
                      final crumb = widget.breadcrumbs[index];
                      final isLast = index == widget.breadcrumbs.length - 1;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: isLast ? null : () => widget.onBreadcrumbTapped(index + 1),
                            child: Text(
                              crumb.name,
                              style: TextStyle(color: isLast ? Theme.of(context).colorScheme.primary : Colors.grey.shade600, fontWeight: isLast ? FontWeight.bold : FontWeight.normal),
                            ),
                          ),
                          if (!isLast)
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0), child: Icon(Icons.chevron_right, size: 16, color: Colors.grey)),
                        ],
                      );
                    }),
                  ]
                ),
              ),
            
            if (widget.breadcrumbs.isNotEmpty) const Divider(),

            InkWell(
              onTap: _canExpand ? () => setState(() => _isExpanded = !_isExpanded) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_currentLevelTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    if (_canExpand)
                      Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
              
            if (_isExpanded && _canExpand)
              if (widget.isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
              else
                SizedBox(
                  height: 150,
                  child: widget.options.isEmpty 
                    ? const Center(child: Text("No further options available."))
                    : ListView.builder(
                        itemCount: widget.options.length,
                        itemBuilder: (context, index) {
                          final item = widget.options[index];
                          return ListTile(
                            title: Text(item.name),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => widget.onOptionTapped(item),
                          );
                        },
                      ),
                ),
          ],
        ),
      ),
    );
  }
}

// --- Custom Legend Widget for FL Chart ---
class Indicator extends StatelessWidget {
  const Indicator({ super.key, required this.color, required this.text, this.size = 16 });
  final Color color;
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
      ],
    );
  }
}



/************************************** STUDENT ****************************************/
// --- STUDENT ACADEMIC RECORD IMPLEMENTATION ---

class AcademicRecord {
  final String courseTitle;
  final String courseCode;
  final String grade;
  final DateTime enrollmentDate;
  final String lecturerName;
  AcademicRecord({required this.courseTitle, required this.courseCode, required this.grade, required this.enrollmentDate, required this.lecturerName});
}

class StudentAcademicRecordView extends StatefulWidget {
  final Student student;
  const StudentAcademicRecordView({super.key, required this.student});

  @override
  State<StudentAcademicRecordView> createState() => _StudentAcademicRecordViewState();
}

class _StudentAcademicRecordViewState extends State<StudentAcademicRecordView> {
  late Future<List<AcademicRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = _fetchAcademicRecords(widget.student.id);
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

  Future<List<AcademicRecord>> _fetchAcademicRecords(String studentId) async {
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
            //enrollmentDate: (enrollmentData['enrollmentDate'] as Timestamp).toDate(),
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
    return records;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<AcademicRecord>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No academic records found."));

          final records = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: record.grade == 'In Progress' ? Colors.blueGrey : Theme.of(context).colorScheme.primary,
                    child: Text(record.grade.substring(0,1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(record.courseTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(record.courseCode),
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.calendar_today, size: 20),
                      title: const Text('Enrolled'),
                      subtitle: Text(DateFormat.yMMMd().format(record.enrollmentDate)),
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline, size: 20),
                      title: const Text('Lecturer'),
                      subtitle: Text(record.lecturerName),
                    ),
                     ListTile(
                      dense: true,
                      leading: const Icon(Icons.star_border, size: 20),
                      title: const Text('Grade'),
                      subtitle: Text(record.grade),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}


// --- LECTURER ACTION PAGES ---

class ClassRosterPage extends StatefulWidget {
  final String offeringId;
  final String courseTitle;
  const ClassRosterPage({super.key, required this.offeringId, required this.courseTitle});

  @override
  State<ClassRosterPage> createState() => _ClassRosterPageState();
}

class _ClassRosterPageState extends State<ClassRosterPage> {
  late Future<List<Student>> _rosterFuture;

  @override
  void initState() {
    super.initState();
    _rosterFuture = _fetchRoster();
  }

  // <-- IMPROVEMENT: This fetch logic is more efficient than reading one-by-one.
  Future<List<Student>> _fetchRoster() async {
    final firestore = FirebaseFirestore.instance;
    final enrollmentsSnapshot = await firestore
        .collection('enrollments')
        .where('courseOfferingId', isEqualTo: widget.offeringId)
        .get();

    if (enrollmentsSnapshot.docs.isEmpty) {
      return [];
    }

    final studentIds = enrollmentsSnapshot.docs.map((doc) => doc.data()['studentId'] as String).toList();
    List<Student> roster = [];

    // Chunk the studentIds into lists of 30
    for (var i = 0; i < studentIds.length; i += 30) {
      final chunk = studentIds.sublist(i, i + 30 > studentIds.length ? studentIds.length : i + 30);
      
      final studentsSnapshot = await firestore
          .collection('students')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
          
      roster.addAll(studentsSnapshot.docs.map((doc) => Student.fromFirestore(doc)));
    }
    
    // Sort students alphabetically by name
    roster.sort((a, b) => a.name.compareTo(b.name));
    return roster;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Roster for ${widget.courseTitle}')),
      body: FutureBuilder<List<Student>>(
        future: _rosterFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text("Error fetching roster: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No students are enrolled in this course."));
          }
          final students = snapshot.data!;
          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return ListTile(
                leading: CircleAvatar(child: Text(student.name.isNotEmpty ? student.name.substring(0, 1) : 'U')),
                title: Text(student.name),
                subtitle: Text(student.email),
              );
            },
          );
        },
      ),
    );
  }
}

class NewAnnouncementPage extends StatefulWidget {
  final String offeringId;
  final String courseTitle;
  const NewAnnouncementPage({super.key, required this.offeringId, required this.courseTitle});

  @override
  State<NewAnnouncementPage> createState() => _NewAnnouncementPageState();
}

class _NewAnnouncementPageState extends State<NewAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final _announcementController = TextEditingController();
  bool _isPosting = false;

  Future<void> _postAnnouncement() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isPosting = true);
      try {
        await FirebaseFirestore.instance.collection('announcements').add({
          'text': _announcementController.text,
          'courseOfferingId': widget.offeringId,
          'date': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Fluttertoast.showToast(msg: "Announcement posted successfully!");
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Failed to post announcement: $e", backgroundColor: Colors.red);
      } finally {
        if (mounted) {
          setState(() => _isPosting = false);
        }
      }
    }
  }
  
  @override
  void dispose(){
    _announcementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Announcement for ${widget.courseTitle}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _announcementController,
                decoration: const InputDecoration(
                  labelText: 'Announcement Message',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Announcement cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isPosting ? null : _postAnnouncement,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isPosting
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Post Announcement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//*************************************** LECTURER ****************************************/

class LecturerCourseInfo {
  final String offeringId;
  final String courseId;
  final String courseTitle;
  final String session;
  LecturerCourseInfo({required this.offeringId, required this.courseId, required this.courseTitle, required this.session});
}

class AnnouncementInfo {
  final String text;
  final String courseId;
  final DateTime date;
  AnnouncementInfo({required this.text, required this.courseId, required this.date});
}

class LecturerOverviewDashboard extends StatefulWidget {
  final Lecturer lecturer;
  const LecturerOverviewDashboard({super.key, required this.lecturer});

  @override
  State<LecturerOverviewDashboard> createState() => _LecturerOverviewDashboardState();
}

class _LecturerOverviewDashboardState extends State<LecturerOverviewDashboard> {
  late Future<List<LecturerCourseInfo>> _teachingLoadFuture;
  late Future<List<AnnouncementInfo>> _announcementsFuture;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    setState(() {
      _teachingLoadFuture = _fetchTeachingLoad();
      _announcementsFuture = _fetchRecentAnnouncements();
    });
  }

  Future<List<LecturerCourseInfo>> _fetchTeachingLoad() async {
    List<LecturerCourseInfo> teachingLoad = [];
    final offeringsSnapshot = await FirebaseFirestore.instance
        .collection('courseOfferings')
        .where('lecturerId', isEqualTo: widget.lecturer.id)
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
    return teachingLoad;
  }
  
  Future<List<AnnouncementInfo>> _fetchRecentAnnouncements() async {
    List<AnnouncementInfo> announcements = [];
    final offeringsSnapshot = await FirebaseFirestore.instance
        .collection('courseOfferings')
        .where('lecturerId', isEqualTo: widget.lecturer.id)
        .get();

    if (offeringsSnapshot.docs.isEmpty) return [];
    
    final offeringIds = offeringsSnapshot.docs.map((doc) => doc.id).toList();
    if (offeringIds.isEmpty) return [];

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
    return announcements;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _fetchData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //Text("Welcome, ${widget.lecturer.name}", style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              Text("Current Teaching Load (2025-2026)", style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              FutureBuilder<List<LecturerCourseInfo>>(
                future: _teachingLoadFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("You are not assigned to any courses for the current session.");
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) => CourseInfoCard(
                      courseInfo: snapshot.data![index],
                      onDataChanged: _fetchData,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text("Recent Announcements", style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              FutureBuilder<List<AnnouncementInfo>>(
                future: _announcementsFuture,
                builder: (context, snapshot) {
                   if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                   if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("You have not posted any announcements recently.");
                   return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final announcement = snapshot.data![index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          leading: const Icon(Icons.campaign),
                          title: Text(announcement.text),
                          subtitle: Text("${announcement.courseId} - ${DateFormat.yMMMd().add_jm().format(announcement.date)}"),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CourseInfoCard extends StatelessWidget {
  final LecturerCourseInfo courseInfo;
  // <-- IMPROVEMENT: Renamed callback for clarity and consistency.
  final VoidCallback onDataChanged;

  const CourseInfoCard({
    super.key, 
    required this.courseInfo, 
    required this.onDataChanged,
  });

  Future<int> _getStudentCount() async {
    // <-- THE FIX: Changed field name from 'offeringId' to 'courseOfferingId'
    final countQuery = FirebaseFirestore.instance.collection('enrollments').where('courseOfferingId', isEqualTo: courseInfo.offeringId).count();
    final snapshot = await countQuery.get();
    return snapshot.count ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(courseInfo.courseTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(courseInfo.courseId, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                FutureBuilder<int>(
                  future: _getStudentCount(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Text("Loading students...");
                    return Text("${snapshot.data ?? 0} Students Enrolled");
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ClassRosterPage(
                        offeringId: courseInfo.offeringId,
                        courseTitle: courseInfo.courseTitle,
                      ),
                    ));
                  },
                  child: const Text("Roster"),
                ),
                TextButton(
                  onPressed: () async {
                     final result = await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => NewAnnouncementPage(
                        offeringId: courseInfo.offeringId,
                        courseTitle: courseInfo.courseTitle,
                      ),
                    ));
                    if (result == true) {
                      onDataChanged();
                    }
                  },
                  child: const Text("Announce"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
