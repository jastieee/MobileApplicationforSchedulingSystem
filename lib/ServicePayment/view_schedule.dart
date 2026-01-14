import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../UserDashboard/welcome_page.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';


class WelcomePage1 extends StatelessWidget {
  const WelcomePage1({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome!'),
        backgroundColor: const Color(0xFF3D5184),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF253660),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 100),
            const SizedBox(height: 20),
            const Text(
              'Booking Process Completed!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Your classes have been successfully booked.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                // Example: Navigate back to the very first screen or a dashboard
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => WelcomePage()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D5184),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Go to Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// Existing ViewSchedulePage remains the same

class ViewSchedulePage extends StatefulWidget {
  final String branchName;

  const ViewSchedulePage({required this.branchName, Key? key}) : super(key: key);

  @override
  _ViewSchedulePageState createState() => _ViewSchedulePageState();
}

class _ViewSchedulePageState extends State<ViewSchedulePage> {

  String? selectedBranchName;
  String? selectedBranchCode;
  bool isLoading = true;
  List<Map<String, dynamic>> schedules = [];

  final List<String> daysOfWeek = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

  String? selectedDay;

  int? memberId;


  @override
  void initState() {
    super.initState();
    selectedBranchName = widget.branchName;
    loadBranchInfo();
    loadMemberId();
  }

  Future<void> loadMemberId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    memberId = prefs.getInt('member_id');
  }

