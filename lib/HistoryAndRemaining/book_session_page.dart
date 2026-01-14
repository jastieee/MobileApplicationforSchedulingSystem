import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:slimmersworld/ServicePayment/select_date_page.dart'; // Import the new date selection page
import '../UserDashboard/welcome_page.dart';

// A placeholder for your Welcome Page from viewbody_schedule.dart
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
              'Your sessions have been successfully booked.',
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
                // This assumes a 'WelcomePage' exists in your project.
                // Replace with your actual home/dashboard navigation.
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => WelcomePage()), // Navigating back to this same placeholder
                      (Route<dynamic> route) => false,
                );
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


class BookSessionPage extends StatefulWidget {
  final String serviceName;
  final String branchName;

  const BookSessionPage({
    Key? key,
    required this.serviceName,
    required this.branchName,
  }) : super(key: key);

  @override
  _BookSessionPageState createState() => _BookSessionPageState();
}

class _BookSessionPageState extends State<BookSessionPage> {
  bool isLoading = true;
  String? errorMessage;
  String? _programType; // To store the program type received from PHP

  // For 'class' program type
  List<Map<String, String>> availableClassSlots = [];
  Map<String, String>? selectedClassSlot;
  List<Map<String, String>> _availableInstructors = []; // New: Stores instructors for class type
  Map<String, String>? _selectedInstructor; // New: Stores selected instructor for class type
  bool _isFetchingInstructors = false; // New: Loading state for instructors

  // For 'skin' and 'body' program types
  String? _selectedDayOfWeekForSkinBody; // e.g., "Monday"
  List<Map<String, String>> _availableDoctors = []; // Stores facilitator_id, facilitator_name, facilitator_position
  Map<String, String>? _selectedDoctor; // Stores the selected facilitator's map
  DateTime? _selectedDate; // Now represents the first selected date if multiple
  String? _selectedTimeSlot; // Now represents the time for the first selected date
  // List<String> generatedFlexibleTimeSlots = []; // Moved to SelectDatePage

  // New state variable to indicate if doctors are being fetched (already existed for skin/body)
  bool _isFetchingDoctors = false;

  // Member data for scheduling and payment
  Map<String, dynamic>? memberData;
  bool isLoadingMember = false;

  // New state variables for multi-session booking
  int _remainingSessions = 1; // Default to 1, will be fetched from memberData or specific service fetch
  int _sessionsToScheduleCount = 1; // Default to scheduling 1 session
  Map<DateTime, String> _finalSelectedDatesTimes = {}; // Stores all selected dates and times from SelectDatePage

  // Map to convert day names to Material's DateTime.weekday (1=Monday, 7=Sunday)
  final Map<String, int> _dayNameToWeekday = {
    'Monday': DateTime.monday,
    'Tuesday': DateTime.tuesday,
    'Wednesday': DateTime.wednesday,
    'Thursday': DateTime.thursday,
    'Friday': DateTime.friday,
    'Saturday': DateTime.saturday,
    'Sunday': DateTime.sunday,
  };

  @override
  void initState() {
    super.initState();
    _fetchServiceDetails();
    fetchMemberData(); // Fetch general member data on page init
  }