  Future<void> loadBranchInfo() async {
    final prefs = await SharedPreferences.getInstance();
    selectedBranchName = prefs.getString('selected_branch_name');
    selectedBranchCode = prefs.getString('branch_code');

    if (selectedBranchName != null && selectedBranchCode != null) {
      await fetchSchedule();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch information not found. Please select a branch again.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> fetchSchedule() async {
    setState(() {
      isLoading = true;
      schedules.clear();
      selectedDay = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/class_schedules.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'branch_code': selectedBranchName}),
      );

      final data = jsonDecode(response.body);
      print('Response body: ${response.body}');

      if (data['success'] == true && data['schedule'] is List) {
        setState(() {
          schedules = List<Map<String, dynamic>>.from(data['schedule']);
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to load schedule')),
        );
        setState(() => isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  String capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  DateTime? parseTimeString(String timeStr, DateTime date) {
    try {
      String startTimeStr = timeStr.split(' to ')[0].trim();
      final timeFormat = DateFormat('h:mm a');
      final parsedTime = timeFormat.parse(startTimeStr);

      return DateTime(
        date.year,
        date.month,
        date.day,
        parsedTime.hour,
        parsedTime.minute,
      );
    } catch (e) {
      print('Error parsing time: $timeStr - $e');
      return null;
    }
  }

  bool isClassTimeAvailableToday(String timeStr) {
    final now = DateTime.now();
    final classTime = parseTimeString(timeStr, now);

    if (classTime == null) return true;

    return now.isBefore(classTime);
  }

  void navigateToDateList(String programTitle, String day, String time) {
    // Find the program to get its price
    final program = schedules.firstWhere((p) => p['title'] == programTitle);
    final double price = program['price']?.toDouble() ?? 0.0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionSelectionPage(
          programTitle: programTitle,
          selectedDay: day,
          time: time,
          price: price, // Add this
        ),
      ),
    );
  }

  List<Widget> buildDaySchedule(String day) {
    List<Widget> items = [];
    final now = DateTime.now();
    final currentDayName = DateFormat('EEEE').format(now).toLowerCase();
    final isToday = day.toLowerCase() == currentDayName;

    for (var program in schedules) {
      final Map<String, dynamic> sched = Map<String, dynamic>.from(program['schedule']);
      final time = sched[day];
      if (time != null && time.toString().trim().isNotEmpty) {
        final bool isTimeAvailable = !isToday || isClassTimeAvailableToday(time);
        final bool isTimePassed = isToday && !isTimeAvailable;

        items.add(
          GestureDetector(
            onTap: isTimeAvailable
                ? () => navigateToDateList(program['title'], day, time)
                : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isTimeAvailable
                    ? const Color(0xFF3D5184)
                    : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(12),
                border: isTimePassed
                    ? Border.all(color: Colors.red.shade300, width: 1)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isTimeAvailable ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program['title'],
                          style: TextStyle(
                            color: isTimeAvailable ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: isTimePassed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: isTimeAvailable ? Colors.white70 : Colors.white38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              time,
                              style: TextStyle(
                                color: isTimeAvailable ? Colors.white70 : Colors.white38,
                                decoration: isTimePassed ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ],
                        ),
                        if (isTimePassed)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Time has passed',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isTimePassed)
                    const Icon(
                      Icons.schedule,
                      color: Colors.red,
                      size: 24,
                    )
                  else if (isTimeAvailable)
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white54,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
        );
      }
    }

    if (items.isEmpty) {
      return [
        Center(
          child: Column(
            children: [
              Icon(
                Icons.event_busy,
                size: 64,
                color: Colors.white38,
              ),
              const SizedBox(height: 16),
              const Text(
                'No classes scheduled for this day',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule - ${selectedBranchName ?? "Branch"}'),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        backgroundColor: const Color(0xFF3D5184),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF253660),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D4373),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.white70,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected Branch',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          selectedBranchName ?? 'Unknown Branch',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            if (schedules.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Day:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedDay,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF2D4373),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: const Icon(
                    Icons.calendar_today,
                    color: Colors.white70,
                  ),
                ),
                hint: const Text(
                  'Select a day',
                  style: TextStyle(color: Colors.white70),
                ),
                dropdownColor: const Color(0xFF2D4373),
                iconEnabledColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                items: daysOfWeek.map((day) {
                  return DropdownMenuItem<String>(
                    value: day,
                    child: Text(
                      capitalize(day),
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedDay = val;
                  });
                },
              ),
              const SizedBox(height: 30),
            ],

            if (selectedDay != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${capitalize(selectedDay!)} Classes',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...buildDaySchedule(selectedDay!),
                    ],
                  ),
                ),
              )
            else if (schedules.isNotEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 64,
                        color: Colors.white38,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Please select a day to view classes',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: Colors.white38,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No schedules available for this branch',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class SessionSelectionPage extends StatefulWidget {
  final String programTitle;
  final String selectedDay;
  final String time;
  final double price;

  const SessionSelectionPage({
    super.key,
    required this.programTitle,
    required this.selectedDay,
    required this.time,
    required this.price,
  });

  @override
  _SessionSelectionPageState createState() => _SessionSelectionPageState();
}

class _SessionSelectionPageState extends State<SessionSelectionPage> {
  String? selectedSessionType;
  int selectedSessionCount = 1;
  // New state variables for instructor selection
  List<Map<String, dynamic>> availableInstructors = [];
  Map<String, dynamic>? selectedInstructor; // To hold {'id': int, 'name': String, 'position': String}
  bool isLoadingInstructors = false;

  final List<String> sessionTypes = ['Full Session', 'Per Session'];
  final List<int> sessionCounts = [1, 2, 3, 4];

  double get totalPrice {
    final int sessions = selectedSessionType == 'Full Session' ? 5 : selectedSessionCount;
    return widget.price * sessions;
  }

  @override
  void initState() {
    super.initState();
    fetchAvailableInstructors();
  }

  Future<void> fetchAvailableInstructors() async {
    setState(() {
      isLoadingInstructors = true;
      availableInstructors.clear();
      selectedInstructor = null; // Reset selected instructor
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final branchCode = prefs.getString('branch_code');

      if (branchCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branch code not found. Cannot fetch instructors.')),
        );
        setState(() => isLoadingInstructors = false);
        return;
      }

      print('Making request with branch_code: $branchCode, selected_day: ${widget.selectedDay}');

      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/facilitator_availability.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'branch_code': branchCode,
          'selected_day': widget.selectedDay.toLowerCase(),
        }),
      );

      print('HTTP Status Code: ${response.statusCode}');
      print('Raw response body: "${response.body}"');

      // Check if HTTP request was successful
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      // Check if response body is empty
      if (response.body.trim().isEmpty) {
        throw Exception('Empty response from server');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body.trim());
      } catch (e) {
        throw Exception('Invalid JSON response: $e\nResponse: ${response.body}');
      }

      print('Parsed response data: $data');

      if (data['success'] == true) {
        if (data['facilitators'] is List) {
          setState(() {
            availableInstructors = List<Map<String, dynamic>>.from(data['facilitators']);
            if (availableInstructors.isNotEmpty) {
              selectedInstructor = availableInstructors.first;
            }
            isLoadingInstructors = false;
          });
          print('Successfully loaded ${availableInstructors.length} instructors');
        } else {
          throw Exception('Invalid facilitators data format');
        }
      } else {
        // Show the actual error message from the server
        String errorMessage = data['message'] ?? 'Unknown server error';
        if (data['debug'] != null) {
          print('Server debug info: ${data['debug']}');
          errorMessage += '\nDebug: ${data['debug']}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in fetchAvailableInstructors: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching instructors: $e'),
          duration: Duration(seconds: 5), // Show error longer
        ),
      );
      setState(() => isLoadingInstructors = false);
    }
  }

  void _showScheduleCountDialog() {
    int selectedCount = 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2D4373),
              title: const Text(
                'Schedule Sessions',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'How many sessions do you want to schedule now?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedCount,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF253660),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    dropdownColor: const Color(0xFF253660),
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    items: List.generate(
                      selectedSessionType == 'Full Session' ? 5 : selectedSessionCount,
                          (index) {
                        final count = index + 1;
                        return DropdownMenuItem<int>(
                          value: count,
                          child: Text(
                            '$count session${count > 1 ? 's' : ''}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedCount = val ?? 1;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScheduleDateListPage(
                          programTitle: widget.programTitle,
                          selectedDay: widget.selectedDay,
                          time: widget.time,
                          sessionType: selectedSessionType!,
                          sessionCount: selectedSessionType == 'Full Session' ? 5 : selectedSessionCount,
                          totalPrice: totalPrice,
                          schedulingCount: selectedCount,
                          // Pass instructor details
                          instructorId: selectedInstructor?['facilitator_id'] ?? 0,
                          instructorName: selectedInstructor?['facilitator_name'] ?? 'N/A',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Sessions'),
        backgroundColor: const Color(0xFF3D5184),
      ),
      backgroundColor: const Color(0xFF253660),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wrap the main content section in Expanded and SingleChildScrollView
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Class Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D4373),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.programTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.selectedDay.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.time,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Session Type Selection
                    const Text(
                      'Session Type:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: selectedSessionType,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF2D4373),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.event_note,
                          color: Colors.white70,
                        ),
                      ),
                      hint: const Text(
                        'Select session type',
                        style: TextStyle(color: Colors.white70),
                      ),
                      dropdownColor: const Color(0xFF2D4373),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      items: sessionTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            type,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedSessionType = val;
                          if (val == 'Full Session') {
                            selectedSessionCount = 5; // Default to 5 for full session
                          } else {
                            selectedSessionCount = 1; // Reset to 1 for per session
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    // Instructor Selection
                    if (selectedSessionType != null) ...[ // Only show if session type is selected
                      const Text(
                        'Select Instructor:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      isLoadingInstructors
                          ? const Center(child: CircularProgressIndicator())
                          : availableInstructors.isEmpty
                          ? const Text(
                        'No instructors available for this class on this day.',
                        style: TextStyle(color: Colors.white70),
                      )
                          : DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedInstructor,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF2D4373),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.person,
                            color: Colors.white70,
                          ),
                        ),
                        hint: const Text(
                          'Select an instructor',
                          style: TextStyle(color: Colors.white70),
                        ),
                        dropdownColor: const Color(0xFF2D4373),
                        iconEnabledColor: Colors.white,
                        style: const TextStyle(color: Colors.white),
                        items: availableInstructors.map((instructor) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: instructor,
                            child: Text(
                              '${instructor['facilitator_name']} (${instructor['facilitator_position']})',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedInstructor = val;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                    ],


                    // Session Count Selection
                    if (selectedSessionType != null) ...[
                      const Text(
                        'Number of Sessions:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (selectedSessionType == 'Full Session')
                      // Display textbox with value 5 for full session
                        TextFormField(
                          readOnly: true,
                          initialValue: '5',
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF2D4373),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            prefixIcon: const Icon(
                              Icons.format_list_numbered,
                              color: Colors.white70,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        )
                      else
                      // Display dropdown for per session (1-4)
                        DropdownButtonFormField<int>(
                          value: selectedSessionCount,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF2D4373),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            prefixIcon: const Icon(
                              Icons.format_list_numbered,
                              color: Colors.white70,
                            ),
                          ),
                          dropdownColor: const Color(0xFF2D4373),
                          iconEnabledColor: Colors.white,
                          style: const TextStyle(color: Colors.white),
                          items: sessionCounts.map((count) {
                            return DropdownMenuItem<int>(
                              value: count,
                              child: Text(
                                '$count session${count > 1 ? 's' : ''}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedSessionCount = val ?? 1;
                            });
                          },
                        ),
                    ],
                    // Add this section before the Spacer()
                    if (selectedSessionType != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D4373),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Price Summary',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Price per session:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  '₱${widget.price.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sessions: ${selectedSessionType == 'Full Session' ? 5 : selectedSessionCount}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  '₱${totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Add a wide gap at the end of the scrollable content
                    const SizedBox(height: 80), // This adds the desired wide gap
                  ],
                ),
              ),
            ),

            // Continue Button (remains at the bottom)
            if (selectedSessionType != null && selectedInstructor != null) // Only enable if both are selected
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final totalSessions = selectedSessionType == 'Full Session' ? 5 : selectedSessionCount;
                    if (totalSessions == 1) {
                      // Direct navigation for single session
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScheduleDateListPage(
                            programTitle: widget.programTitle,
                            selectedDay: widget.selectedDay,
                            time: widget.time,
                            sessionType: selectedSessionType!,
                            sessionCount: totalSessions,
                            totalPrice: totalPrice,
                            schedulingCount: 1,
                            // Pass instructor details
                            instructorId: selectedInstructor!['facilitator_id'],
                            instructorName: selectedInstructor!['facilitator_name'],
                          ),
                        ),
                      );
                    } else {
                      // Show popup for multiple sessions
                      _showScheduleCountDialog();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5184),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Optionally, show a message if instructor is not selected
            if (selectedSessionType != null && selectedInstructor == null && !isLoadingInstructors && availableInstructors.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Text(
                  'Please select an instructor to continue.',
                  style: TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            if (selectedSessionType != null && availableInstructors.isEmpty && !isLoadingInstructors)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Text(
                  'No instructors available for this class and day. Please choose another class or day.',
                  style: TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ScheduleDateListPage extends StatefulWidget {
  final String programTitle;
  final String selectedDay;
  final String time;
  final String sessionType;
  final int sessionCount;
  final double totalPrice;
  final int schedulingCount;
  final int instructorId; // New parameter
  final String instructorName; // New parameter

  const ScheduleDateListPage({
    super.key,
    required this.programTitle,
    required this.selectedDay,
    required this.time,
    required this.sessionType,
    required this.sessionCount,
    required this.totalPrice,
    required this.schedulingCount,
    required this.instructorId, // Initialize
    required this.instructorName, // Initialize
  });

  @override
  _ScheduleDateListPageState createState() => _ScheduleDateListPageState();
}

class _ScheduleDateListPageState extends State<ScheduleDateListPage> {
  Map<String, dynamic>? memberData;
  bool isLoadingMember = false;
  List<DateTime> selectedDates = []; // New property
  int get remainingSelections => widget.schedulingCount - selectedDates.length; // New getter


  @override
  void initState() {
    super.initState();
    fetchMemberData();
  }

  Future<void> fetchMemberData() async {
    setState(() {
      isLoadingMember = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final memberId = prefs.getInt('member_id');
      final savedUsername = prefs.getString('username'); // <--- Add this line to get the saved username

      if (memberId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member ID not found. Please log in again.')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/member_controller.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'member_id': memberId}),
      );

      final data = jsonDecode(response.body);
      print('Member data response: ${response.body}');

      if (data['success'] == true && data['member'] != null) {
        setState(() {
          // Ensure the fetched memberData includes the username.
          // If your PHP script (member_controller.php) returns a 'username' field, use that.
          // Otherwise, explicitly add the username from SharedPreferences to your memberData map.
          memberData = data['member'];
          if (savedUsername != null) {
            memberData!['username'] = savedUsername; // <--- Ensure username is in memberData
          }
          isLoadingMember = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to load member data')),
        );
        setState(() => isLoadingMember = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => isLoadingMember = false);
    }
  }

  List<DateTime> getDatesForDay(String dayName) {
    final List<DateTime> dates = [];
    final now = DateTime.now();
    final int currentYear = now.year;

    final DateTime startDate = now;
    final DateTime endDate = DateTime(currentYear, 12, 31);

    int weekdayTarget = [
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
    ].indexOf(dayName.toLowerCase()) + 1;

    for (DateTime date = startDate; date.isBefore(endDate.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      if (date.weekday == weekdayTarget) {
        if (date.isAfter(now.subtract(const Duration(days: 1)))) {
          dates.add(date);
        }
      }
    }
    return dates;
  }

  bool isClassTimeAvailable(String timeStr, DateTime date) {
    try {
      final now = DateTime.now();

      if (date.day != now.day || date.month != now.month || date.year != now.year) {
        return true;
      }

      String startTimeStr = timeStr.split(' to ')[0].trim();
      final timeFormat = DateFormat('h:mm a');
      final parsedTime = timeFormat.parse(startTimeStr);

      final classDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      return now.isBefore(classDateTime);
    } catch (e) {
      print('Error parsing time: $timeStr - $e');
      return true;
    }
  }

  // --- START NEW PAYMENT FLOW INTEGRATION ---
  Future<void> _initiatePayMongoPayment(List<DateTime> datesToSchedule) async {
    if (memberData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member data not loaded. Cannot initiate payment.')),
      );
      return;
    }

    // Combine all service details into a single string for metadata
    String serviceDetails = datesToSchedule.map((date) =>
    '${widget.programTitle} on ${DateFormat('MMMM d, y (EEEE)').format(date)} at ${widget.time} with ${widget.instructorName}'
    ).join('; ');

    // Extract member information
    final String fullName = '${memberData!['firstname'] ?? ''} ${memberData!['mi'] ?? ''} ${memberData!['lastname'] ?? ''} ${memberData!['suffix'] ?? ''}'.trim();
    final String userName = memberData!['username'] ?? memberData!['membership_code'] ?? 'unknown_user';

    // Show loading dialog *before* initiating PayMongo request
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/create_payment_flutter.php'), // Your PHP endpoint
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded', // Corrected header for $_POST
        },
        body: {
          'amount': widget.totalPrice.toString(), // Ensure amount is string
          'name': fullName,
          'user_name': userName,
          'service_details': serviceDetails,
        }.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&'),
      );

      // Dismiss the initial loading indicator after getting PHP response
      Navigator.of(context).pop();

      final responseData = jsonDecode(response.body);

      if (responseData['success'] == true && responseData['checkout_url'] != null) {
        final String checkoutUrl = responseData['checkout_url'];
        final String referenceId = responseData['reference_id']; // This is the original reference ID

        // IMPORTANT: AWAIT THE RESULT FROM THE WEBVIEW PAGE
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PayMongoWebViewPage(
              checkoutUrl: checkoutUrl,
              referenceId: referenceId, // Pass the original referenceId
              programTitle: widget.programTitle,
              selectedDates: datesToSchedule,
              time: widget.time,
              memberData: memberData!,
              instructorId: widget.instructorId, // Pass instructorId
              instructorName: widget.instructorName, // Pass instructorName
            ),
          ),
        );

        // Now, after the WebView has been popped, check its result
        if (result != null && result is Map<String, dynamic>) {
          final bool paymentSuccess = result['success'];
          final String? finalReferenceId = result['referenceId'];
          final String? errorMessage = result['error']; // Capture any error message from WebView

          if (paymentSuccess) {
            // Show a "Processing" or "Waiting" dialog while class registration happens
            _showPaymentWaitingDialog(); // Implement this new function

            try {
              await _processPaymentAndRegisterSessions(datesToSchedule, finalReferenceId); // Pass the finalReferenceId
              // Dismiss waiting dialog if registration is successful
              Navigator.of(context).pop(); // Dismiss _showPaymentWaitingDialog

              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF2D4373),
                  title: const Text('Payment Successful!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: Text('Your payment for ${widget.programTitle} was successful. Reference ID: ${finalReferenceId ?? 'N/A'}. Classes have been registered.', style: const TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const WelcomePage1()),
                              (Route<dynamic> route) => false,
                        );
                      },
                      child: const Text('Go to Home', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            } catch (e) {
              // Dismiss waiting dialog if registration fails
              Navigator.of(context).pop(); // Dismiss _showPaymentWaitingDialog

              // If class registration fails AFTER payment success
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF2D4373),
                  title: const Text('Registration Failed!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  content: Text('Payment was successful (Ref ID: ${finalReferenceId ?? 'N/A'}), but there was an error registering your classes. Please contact support. Error: $e', style: const TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const WelcomePage1()),
                              (Route<dynamic> route) => false,
                        );
                      },
                      child: const Text('Go to Home', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            }
          } else {
            // Payment failed or cancelled
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF2D4373),
                title: const Text('Payment Failed or Cancelled', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                content: Text('There was an issue with your payment for ${widget.programTitle}. Please try again. Reference ID: ${finalReferenceId ?? 'N/A'}. ${errorMessage != null ? 'Error: $errorMessage' : ''}', style: const TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                    },
                    child: const Text('Retry Payment', style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Go back to previous screen (ScheduleDateListPage)
                    },
                    child: const Text('Go Back', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            );
          }
        } else {
          // This case handles if `Navigator.pop` returns null (e.g., if user used back button without explicit pop with result)
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF2D4373),
              title: const Text('Payment Process Interrupted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              // Use the `referenceId` local variable here, not `widget.referenceId`
              content: Text('The payment process was interrupted. Please check your PayMongo dashboard or retry. Reference ID: $referenceId', style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(); // Go back to previous screen (ScheduleDateListPage)
                  },
                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      } else {
        // Error getting checkout URL from your PHP script
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Failed to get PayMongo checkout URL')),
        );
      }
    } catch (e) {
      // Catch any network or other unexpected errors during the initial http.post or webview push
      if (mounted) { // Check if the widget is still in the tree
        Navigator.of(context).pop(); // Dismiss loading indicator if it's still open
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initiating payment: $e')),
      );
    }
  }

  void _showPaymentWaitingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User cannot dismiss by tapping outside
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D4373),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Payment successful, registering classes...',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            Text(
              'Please do not close this app.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  // Add validation before sending data
  Future<void> _processPaymentAndRegisterSessions(List<DateTime> datesToSchedule, String? finalReferenceId) async { // Added finalReferenceId parameter
    final prefs = await SharedPreferences.getInstance();
    final branchName = prefs.getString('selected_branch_name') ?? 'default';
    final tableName = '${branchName.replaceAll(' ', '_')}_logs';

    // These variables are used for both the summary and individual log entries
    final double paymentAmount = widget.totalPrice; // Amount paid for this transaction
    final int totalSessionsPurchased = widget.sessionCount; // Total sessions customer bought (e.g., 5-session package)
    final int scheduledSessionsCount = datesToSchedule.length; // How many sessions are being scheduled *now*

    try {
      // --- 1. FIRST API CALL: Insert into members_services table (SUMMARY ROW) ---
      // This call sends data for the overall purchase/transaction, not individual dates.
      final Map<String, dynamic> serviceSummaryData = {
        'nfc_uid': _sanitizeString(memberData?['nfc_uid'] ?? ''),
        'firstname': _sanitizeString(memberData?['firstname'] ?? ''),
        'mi': _sanitizeString(memberData?['mi'] ?? ''),
        'lastname': _sanitizeString(memberData?['lastname'] ?? ''),
        'suffix': _sanitizeString(memberData?['suffix'] ?? ''),
        'branch_code': _sanitizeString(prefs.getString('branch_code') ?? ''),
        'membership_code': _sanitizeString(memberData?['membership_code'] ?? ''),
        'membership_type': _sanitizeString(memberData?['membership_type'] ?? ''),
        'program': 'class', // Or whatever represents the overall program type (e.g., "Boxing", "Yoga")
        'services': _sanitizeString(widget.programTitle), // e.g., "Boxing", "Yoga"
        'price': widget.totalPrice, // Total price of the service/sessions
        'payment': paymentAmount, // Actual amount paid (should be from PayMongo callback)
        'sessions': totalSessionsPurchased, // Total sessions purchased (e.g., 5-session package)
        'track_sessions': scheduledSessionsCount, // Number of sessions being scheduled *now* from the total purchased
      };

      print('Sending summary data to record_member_service.php: ${jsonEncode(serviceSummaryData)}');

      final serviceResponse = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/record_member_service.php'), // Call your NEW PHP script for summary
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(serviceSummaryData),
      );

      print('Response status from record_member_service.php: ${serviceResponse.statusCode}');
      print('Response body from record_member_service.php: ${serviceResponse.body}');

      final serviceResult = jsonDecode(serviceResponse.body);
      if (serviceResponse.statusCode != 200 || serviceResult['success'] != true) {
        // If recording the summary fails, throw an error and don't proceed with scheduling individual dates
        throw Exception('Failed to record member service summary: ${serviceResult['message'] ?? 'Unknown error'}');
      }

      // --- NEW API CALL: Insert into servicesTrn_logs table (Transaction details) ---
      final Map<String, dynamic> serviceTrnData = {
        'nfc_uid': _sanitizeString(memberData?['nfc_uid'] ?? ''),
        'firstname': _sanitizeString(memberData?['firstname'] ?? ''),
        'mi': _sanitizeString(memberData?['mi'] ?? ''),
        'lastname': _sanitizeString(memberData?['lastname'] ?? ''),
        'suffix': _sanitizeString(memberData?['suffix'] ?? ''),
        'branch_code': _sanitizeString(prefs.getString('branch_code') ?? ''),
        'membership_code': _sanitizeString(memberData?['membership_code'] ?? ''),
        'membership_type': _sanitizeString(memberData?['membership_type'] ?? ''),
        'program': 'class',
        'services': _sanitizeString(widget.programTitle),
        'price': widget.totalPrice,
        'payment': paymentAmount,
        'sessions': totalSessionsPurchased,
        'payment_method': 'PayMongo', // Explicitly PayMongo as per previous setup
        'recorded_by': 'Online Registration', // As requested
        'reference_id': finalReferenceId ?? 'N/A', // Pass the reference ID
      };

      print('Sending transaction data to record_service_transaction.php: ${jsonEncode(serviceTrnData)}');
      final trnResponse = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/record_service_transaction.php'), // NEW PHP script
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(serviceTrnData),
      );

      print('Response status from record_service_transaction.php: ${trnResponse.statusCode}');
      print('Response body from record_service_transaction.php: ${trnResponse.body}');

      final trnResult = jsonDecode(trnResponse.body);
      if (trnResponse.statusCode != 200 || trnResult['success'] != true) {
        throw Exception('Failed to record service transaction: ${trnResult['message'] ?? 'Unknown error'}');
      }


      // --- 2. SECOND API CALLS (Loop): Insert into branch-specific log table (INDIVIDUAL ENTRIES) ---
      // This loop runs ONLY if the summary insertion AND transaction insertion were successful.
      for (DateTime date in datesToSchedule) {
        final scheduledTime = '${DateFormat('EEEE, MMM dd, y').format(date)} at ${widget.time}';

        // Data for the branch-specific log table (individual appointment details)
        final Map<String, dynamic> logData = {
          'table': _sanitizeString(tableName),
          'nfc_uid': _sanitizeString(memberData?['nfc_uid'] ?? ''),
          'firstname': _sanitizeString(memberData?['firstname'] ?? ''),
          'mi': _sanitizeString(memberData?['mi'] ?? ''),
          'lastname': _sanitizeString(memberData?['lastname'] ?? ''),
          'suffix': _sanitizeString(memberData?['suffix'] ?? ''),
          'membership_code': _sanitizeString(memberData?['membership_code'] ?? ''),
          'membership_type': _sanitizeString(memberData?['membership_type'] ?? ''),
          'services': _sanitizeString(widget.programTitle), // Service/program associated with this session
          'scheduled_time': _sanitizeString(scheduledTime), // The specific date and time for this log entry
          'program': 'class', // Type of program/session
          'branch_code': _sanitizeString(prefs.getString('branch_code') ?? ''),
          // 'instructor_id': widget.instructorId, // Add instructor ID
          'instructor_name': widget.instructorName, // Add instructor name
        };

        print('Sending log data to scheduled_appointment.php for date: $scheduledTime');
        final logResponse = await http.post(
          Uri.parse('https://membership.ndasphilsinc.com/scheduled_appointment.php'), // Call your EXISTING PHP script for log entries
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(logData),
        );

        print('Response status from scheduled_appointment.php: ${logResponse.statusCode}');
        print('Response body from scheduled_appointment.php: ${logResponse.body}');

        final logResult = jsonDecode(logResponse.body);
        if (logResponse.statusCode != 200 || logResult['success'] != true) {
          throw Exception('Failed to register date ${DateFormat('MMM dd, y').format(date)}: ${logResult['message'] ?? 'Unknown error'}');
        }
      }