  // Fetches general member data from API (used on page load)
  Future<void> fetchMemberData() async {
    setState(() {
      isLoadingMember = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final memberId = prefs.getInt('member_id');
      final savedUsername = prefs.getString('username');

      if (memberId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member ID not found. Please log in again.')),
          );
        }
        setState(() => isLoadingMember = false);
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
        if (mounted) {
          setState(() {
            memberData = data['member'];
            if (savedUsername != null) {
              memberData!['username'] = savedUsername;
            }
            // _remainingSessions will be fetched specifically for the service later,
            // or if member_controller.php already returns 'remaining_sessions' for the current service, use it.
            // For now, it will be a default value unless explicitly provided by the API.
            _remainingSessions = int.tryParse(memberData!['remaining_sessions']?.toString() ?? '1') ?? 1;
            _sessionsToScheduleCount = _remainingSessions > 0 ? 1 : 0;
            isLoadingMember = false;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to load member data')),
          );
          setState(() => isLoadingMember = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching member data: $e')),
        );
        setState(() => isLoadingMember = false);
      }
    }
  }


  // Function to fetch service details including program type and availability
  Future<void> _fetchServiceDetails() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/get_available_dates.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'branch_code': widget.branchName,
          'service_name': widget.serviceName,
        }),
      );

      print('Response body from get_available_dates.php: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            _programType = jsonResponse['program_type'];
            if (_programType == 'class') {
              availableClassSlots = List<Map<String, String>>.from(
                (jsonResponse['available_slots'] as List? ?? [])
                    .map((item) => Map<String, String>.from(item)),
              );
            } else {
              // For 'skin' and 'body', we'll set up flexible time slots later.
              // We don't fetch specific days from the backend for these types now.
            }
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = jsonResponse['message'] ?? 'Failed to load service details.';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}. Please try again later.';
          isLoading = false;
        });
      }
    } on FormatException catch (e) {
      setState(() {
        errorMessage = 'Failed to parse data: Invalid JSON format. Error: ${e.message}';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching service details: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  // Function to fetch available doctors/instructors for the selected day (for Skin/Body)
  Future<void> _fetchDoctors(String selectedDay) async {
    setState(() {
      _isFetchingDoctors = true; // Set to true when fetching starts
      // Clear previous selections and errors related to doctors
      _availableDoctors.clear();
      _selectedDoctor = null;
      errorMessage = null; // Clear potential previous doctor errors
    });

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/fetch_doctors_remaining.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'branch_name': widget.branchName,
          'service_name': widget.serviceName,
          'selected_day': selectedDay,
        }),
      );

      print('Response body from fetch_doctors_remaining.php: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            _availableDoctors = (jsonResponse['facilitators'] as List? ?? []).map((item) {
              // Explicitly convert facilitator_id to String
              return {
                'facilitator_id': item['facilitator_id'].toString(), // Convert int to String
                'facilitator_name': item['facilitator_name'] as String,
                'facilitator_position': item['facilitator_position'] as String,
              };
            }).toList();
          });
        } else {
          setState(() {
            _availableDoctors.clear(); // Ensure list is clear if no doctors found
            errorMessage = jsonResponse['message'] ?? 'Failed to load doctors.';
          });
        }
      } else {
        setState(() {
          _availableDoctors.clear();
          errorMessage = 'Server error fetching doctors: ${response.statusCode}.';
        });
      }
    } on FormatException catch (e) {
      setState(() {
        _availableDoctors.clear();
        errorMessage = 'Failed to parse doctor data: Invalid JSON format. Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _availableDoctors.clear();
        errorMessage = 'Error fetching doctors: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isFetchingDoctors = false; // Set to false when fetching is complete (success or failure)
      });
    }
  }

  // New function to fetch available instructors for the selected class and day (for Class)
  Future<void> _fetchInstructors(String selectedDay) async {
    setState(() {
      _isFetchingInstructors = true; // Set to true when fetching starts
      _availableInstructors.clear();
      _selectedInstructor = null;
      errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/fetch_instructor_remaining.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'branch_name': widget.branchName,
          'service_name': widget.serviceName,
          'selected_day': selectedDay, // Pass the day of the class
        }),
      );

      print('Response body from fetch_instructor_remaining.php: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            _availableInstructors = (jsonResponse['facilitators'] as List? ?? []).map((item) {
              return {
                'facilitator_id': item['facilitator_id'].toString(),
                'facilitator_name': item['facilitator_name'] as String,
                'facilitator_position': item['facilitator_position'] as String,
              };
            }).toList();
          });
        } else {
          setState(() {
            _availableInstructors.clear();
            errorMessage = jsonResponse['message'] ?? 'Failed to load instructors.';
          });
        }
      } else {
        setState(() {
          _availableInstructors.clear();
          errorMessage = 'Server error fetching instructors: ${response.statusCode}.';
        });
      }
    } on FormatException catch (e) {
      setState(() {
        _availableInstructors.clear();
        errorMessage = 'Failed to parse instructor data: Invalid JSON format. Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _availableInstructors.clear();
        errorMessage = 'Error fetching instructors: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isFetchingInstructors = false; // Set to false when fetching is complete
      });
    }
  }


  // Function to navigate to SelectDatePage and get the selected date(s) and time(s) back
  Future<void> _navigateToSelectDatePage() async {
    if (_selectedDayOfWeekForSkinBody == null || _selectedDoctor == null) {
      _showAlertDialog('Selection Error', 'Please select a day of the week and a doctor first.');
      return;
    }

    // Clear previous selection before navigating to a new date selection
    setState(() {
      _finalSelectedDatesTimes.clear();
      _selectedDate = null;
      _selectedTimeSlot = null;
    });

    final Map<DateTime, String>? selectedDatesFromPage = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectDatePage(
          selectedDayOfWeekForSkinBody: _selectedDayOfWeekForSkinBody!,
          selectedDoctor: _selectedDoctor!,
          serviceName: widget.serviceName,
          branchName: widget.branchName,
          sessionsToSelect: _sessionsToScheduleCount, // Pass the count
        ),
      ),
    );

    if (selectedDatesFromPage != null && selectedDatesFromPage.isNotEmpty) {
      setState(() {
        _finalSelectedDatesTimes = selectedDatesFromPage;
        // For display purposes on this page, set _selectedDate and _selectedTimeSlot
        // to the first entry in the map, or null if the map is empty.
        if (_finalSelectedDatesTimes.isNotEmpty) {
          _selectedDate = _finalSelectedDatesTimes.keys.first;
          _selectedTimeSlot = _finalSelectedDatesTimes.values.first;
        } else {
          _selectedDate = null;
          _selectedTimeSlot = null;
        }
      });
    } else if (selectedDatesFromPage != null && selectedDatesFromPage.isEmpty) {
      // User returned from SelectDatePage without selecting any dates
      setState(() {
        _finalSelectedDatesTimes.clear();
        _selectedDate = null;
        _selectedTimeSlot = null;
      });
    }
  }


  // Function to handle the "Book Now" action
  void _bookNow() {
    if (_programType == 'class') {
      if (selectedClassSlot == null) {
        _showAlertDialog('Booking Error', 'Please select a day and time to book your session.');
        return;
      }
      if (_selectedInstructor == null) { // New check for instructor
        _showAlertDialog('Booking Error', 'Please select an instructor for your class session.');
        return;
      }

      // For class booking, create a single entry for _finalSelectedDatesTimes
      // You'll need to parse the day from selectedClassSlot to a DateTime object.
      // A simple way for a class that might repeat weekly is to use the current week's date for that day.
      final String dayName = selectedClassSlot!['day']!; // e.g., "Monday"
      final String timeSlot = selectedClassSlot!['time']!; // e.g., "8:00 AM - 9:00 AM"

      // Find the next upcoming date for the selected day of the week
      DateTime now = DateTime.now();
      int currentWeekday = now.weekday;
      int targetWeekday = _dayNameToWeekday[dayName]!; // Convert day name to DateTime.weekday

      DateTime classDate;
      if (currentWeekday <= targetWeekday) {
        classDate = now.add(Duration(days: targetWeekday - currentWeekday));
      } else {
        classDate = now.add(Duration(days: (7 - currentWeekday) + targetWeekday));
      }

      // For summary, use this single date/time pair.
      final Map<DateTime, String> classBookingMap = {classDate: timeSlot};

      // Call the common process payment and register sessions function
      showSummaryDialog(classBookingMap);

    } else { // For 'skin' and 'body'
      if (_selectedDayOfWeekForSkinBody == null ||
          _selectedDoctor == null ||
          _finalSelectedDatesTimes.isEmpty || // Check if any dates are selected
          _finalSelectedDatesTimes.length != _sessionsToScheduleCount // Ensure correct number of sessions selected
      ) {
        _showAlertDialog('Booking Error', 'Please select a day, doctor, and exactly $_sessionsToScheduleCount date(s) and time slot(s) to book your session.');
        return;
      }

      // Pass the fully populated map to the summary dialog
      showSummaryDialog(_finalSelectedDatesTimes);
    }
  }

  // Helper function to show a custom alert dialog (replaces alert())
  void _showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF394A7F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(title, style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(message, style: GoogleFonts.montserrat(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              child: Text('OK', style: GoogleFonts.montserrat(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Helper function for summary dialog
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130, // Adjusted width for better alignment
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

  // Helper function to get branch name (for summary dialog)
  Future<String?> _getBranchName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_branch_name');
  }

// NEW _processPaymentAndRegisterSessions function
  Future<void> _processPaymentAndRegisterSessions(Map<DateTime, String> selectedDatesTimes, String? finalReferenceId) async {
    final prefs = await SharedPreferences.getInstance();
    final branchName = prefs.getString('selected_branch_name') ?? 'default';
    final branchCode = prefs.getString('branch_code') ?? 'default_code';
    final tableName = '${branchName.replaceAll(' ', '_')}_logs';

    // Show a "Processing" dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D4373),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Registering sessions...',
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

    try {
      // --- New API CALL: Update members_services table (only track_sessions) ---
      final Map<String, dynamic> updateMemberSessionsData = {
        'nfc_uid': _sanitizeString(memberData?['nfc_uid']),
        'firstname': _sanitizeString(memberData?['firstname']),
        'mi': _sanitizeString(memberData?['mi']),
        'lastname': _sanitizeString(memberData?['lastname']),
        'suffix': _sanitizeString(memberData?['suffix']),
        'program': _sanitizeString(_programType),
        'services': _sanitizeString(widget.serviceName),
        'sessions_booked': _sessionsToScheduleCount,
      };

      print('Sending update data to update_member_sessions.php: ${jsonEncode(updateMemberSessionsData)}');
      final updateResponse = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/update_member_sessions.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(updateMemberSessionsData),
      );

      print('Response status from update_member_sessions.php: ${updateResponse.statusCode}');
      print('Response body from update_member_sessions.php: ${updateResponse.body}');

      final updateResult = jsonDecode(updateResponse.body);
      if (updateResponse.statusCode != 200 || updateResult['success'] != true) {
        throw Exception('Failed to update member sessions: ${updateResult['message'] ?? 'Unknown error'}');
      }


      // --- ONLY REMAINING API CALL: Insert into branch-specific log table (INDIVIDUAL ENTRIES) ---
      // For class type, selectedDatesTimes will contain only one entry derived from selectedClassSlot
      // For skin/body, it will contain multiple entries from SelectDatePage
      for (var entry in selectedDatesTimes.entries) {
        final date = entry.key;
        final time = entry.value;
        final scheduledTime = '${DateFormat('EEEE, MMM dd, y').format(date)} at $time';

        // Determine instructor/doctor based on program type
        String instructorId;
        String instructorName;
        if (_programType == 'class' && _selectedInstructor != null) {
          instructorId = _sanitizeString(_selectedInstructor!['facilitator_id']);
          instructorName = _sanitizeString(_selectedInstructor!['facilitator_name']);
        } else if ((_programType == 'skin' || _programType == 'body') && _selectedDoctor != null) {
          instructorId = _sanitizeString(_selectedDoctor!['facilitator_id']);
          instructorName = _sanitizeString(_selectedDoctor!['facilitator_name']);
        } else {
          instructorId = 'N/A';
          instructorName = 'N/A';
        }

        // Data for the branch-specific log table (individual appointment details)
        final Map<String, dynamic> logData = {
          'table': _sanitizeString(tableName),
          'nfc_uid': _sanitizeString(memberData?['nfc_uid']),
          'firstname': _sanitizeString(memberData?['firstname']),
          'mi': _sanitizeString(memberData?['mi']),
          'lastname': _sanitizeString(memberData?['lastname']),
          'suffix': _sanitizeString(memberData?['suffix']),
          'membership_code': _sanitizeString(memberData?['membership_code']),
          'membership_type': _sanitizeString(memberData?['membership_type']),
          'services': _sanitizeString(widget.serviceName),
          'scheduled_time': _sanitizeString(scheduledTime),
          'program': _sanitizeString(_programType),
          'branch_code': _sanitizeString(branchCode),
          'instructor_id': instructorId, // Use dynamically determined instructor/doctor
          'instructor_name': instructorName, // Use dynamically determined instructor/doctor
        };

        print('Sending log data to scheduled_appointment.php for date: $scheduledTime');
        final logResponse = await http.post(
          Uri.parse('https://membership.ndasphilsinc.com/scheduled_appointment.php'),
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

      // If all individual log entries were successful:
      if (!mounted) return;
      Navigator.pop(context); // Dismiss the "Registering sessions..." dialog
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
      print('Overall registration error: ${e.toString()}'); // Print full error message
      if (!mounted) return;
      Navigator.pop(context); // Dismiss the "Registering sessions..." dialog on error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error registering sessions: ${e.toString()}')),
      );
    }
  }

  // Helper function to sanitize strings
  String _sanitizeString(dynamic input) {
    if (input == null) return '';
    return input
        .toString()
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .trim();
  }


  // The full summary dialog function
  void showSummaryDialog(Map<DateTime, String> selectedDatesTimesMap) {
    final DateFormat dayFormatter = DateFormat('EEEE');
    final DateFormat dateFormatter = DateFormat('MMMM d, y');

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            // Price calculation is still done for internal logic, but not displayed to user
            final double pricePerSession = double.tryParse(widget.serviceName.contains('Body') ? '1000.00' : '500.00') ?? 0.0;
            final double totalPrice = pricePerSession * _sessionsToScheduleCount;

            // Determine the facilitator's name for the summary
            String facilitatorName;
            if (_programType == 'class' && _selectedInstructor != null) {
              facilitatorName = _selectedInstructor!['facilitator_name'] ?? 'N/A';
            } else if ((_programType == 'skin' || _programType == 'body') && _selectedDoctor != null) {
              facilitatorName = _selectedDoctor!['facilitator_name'] ?? 'N/A';
            } else {
              facilitatorName = 'N/A';
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF2D4373),
              title: const Text(
                'Booking Summary',
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
                  mainAxisSize: MainAxisSize.min, // Use min to wrap content
                  children: [
                    // Member Information
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

                    // Service Details
                    const Text(
                      'Service Details:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Service:', widget.serviceName), // Used widget.serviceName
                    _buildInfoRow('Facilitator:', facilitatorName), // Dynamic facilitator name

                    // Scheduled Dates & Times
                    const Text(
                      'Scheduled Dates & Times:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...selectedDatesTimesMap.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• ${dateFormatter.format(entry.key)} (${dayFormatter.format(entry.key)}) at ${entry.value}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )).toList(),

                    const Divider(color: Colors.white30),

                    // Booking Details
                    const Text(
                      'Booking Details:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Program Type:', _programType!), // Used _programType
                    _buildInfoRow('Number of Sessions:', '$_remainingSessions'), // Now shows remaining sessions
                    _buildInfoRow('Sessions to Schedule:', '${selectedDatesTimesMap.length}'), // Already correct

                    // Removed the "Total Amount" row as per request
                    // _buildInfoRow('Total Amount:', '₱${totalPrice.toStringAsFixed(2)}'),

                    const Divider(color: Colors.white30),

                    // Branch Information
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
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop(); // Dismiss summary dialog
                    await _processPaymentAndRegisterSessions(
                      selectedDatesTimesMap,
                      'DirectBooking-${DateTime.now().millisecondsSinceEpoch}', // Generate a unique reference ID
                    );
                  },
                  child: const Text(
                    'Confirm & Book',
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
    // Moved up to be accessible for the date formatting
    final DateFormat _dateFormatter = DateFormat('MMMM d, y (EEEE)');

    return Scaffold(
      backgroundColor: const Color(0xFF253660),
      appBar: AppBar(
        title: Text(
          "Book ${widget.serviceName}",
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF253660),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView( // Made the content scrollable
          child: isLoading || isLoadingMember // Show overall loading if either is loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : errorMessage != null
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          )
              : Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You are booking a session for:",
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Service: ${widget.serviceName}",
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  "Branch: ${widget.branchName}",
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 30),
                // Conditional UI based on program type
                if (_programType == 'class') ...[
                  Text(
                    "Select an available day:",
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Dropdown for selecting the day for 'class' type
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF394A7F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, String>>(
                        isExpanded: true,
                        value: selectedClassSlot,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white),
                        dropdownColor: const Color(0xFF394A7F),
                        hint: Text(
                          availableClassSlots.isEmpty ? 'No days available' : 'Choose a day',
                          style: GoogleFonts.montserrat(color: Colors.white70),
                        ),
                        onChanged: (Map<String, String>? newValue) {
                          setState(() {
                            selectedClassSlot = newValue;
                            _selectedInstructor = null; // Reset instructor when class slot changes
                          });
                          if (newValue != null && newValue['day'] != null) {
                            _fetchInstructors(newValue['day']!); // Fetch instructors for selected day
                          }
                        },
                        items: availableClassSlots.map<DropdownMenuItem<Map<String, String>>>((Map<String, String> dayTime) {
                          return DropdownMenuItem<Map<String, String>>(
                            value: dayTime,
                            child: Text(
                              dayTime['day']!,
                              style: GoogleFonts.montserrat(color: Colors.white),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Dropdown for Instructors (visible after class slot is selected)
                  if (selectedClassSlot != null) ...[
                    Text(
                      "Select Instructor:",
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _isFetchingInstructors
                        ? const Center(child: CircularProgressIndicator(color: Colors.white)) // Show loading indicator
                        : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF394A7F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, String>>(
                          isExpanded: true,
                          value: _selectedInstructor,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white),
                          dropdownColor: const Color(0xFF394A7F),
                          hint: Text(
                            _availableInstructors.isEmpty
                                ? (_isFetchingInstructors ? 'Loading instructors...' : 'No instructors available')
                                : 'Choose an instructor',
                            style: GoogleFonts.montserrat(color: Colors.white70),
                          ),
                          onChanged: (Map<String, String>? newValue) {
                            setState(() {
                              _selectedInstructor = newValue;
                            });
                          },
                          items: _availableInstructors.map<DropdownMenuItem<Map<String, String>>>((Map<String, String> instructor) {
                            return DropdownMenuItem<Map<String, String>>(
                              value: instructor,
                              child: Text(
                                instructor['facilitator_name']!,
                                style: GoogleFonts.montserrat(color: Colors.white),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Display selected time slot for 'class' type
                  if (selectedClassSlot != null)
                    Text(
                      "Time Slot: ${selectedClassSlot!['time']}",
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                ] else if (_programType == 'skin' || _programType == 'body') ...[
                  // --- UI for Skin/Body services ---
                  Text(
                    "Select Day of Week:",
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Dropdown for Day of Week
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF394A7F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedDayOfWeekForSkinBody,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white),
                        dropdownColor: const Color(0xFF394A7F),
                        hint: Text(
                          'Choose a day',
                          style: GoogleFonts.montserrat(color: Colors.white70),
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedDayOfWeekForSkinBody = newValue;
                            // Reset doctor, date, time when day changes
                            _selectedDoctor = null;
                            _selectedDate = null;
                            _selectedTimeSlot = null;
                            _finalSelectedDatesTimes.clear(); // Clear final selections
                          });
                          if (newValue != null) {
                            _fetchDoctors(newValue); // Pass the newly selected day to fetch doctors
                          }
                        },
                        items: _dayNameToWeekday.keys.map<DropdownMenuItem<String>>((String day) {
                          return DropdownMenuItem<String>(
                            value: day,
                            child: Text(
                              day,
                              style: GoogleFonts.montserrat(color: Colors.white),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Dropdown for Doctors (visible after day is selected)
                  if (_selectedDayOfWeekForSkinBody != null) ...[
                    Text(
                      "Select Doctor/Instructor:",
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _isFetchingDoctors
                        ? const Center(child: CircularProgressIndicator(color: Colors.white)) // Show loading indicator
                        : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF394A7F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, String>>(
                          isExpanded: true,
                          value: _selectedDoctor,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white),
                          dropdownColor: const Color(0xFF394A7F),
                          hint: Text(
                            _availableDoctors.isEmpty
                                ? (_isFetchingDoctors ? 'Loading doctors...' : 'No doctors available')
                                : 'Choose a doctor',
                            style: GoogleFonts.montserrat(color: Colors.white70),
                          ),
                          onChanged: (Map<String, String>? newValue) {
                            setState(() {
                              _selectedDoctor = newValue;
                              // Reset dates/times when doctor changes
                              _selectedDate = null;
                              _selectedTimeSlot = null;
                              _finalSelectedDatesTimes.clear(); // Clear final selections
                            });
                          },
                          items: _availableDoctors.map<DropdownMenuItem<Map<String, String>>>((Map<String, String> doctor) {
                            return DropdownMenuItem<Map<String, String>>(
                              value: doctor,
                              child: Text(
                                // Access the 'facilitator_name' key from the PHP response
                                doctor['facilitator_name']!,
                                style: GoogleFonts.montserrat(color: Colors.white),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // "How many sessions to schedule?" dropdown
                  if (_selectedDoctor != null && _remainingSessions > 1) ...[ // Only show if more than 1 remaining session
                    Text(
                      "How many sessions to schedule (out of $_remainingSessions remaining):",
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF394A7F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _sessionsToScheduleCount,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white),
                          dropdownColor: const Color(0xFF394A7F),
                          onChanged: (int? newValue) {
                            setState(() {
                              _sessionsToScheduleCount = newValue!;
                              _selectedDate = null;
                              _selectedTimeSlot = null;
                              _finalSelectedDatesTimes.clear(); // Clear existing selections
                            });
                          },
                          // Dynamically generate options from 1 up to _remainingSessions
                          items: List.generate(_remainingSessions, (index) => index + 1)
                              .map<DropdownMenuItem<int>>((int count) {
                            return DropdownMenuItem<int>(
                              value: count,
                              child: Text(
                                '$count session(s)',
                                style: GoogleFonts.montserrat(color: Colors.white),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Date selection button (visible after doctor is selected)
                  // It will now always show if a doctor is selected, whether 1 or multiple sessions are remaining
                  if (_selectedDoctor != null) ...[
                    Text(
                      "Select Date(s):",
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Center(
                      child: ElevatedButton(
                        onPressed: _navigateToSelectDatePage, // Call the new navigation function
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3D5184),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: Text(
                          _finalSelectedDatesTimes.isEmpty
                              ? 'Choose Date(s)'
                              : 'Selected: ${_finalSelectedDatesTimes.length} date(s)',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (_finalSelectedDatesTimes.isNotEmpty && _selectedDoctor != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Text(
                          "Doctor: ${_selectedDoctor!['facilitator_name']}",
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            color: Colors.white70,

                          ),
                        ),
                      ),
                    // Display selected dates and times if any
                    if (_finalSelectedDatesTimes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Selected Dates & Times:",
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            ..._finalSelectedDatesTimes.entries.map((entry) => Text(
                              '• ${DateFormat('MMMM d, y (EEEE)').format(entry.key)} at ${entry.value}',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: 30),
                Center(
                  child: ElevatedButton(
                    onPressed: _bookNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D5184), // A vibrant color for "Book Now"
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 7,
                      shadowColor: Colors.black.withOpacity(0.4),
                    ),
                    child: Text(
                      'Book Now',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