      // If both the summary insertion AND all individual log entries were successful:
      // You can now proceed to navigate to a success page or show a success message.
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const WelcomePage1(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessions registered successfully!')),
      );

    } catch (e) {
      print('Overall registration error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error registering sessions: ${e.toString()}')),
      );
      // You might want to rethrow the exception if there's a higher-level handler,
      // or handle it completely here by showing an error dialog/message.
      // rethrow; // Uncomment if you want to propagate the error further
    }
  }

  // Helper function to sanitize strings
  String _sanitizeString(String? input) {
    if (input == null) return '';
    // Remove or replace problematic characters
    return input
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '') // Remove non-printable ASCII
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '') // Remove non-printable ASCII
        .trim();
  }

  // --- END NEW PAYMENT FLOW INTEGRATION ---

  void showSummaryDialog(List<DateTime> selectedDatesList) {
    final DateFormat dayFormatter = DateFormat('EEEE');
    final DateFormat dateFormatter = DateFormat('MMMM d, y');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D4373),
          title: const Text(
            'Class Registration Summary',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: isLoadingMember
              ? const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading member information...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          )
              : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Member Information (same as before)
                const Text(
                  'Member Information:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (memberData != null) ...[
                  _buildInfoRow('Name:', '${memberData!['firstname'] ?? ''} ${memberData!['mi'] ?? ''} ${memberData!['lastname'] ?? ''} ${memberData!['suffix'] ?? ''}'),
                  _buildInfoRow('Membership Code:', memberData!['membership_code'] ?? 'N/A'),
                  _buildInfoRow('Membership Type:', memberData!['membership_type'] ?? 'N/A'),
                ] else
                  const Text(
                    'Member information not available',
                    style: TextStyle(color: Colors.red),
                  ),

                const Divider(color: Colors.white30),

                // Class Information
                const Text(
                  'Class Details:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Service:', widget.programTitle),
                _buildInfoRow('Instructor:', widget.instructorName), // Display instructor name

                // Multiple dates section
                const Text(
                  'Scheduled Dates & Times:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                ...selectedDatesList.map((date) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• ${dateFormatter.format(date)} (${dayFormatter.format(date)}) at ${widget.time}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                )).toList(),

                const Divider(color: Colors.white30),

                // Payment Information (same as before)
                const Text(
                  'Payment Details:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Session Type:', widget.sessionType),
                _buildInfoRow('Number of Sessions:', '${widget.sessionCount}'),
                _buildInfoRow('Sessions to Schedule:', '${selectedDatesList.length}'),
                _buildInfoRow('Total Amount:', '₱${widget.totalPrice.toStringAsFixed(2)}'),

                const Divider(color: Colors.white30),

                // Branch Information (same as before)
                const Text(
                  'Branch Information:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<SharedPreferences>(
                  future: SharedPreferences.getInstance(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildInfoRow('Branch:', 'Loading...');
                    } else if (snapshot.hasError || !snapshot.hasData) {
                      return _buildInfoRow('Branch:', 'Error loading');
                    }

                    final prefs = snapshot.data!;
                    final branchName = prefs.getString('selected_branch_name') ?? 'N/A';
                    final branchCode = prefs.getString('branch_code') ?? 'N/A';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Branch:', branchName),
                        _buildInfoRow('Branch Code:', branchCode),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Dismiss summary dialog
                _initiatePayMongoPayment(selectedDatesList); // Initiate payment
              },
              child: const Text(
                'Proceed to Payment',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim(),
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _getBranchName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_branch_name');
  }

  @override
  Widget build(BuildContext context) {
    final List<DateTime> dates = getDatesForDay(widget.selectedDay);
    final DateFormat formatter = DateFormat('MMMM d, y (EEEE)');

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.programTitle} - ${widget.selectedDay.toUpperCase()}'),
        backgroundColor: const Color(0xFF3D5184),
      ),
      backgroundColor: const Color(0xFF253660),
      body: Column(
        children: [
          // Add selection counter at the top
          if (widget.schedulingCount > 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D4373),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Select ${widget.schedulingCount} dates (${selectedDates.length}/${widget.schedulingCount} selected)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          Expanded(
            child: dates.isEmpty
                ? const Center(
              child: Text(
                'No upcoming classes available for this day.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                final now = DateTime.now();
                final isToday = date.day == now.day &&
                    date.month == now.month &&
                    date.year == now.year;
                final isTimeAvailable = isToday ? isClassTimeAvailable(widget.time, date) : true;
                final isTimePassed = isToday && !isTimeAvailable;
                final isSelected = selectedDates.any((d) =>
                d.day == date.day && d.month == date.month && d.year == date.year);

                return Card(
                  color: isSelected
                      ? const Color(0xFF4CAF50)
                      : (isTimeAvailable ? const Color(0xFF3D5184) : Colors.grey.shade700),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: widget.schedulingCount > 1
                        ? Checkbox(
                      value: isSelected,
                      onChanged: isTimeAvailable
                          ? (bool? value) {
                        setState(() {
                          if (value == true) {
                            if (selectedDates.length < widget.schedulingCount) {
                              selectedDates.add(date);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('You can only select ${widget.schedulingCount} dates'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          } else {
                            selectedDates.removeWhere((d) =>
                            d.day == date.day && d.month == date.month && d.year == date.year);
                          }
                        });
                      }
                          : null,
                      activeColor: Colors.white,
                      checkColor: const Color(0xFF4CAF50),
                    )
                        : null,
                    title: Text(
                      formatter.format(date),
                      style: TextStyle(
                        color: isTimeAvailable ? Colors.white : Colors.white54,
                        decoration: isTimePassed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time: ${widget.time}',
                          style: TextStyle(
                            color: isTimeAvailable ? Colors.white70 : Colors.white38,
                            decoration: isTimePassed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        Text(
                          'Instructor: ${widget.instructorName}', // Display instructor name here
                          style: TextStyle(
                            color: isTimeAvailable ? Colors.white70 : Colors.white38,
                            decoration: isTimePassed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (isTimePassed)
                          const Text(
                            'Registration closed - Time has passed',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (isSelected)
                          const Text(
                            'Selected',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    trailing: isTimePassed
                        ? const Icon(Icons.schedule, color: Colors.red, size: 20)
                        : (isSelected
                        ? const Icon(Icons.check_circle, color: Colors.white, size: 20)
                        : const Icon(Icons.info_outline, color: Colors.white54, size: 20)),
                    onTap: widget.schedulingCount == 1
                        ? (isTimeAvailable ? () => showSummaryDialog([date]) : null)
                        : (isTimeAvailable
                        ? () {
                      setState(() {
                        if (isSelected) {
                          selectedDates.removeWhere((d) =>
                          d.day == date.day && d.month == date.month && d.year == date.year);
                        } else {
                          if (selectedDates.length < widget.schedulingCount) {
                            selectedDates.add(date);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('You can only select ${widget.schedulingCount} dates'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      });
                    }
                        : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Registration is closed. The class time has already passed.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),

          // Add confirm button for multiple selections
          if (widget.schedulingCount > 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: selectedDates.length == widget.schedulingCount
                    ? () => showSummaryDialog(selectedDates)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedDates.length == widget.schedulingCount
                      ? const Color(0xFF3D5184)
                      : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  selectedDates.length == widget.schedulingCount
                      ? 'Continue with Selected Dates'
                      : 'Select ${remainingSelections} more date${remainingSelections > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// NEW WIDGET FOR PAYMONGO WEBVIEW
class PayMongoWebViewPage extends StatefulWidget {
  final String checkoutUrl;
  final String referenceId;
  final String programTitle;
  final List<DateTime> selectedDates;
  final String time;
  final Map<String, dynamic> memberData;
  final int instructorId; // Add this
  final String instructorName; // Add this

  const PayMongoWebViewPage({
    Key? key,
    required this.checkoutUrl,
    required this.referenceId,
    required this.programTitle,
    required this.selectedDates,
    required this.time,
    required this.memberData,
    required this.instructorId, // Initialize
    required this.instructorName, // Initialize
  }) : super(key: key);

  @override
  State<PayMongoWebViewPage> createState() => _PayMongoWebViewPageState();
}

class _PayMongoWebViewPageState extends State<PayMongoWebViewPage> {
  late final WebViewController _controller;
  bool _isLoadingPage = true;
  String? _finalReferenceId;

  @override
  void initState() {
    super.initState();
    _finalReferenceId = widget.referenceId;

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
    WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100) {
              setState(() {
                _isLoadingPage = false;
              });
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoadingPage = true;
            });
            print('Page started loading: $url');
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoadingPage = false;
            });
            print('Page finished loading: $url');

            // Check for various success/failure indicators from the original URLs
            if (_isPaymentSuccessUrl(url)) {
              print('Payment success detected!');
              Navigator.pop(context, {'success': true, 'referenceId': _extractRefIdFromSuccessUrl(url)});
            } else if (_isPaymentFailedUrl(url)) {
              print('Payment failed/cancelled detected!');
              Navigator.pop(context, {'success': false, 'referenceId': widget.referenceId});
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
              Page resource error:
                code: ${error.errorCode}
                description: ${error.description}
                errorType: ${error.errorType}
                isForMainFrame: ${error.isForMainFrame}
            ''');
            // If there's a resource error, consider it a failure unless explicitly handled
            if (!_isPaymentSuccessUrl(error.url ?? '') && !_isPaymentFailedUrl(error.url ?? '')) {
              Navigator.pop(context, {'success': false, 'referenceId': widget.referenceId, 'error': error.description});
            }
          },
          onUrlChange: (UrlChange change) {
            debugPrint('url change to ${change.url}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setTextZoom(100);
    }

    _controller = controller;
  }

  // Helper function to determine if the URL indicates payment success
  bool _isPaymentSuccessUrl(String url) {
    // Check if the URL matches your success receipt page and has a reference ID
    return url.contains('membership.ndasphilsinc.com/receipt.php') && url.contains('ref_id=');
  }

  // Helper function to extract ref_id from the success URL
  String? _extractRefIdFromSuccessUrl(String url) {
    final uri = Uri.parse(url);
    return uri.queryParameters['ref_id'] ?? widget.referenceId;
  }

  // Helper function to determine if the URL indicates payment failure/cancellation
  bool _isPaymentFailedUrl(String url) {
    // Check if the URL matches your cancelled/members list page
    return url.contains('membership.ndasphilsinc.com/members_list.php');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: const Color(0xFF3D5184),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              // User manually closed the webview, treat as cancelled
              Navigator.pop(context, {'success': false, 'referenceId': widget.referenceId});
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoadingPage)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
