import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Enum to represent the status of a scheduled activity
enum ScheduleStatus {
  upcoming, // Future or current time on the current day
  late,     // Past hour on the current day
  voided,   // Past day
}

// Main page for viewing member details and selecting a branch
class ViewYourSchedulePage extends StatefulWidget {
  const ViewYourSchedulePage({Key? key}) : super(key: key);

  @override
  _ViewYourSchedulePageState createState() => _ViewYourSchedulePageState();
}

class _ViewYourSchedulePageState extends State<ViewYourSchedulePage> {
  Map<String, dynamic>? memberDetails;
  List<Map<String, dynamic>> availableBranches = [];
  bool isLoading = true;
  String? errorMessage;
  String? selectedBranchCode;
  String? firstNameFromPrefs;

  // Variables to hold the current member's name details for filtering
  String? currentMemberFirstName;
  String? currentMemberMI;
  String? currentMemberLastName;
  String? currentMemberSuffix;

  @override
  void initState() {
    super.initState();
    _loadAndFetchMemberData();
  }

  Future<void> _loadAndFetchMemberData() async {
    final prefs = await SharedPreferences.getInstance();
    final int? memberIdInt = prefs.getInt('member_id');
    String? memberId = memberIdInt?.toString() ?? prefs.getString('member_id');

    firstNameFromPrefs = prefs.getString('fullname')?.split(' ').first ?? 'Member';

    if (memberId == null || memberId.isEmpty) {
      setState(() {
        isLoading = false;
        errorMessage = 'No member ID found.';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/check_member_type.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'member_id': memberId}),
      );

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['success'] == true) {
        setState(() {
          memberDetails = jsonResponse['member_details'] ?? {};
          if (memberDetails!.containsKey('membership_type')) {
            memberDetails!['member_type'] = memberDetails!['membership_type'];
          }
          // Store member's name details
          currentMemberFirstName = memberDetails!['firstname']?.toString();
          currentMemberMI = memberDetails!['mi']?.toString();
          currentMemberLastName = memberDetails!['lastname']?.toString();
          currentMemberSuffix = memberDetails!['suffix']?.toString();
        });
      } else {
        setState(() {
          errorMessage = jsonResponse['message'] ?? 'Failed to load member details.';
          isLoading = false;
        });
        throw Exception(errorMessage);
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching member details: ${e.toString()}';
        isLoading = false;
      });
      throw Exception(errorMessage);
    }

    // After fetching member details, proceed to fetch branches
    try {
      if (memberDetails != null) {
        await _fetchMemberBranches(memberId);
      } else {
        setState(() {
          errorMessage = 'Could not retrieve member details to fetch branches.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error during branch loading: $e';
        isLoading = false;
      });
    }
  }


  Future<void> _fetchMemberBranches(String memberId) async {
    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/member_controller.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'member_id': memberId}),
      );

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['success'] == true) {
        setState(() {
          availableBranches = List<Map<String, dynamic>>.from(jsonResponse['branches'] ?? []);
          isLoading = false;
          errorMessage = null;
        });
      } else {
        setState(() {
          errorMessage = 'Error fetching branches: ${jsonResponse['message'] ?? 'Unknown error'}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network or parsing error for branches: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  // --- FUNCTION TO FETCH BRANCH LOGS AND NAVIGATE ---
  Future<void> _fetchBranchLogs(String branchCode) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Create a temporary map to build the request body
      final Map<String, String> requestData = {
        'branchname': branchCode,
      };

      if (currentMemberFirstName != null) {
        requestData['firstname'] = currentMemberFirstName!;
      }
      if (currentMemberMI != null) {
        requestData['mi'] = currentMemberMI!;
      }
      if (currentMemberLastName != null) {
        requestData['lastname'] = currentMemberLastName!;
      }
      if (currentMemberSuffix != null) {
        requestData['suffix'] = currentMemberSuffix!;
      }

      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/get_branch_details.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: requestData, // Pass the new map directly
      );

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['success'] == true) {
        List<Map<String, dynamic>> fetchedLogs = List<Map<String, dynamic>>.from(jsonResponse['data'] ?? []);

        // Improved sorting by actual datetime
        fetchedLogs.sort((a, b) {
          String? timeA = a['scheduled_time'];
          String? timeB = b['scheduled_time'];

          if (timeA == null || timeA.isEmpty) return 1;
          if (timeB == null || timeB.isEmpty) return -1;

          // Extract start time from various formats
          String startTimeA = _extractStartTime(timeA);
          String startTimeB = _extractStartTime(timeB);

          try {
            DateTime? dateA = _parseScheduledTime(startTimeA);
            DateTime? dateB = _parseScheduledTime(startTimeB);

            if (dateA == null || dateB == null) {
              print('Failed to parse dates: "$startTimeA" or "$startTimeB"');
              return 0;
            }

            return dateA.compareTo(dateB);
          } catch (e) {
            print('Error during datetime comparison: $e');
            return 0;
          }
        });

        setState(() {
          isLoading = false;
        });

        final selectedBranch = availableBranches.firstWhere(
              (branch) => branch['branch_code'] == selectedBranchCode,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScheduleViewPage(
              initialLogs: fetchedLogs,
              branchName: selectedBranch['branch_name']?.toString() ?? branchCode,
            ),
          ),
        );
      } else {
        setState(() {
          errorMessage = 'Error fetching branch logs: ${jsonResponse['message'] ?? 'Unknown error'}';
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage!),
            backgroundColor: Colors.red.shade300,
          ),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network or parsing error for branch logs: ${e.toString()}';
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage!),
          backgroundColor: Colors.red.shade300,
        ),
      );
    }
  }

// Add this helper function to extract start time from various formats
  String _extractStartTime(String timeString) {
    timeString = timeString.trim();

    // Handle formats with " - " (dash for time range)
    if (timeString.contains(' - ')) {
      return timeString.split(' - ')[0].trim();
    }

    // Handle formats with " to "
    if (timeString.contains(' to ')) {
      return timeString.split(' to ')[0].trim();
    }

    // If no range separator, return the whole string
    return timeString;
  }

// Add this helper function to parse different datetime formats
  DateTime? _parseScheduledTime(String timeString) {
    List<DateFormat> formats = [
      DateFormat('EEEE, MMM dd,yyyy \'at\' h:mm a'),    // Monday, Jul 14, 2025 at 12:00 PM
      DateFormat('EEEE, MMM dd,yyyy \'at\' h:mma'),     // Monday, Jul 14, 2025 at 7:30am
      DateFormat('EEEE, MMM d,yyyy \'at\' h:mm a'),     // Monday, Jul 3, 2025 at 12:00 PM
      DateFormat('EEEE, MMM d,yyyy \'at\' h:mma'),      // Monday, Jul 3, 2025 at 7:30am
      DateFormat('EEEE, MMM dd,yyyy h:mm a'),           // Monday, Jul 14, 2025 12:00 PM (without "at")
      DateFormat('EEEE, MMM dd,yyyy h:mma'),            // Monday, Jul 14, 2025 7:30am
      DateFormat('EEEE, MMM d,yyyy h:mm a'),            // Monday, Jul 3, 2025 12:00 PM
      DateFormat('EEEE, MMM d,yyyy h:mma'),             // Monday, Jul 3, 2025 7:30am
      DateFormat('MMM dd,yyyy \'at\' h:mm a'),          // Jul 14, 2025 at 12:00 PM (without day name)
      DateFormat('MMM dd,yyyy \'at\' h:mma'),           // Jul 14, 2025 at 7:30am
      DateFormat('MMM d,yyyy \'at\' h:mm a'),           // Jul 3, 2025 at 12:00 PM
      DateFormat('MMM d,yyyy \'at\' h:mma'),            // Jul 3, 2025 at 7:30am
      DateFormat('MMM dd,yyyy h:mm a'),                 // Jul 14, 2025 12:00 PM
      DateFormat('MMM dd,yyyy h:mma'),                  // Jul 14, 2025 7:30am
      DateFormat('MMM d,yyyy h:mm a'),                  // Jul 3, 2025 12:00 PM
      DateFormat('MMM d,yyyy h:mma'),                   // Jul 3, 2025 7:30am
    ];

    for (DateFormat format in formats) {
      try {
        return format.parse(timeString);
      } catch (e) {
        // Continue to next format
        continue;
      }
    }

    // If all formats fail, try manual parsing
    try {
      return _manualDateTimeParse(timeString);
    } catch (e) {
      print('All parsing attempts failed for: "$timeString"');
      return null;
    }
  }

// Manual parsing as fallback
  DateTime? _manualDateTimeParse(String timeString) {
    try {
      // Remove "at" if present
      String cleanTime = timeString.replaceAll(' at ', ' ');

      // Remove day name if present
      List<String> dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      for (String day in dayNames) {
        if (cleanTime.startsWith(day)) {
          cleanTime = cleanTime.substring(day.length).trim();
          if (cleanTime.startsWith(',')) {
            cleanTime = cleanTime.substring(1).trim();
          }
          break;
        }
      }

      // Parse format like "Jul 14, 2025 12:00 PM" or "Jul 14, 2025 7:30am"
      RegExp regExp = RegExp(r'(\w{3})\s+(\d{1,2}),\s+(\d{4})\s+(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)', caseSensitive: false);
      Match? match = regExp.firstMatch(cleanTime);

      if (match != null) {
        String monthStr = match.group(1)!;
        int day = int.parse(match.group(2)!);
        int year = int.parse(match.group(3)!);
        int hour = int.parse(match.group(4)!);
        int minute = int.parse(match.group(5)!);
        String ampm = match.group(6)!.toUpperCase();

        // Convert month string to number
        Map<String, int> months = {
          'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
          'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
        };

        int month = months[monthStr.toUpperCase()] ?? 1;

        // Convert to 24-hour format
        if (ampm == 'PM' && hour != 12) {
          hour += 12;
        } else if (ampm == 'AM' && hour == 12) {
          hour = 0;
        }

        return DateTime(year, month, day, hour, minute);
      }

      return null;
    } catch (e) {
      print('Manual parsing failed: $e');
      return null;
    }
  }

  void _onBranchSelected(String branchCode, String branchName) {
    setState(() {
      selectedBranchCode = branchCode;
    });
    // Automatically navigate to the schedule page after selecting a branch
    _fetchBranchLogs(branchCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF253660),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : errorMessage != null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  errorMessage!,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.red.shade300,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadAndFetchMemberData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C5C92),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            // Header: Scheduled Activities
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Scheduled Activities",
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD3D7E0),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Branch Selection Header
                    Text(
                      'Select Branch',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a branch to view your schedules.',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: const Color(0xFFCED4F1),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Branch Cards
                    if (availableBranches.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF394A7F),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'No branches available for your membership type or an error occurred.',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              color: const Color(0xFFCED4F1),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...availableBranches.map((branch) {
                        final branchCode = branch['branch_code']?.toString() ?? '';
                        final branchName = branch['branch_name']?.toString() ?? 'Unknown Branch';
                        final isSelected = selectedBranchCode == branchCode;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _onBranchSelected(branchCode, branchName),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? const LinearGradient(
                                  colors: [Color(0xFF4C5C92), Color(0xFF6B7DB8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                                    : const LinearGradient(
                                  colors: [Color(0xFF394A7F), Color(0xFF2E3A67)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: isSelected ? 12 : 8,
                                    offset: Offset(0, isSelected ? 6 : 4),
                                  ),
                                ],
                                border: isSelected
                                    ? Border.all(color: Colors.white30, width: 2)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          branchName,
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tap to select this branch',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 14,
                                            color: const Color(0xFFCED4F1),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Color(0xFF4C5C92),
                                        size: 20,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Color(0xFFCED4F1),
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    const SizedBox(height: 24),
                    // Removed the "View Schedule" button
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

// Schedule View Page - now nested within the same file
class ScheduleViewPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialLogs;
  final String branchName;

  const ScheduleViewPage({
    Key? key,
    required this.initialLogs,
    required this.branchName,
  }) : super(key: key);

  @override
  State<ScheduleViewPage> createState() => _ScheduleViewPageState();
}

class _ScheduleViewPageState extends State<ScheduleViewPage> {
  late List<Map<String, dynamic>> _allLogs; // Store all fetched logs
  late List<Map<String, dynamic>> _filteredLogs; // Logs displayed after filtering
  String? _selectedProgramType; // Null for "All Programs"
  List<String> _programTypes = [];
  Set<ScheduleStatus> _selectedStatusFilter = {ScheduleStatus.upcoming}; // Default to Upcoming

  @override
  void initState() {
    super.initState();
    _allLogs = widget.initialLogs; // Initialize allLogs with the passed data
    _programTypes = _extractUniqueProgramTypes(_allLogs);
    _applyFilters(); // Apply initial filter
  }

  // Extracts unique program types from the initial logs to populate the dropdown
  List<String> _extractUniqueProgramTypes(List<Map<String, dynamic>> logs) {
    Set<String> types = {};
    for (var log in logs) {
      if (log['program'] != null && log['program'].isNotEmpty) {
        types.add(log['program'].toString());
      }
    }
    List<String> sortedTypes = types.toList();
    sortedTypes.sort(); // Sort alphabetically for consistent order
    return ['All Programs', ...sortedTypes]; // Add "All Programs" option at the beginning
  }

  // Helper function to determine the status of a scheduled activity
  ScheduleStatus _getScheduleStatus(String? scheduledTime) {
    if (scheduledTime == null || scheduledTime.isEmpty) return ScheduleStatus.upcoming; // Default to upcoming if time is null

    String parseableTime = scheduledTime.split(' to ')[0].trim();

    try {
      DateTime? scheduledDateTime = _parseScheduledTime(parseableTime);
      if (scheduledDateTime == null) return ScheduleStatus.upcoming; // Treat as upcoming if parsing fails

      DateTime now = DateTime.now();

      // Check if the scheduled date is entirely in the past (before today)
      if (scheduledDateTime.year < now.year ||
          (scheduledDateTime.year == now.year && scheduledDateTime.month < now.month) ||
          (scheduledDateTime.year == now.year && scheduledDateTime.month == now.month && scheduledDateTime.day < now.day)) {
        return ScheduleStatus.voided;
      }

      // Check if the scheduled date is today, but the time has passed
      if (scheduledDateTime.year == now.year &&
          scheduledDateTime.month == now.month &&
          scheduledDateTime.day == now.day &&
          scheduledDateTime.isBefore(now)) {
        return ScheduleStatus.late;
      }

      // Otherwise, it's upcoming (future date or future time on current day)
      return ScheduleStatus.upcoming;
    } catch (e) {
      print('Error parsing date "$scheduledTime" in _getScheduleStatus (ScheduleViewPage): $e');
      return ScheduleStatus.upcoming; // Treat as upcoming if parsing fails
    }
  }

  // Add this helper function to extract start time from various formats
  String _extractStartTime(String timeString) {
    timeString = timeString.trim();

    // Handle formats with " - " (dash for time range)
    if (timeString.contains(' - ')) {
      return timeString.split(' - ')[0].trim();
    }

    // Handle formats with " to "
    if (timeString.contains(' to ')) {
      return timeString.split(' to ')[0].trim();
    }

    // If no range separator, return the whole string
    return timeString;
  }

// Add this helper function to parse different datetime formats
  DateTime? _parseScheduledTime(String timeString) {
    List<DateFormat> formats = [
      DateFormat('EEEE, MMM dd,yyyy \'at\' h:mm a'),    // Monday, Jul 14, 2025 at 12:00 PM
      DateFormat('EEEE, MMM dd,yyyy \'at\' h:mma'),     // Monday, Jul 14, 2025 at 7:30am
      DateFormat('EEEE, MMM d,yyyy \'at\' h:mm a'),     // Monday, Jul 3, 2025 at 12:00 PM
      DateFormat('EEEE, MMM d,yyyy \'at\' h:mma'),      // Monday, Jul 3, 2025 at 7:30am
      DateFormat('EEEE, MMM dd,yyyy h:mm a'),           // Monday, Jul 14, 2025 12:00 PM (without "at")
      DateFormat('EEEE, MMM dd,yyyy h:mma'),            // Monday, Jul 14, 2025 7:30am
      DateFormat('EEEE, MMM d,yyyy h:mm a'),            // Monday, Jul 3, 2025 12:00 PM
      DateFormat('EEEE, MMM d,yyyy h:mma'),             // Monday, Jul 3, 2025 7:30am
      DateFormat('MMM dd,yyyy \'at\' h:mm a'),          // Jul 14, 2025 at 12:00 PM (without day name)
      DateFormat('MMM dd,yyyy \'at\' h:mma'),           // Jul 14, 2025 at 7:30am
      DateFormat('MMM d,yyyy \'at\' h:mm a'),           // Jul 3, 2025 at 12:00 PM
      DateFormat('MMM d,yyyy \'at\' h:mma'),            // Jul 3, 2025 at 7:30am
      DateFormat('MMM dd,yyyy h:mm a'),                 // Jul 14, 2025 12:00 PM
      DateFormat('MMM dd,yyyy h:mma'),                  // Jul 14, 2025 7:30am
      DateFormat('MMM d,yyyy h:mm a'),                  // Jul 3, 2025 12:00 PM
      DateFormat('MMM d,yyyy h:mma'),                   // Jul 3, 2025 7:30am
    ];

    for (DateFormat format in formats) {
      try {
        return format.parse(timeString);
      } catch (e) {
        // Continue to next format
        continue;
      }
    }

    // If all formats fail, try manual parsing
    try {
      return _manualDateTimeParse(timeString);
    } catch (e) {
      print('All parsing attempts failed for: "$timeString"');
      return null;
    }
  }

// Manual parsing as fallback
  DateTime? _manualDateTimeParse(String timeString) {
    try {
      // Remove "at" if present
      String cleanTime = timeString.replaceAll(' at ', ' ');

      // Remove day name if present
      List<String> dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      for (String day in dayNames) {
        if (cleanTime.startsWith(day)) {
          cleanTime = cleanTime.substring(day.length).trim();
          if (cleanTime.startsWith(',')) {
            cleanTime = cleanTime.substring(1).trim();
          }
          break;
        }
      }

      // Parse format like "Jul 14, 2025 12:00 PM" or "Jul 14, 2025 7:30am"
      RegExp regExp = RegExp(r'(\w{3})\s+(\d{1,2}),\s+(\d{4})\s+(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)', caseSensitive: false);
      Match? match = regExp.firstMatch(cleanTime);

      if (match != null) {
        String monthStr = match.group(1)!;
        int day = int.parse(match.group(2)!);
        int year = int.parse(match.group(3)!);
        int hour = int.parse(match.group(4)!);
        int minute = int.parse(match.group(5)!);
        String ampm = match.group(6)!.toUpperCase();

        // Convert month string to number
        Map<String, int> months = {
          'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
          'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
        };

        int month = months[monthStr.toUpperCase()] ?? 1;

        // Convert to 24-hour format
        if (ampm == 'PM' && hour != 12) {
          hour += 12;
        } else if (ampm == 'AM' && hour == 12) {
          hour = 0;
        }

        return DateTime(year, month, day, hour, minute);
      }

      return null;
    } catch (e) {
      print('Manual parsing failed: $e');
      return null;
    }
  }

  // Combined filter logic for program type and status
  void _applyFilters() {
    setState(() {
      List<Map<String, dynamic>> tempFiltered = _allLogs;

      // Filter by Program Type
      if (_selectedProgramType != null && _selectedProgramType != 'All Programs') {
        tempFiltered = tempFiltered
            .where((log) => log['program'] == _selectedProgramType)
            .toList();
      }

      // Filter by Schedule Status
      if (_selectedStatusFilter.isNotEmpty) {
        tempFiltered = tempFiltered.where((log) {
          final status = _getScheduleStatus(log['scheduled_time']);
          return _selectedStatusFilter.contains(status);
        }).toList();
      }

      _filteredLogs = tempFiltered;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF253660),
      appBar: AppBar(
        backgroundColor: const Color(0xFF394A7F),
        title: Text(
          'Schedule for ${widget.branchName}',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white), // Ensures back button is white
      ),
      body: Column(
        children: [
          // Dropdown for filtering program types
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: DropdownButtonFormField<String>(
              value: _selectedProgramType,
              decoration: InputDecoration(
                labelText: 'Filter by Program Type',
                labelStyle: GoogleFonts.montserrat(color: const Color(0xFFCED4F1)),
                fillColor: const Color(0xFF394A7F),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              dropdownColor: const Color(0xFF394A7F), // Background color of the dropdown menu
              style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white), // Dropdown arrow icon
              items: _programTypes.map((String type) {
                String displayText = type == 'All Programs'
                    ? 'All Programs'
                    : type[0].toUpperCase() + type.substring(1); // Capitalize first letter
                return DropdownMenuItem<String>(
                  value: type == 'All Programs' ? null : type, // Null value for 'All Programs'
                  child: Text(displayText),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedProgramType = newValue;
                  _applyFilters(); // Re-filter logs when selection changes
                });
              },
            ),
          ),
          // Segmented Button for Status Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ScheduleStatus>(
                segments: const <ButtonSegment<ScheduleStatus>>[
                  ButtonSegment<ScheduleStatus>(
                    value: ScheduleStatus.upcoming,
                    label: Text('Set for'), // Changed from 'Upcoming' to 'Future'
                    icon: Icon(Icons.check_circle_outline),
                  ),
                  ButtonSegment<ScheduleStatus>(
                    value: ScheduleStatus.late,
                    label: Text('Late'),
                    icon: Icon(Icons.access_time),
                  ),
                  ButtonSegment<ScheduleStatus>(
                    value: ScheduleStatus.voided,
                    label: Text('Void'),
                    icon: Icon(Icons.cancel_outlined),
                  ),
                ],
                selected: _selectedStatusFilter,
                onSelectionChanged: (Set<ScheduleStatus> newSelection) {
                  setState(() {
                    // Allow only single selection
                    _selectedStatusFilter = newSelection;
                    _applyFilters();
                  });
                },
                style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                      if (states.contains(MaterialState.selected)) {
                        return Colors.white; // Text color for selected segment
                      }
                      return const Color(0xFFCED4F1); // Text color for unselected segments
                    },
                  ),
                  backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                      if (states.contains(MaterialState.selected)) {
                        // Custom colors for selected states
                        if (_selectedStatusFilter.contains(ScheduleStatus.upcoming)) {
                          return Colors.green.shade600;
                        } else if (_selectedStatusFilter.contains(ScheduleStatus.late)) {
                          return Colors.orange.shade600;
                        } else if (_selectedStatusFilter.contains(ScheduleStatus.voided)) {
                          return Colors.red.shade600;
                        }
                      }
                      return const Color(0xFF394A7F); // Background for unselected
                    },
                  ),
                  overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.1)),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  side: MaterialStateProperty.all(BorderSide.none), // Remove default border
                ),
              ),
            ),
          ),
          // List of scheduled activities
          Expanded(
            child: _filteredLogs.isEmpty
                ? Center(
              child: Text(
                'No scheduled activities found for this filter.',
                style: GoogleFonts.montserrat(color: const Color(0xFFCED4F1), fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: _filteredLogs.length,
              itemBuilder: (context, index) {
                final log = _filteredLogs[index];
                final ScheduleStatus status = _getScheduleStatus(log['scheduled_time']);
                final String fullTimeRange = log['scheduled_time'] ?? 'N/A';

                Color cardColor;
                Color borderColor;
                Color tagColor;
                Color tagTextColor;
                String tagText = '';
                Color iconColor;
                Color timeTextColor;

                switch (status) {
                  case ScheduleStatus.voided:
                    cardColor = const Color(0xFF4A2C2C); // Dark red for voided
                    borderColor = Colors.red.shade300;
                    tagColor = Colors.red.shade300;
                    tagTextColor = Colors.white;
                    tagText = 'VOID';
                    iconColor = Colors.red.shade200;
                    timeTextColor = Colors.red.shade300;
                    break;
                  case ScheduleStatus.late:
                    cardColor = const Color(0xFF604225); // Dark orange for late
                    borderColor = Colors.orange.shade300;
                    tagColor = Colors.orange.shade300;
                    tagTextColor = Colors.white;
                    tagText = 'LATE';
                    iconColor = Colors.orange.shade200;
                    timeTextColor = Colors.orange.shade300;
                    break;
                  case ScheduleStatus.upcoming:
                  default:
                    cardColor = const Color(0xFF2E4A2C); // Darker green for upcoming card background
                    borderColor = Colors.green.shade300; // Green border for upcoming
                    tagColor = Colors.green.shade300; // Green tag for upcoming
                    tagTextColor = Colors.white;
                    tagText = 'UPCOMING'; // Changed from 'UPCOMING' to 'FUTURE'
                    iconColor = Colors.green.shade200; // Lighter green for icons
                    timeTextColor = Colors.green.shade300; // Green time text
                    break;
                }

                return Card(
                  color: cardColor,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: borderColor,
                      width: 1,
                    ), // Always show border based on status
                  ),
                  elevation: 4, // Add a slight shadow
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status tag (VOID, LATE, or UPCOMING)
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: tagColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tagText,
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                                color: tagTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Member Name
                        Text(
                          '${log['firstname'] ?? ''} ${log['mi'] ?? ''} ${log['lastname'] ?? ''} ${log['suffix'] ?? ''}',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            color: Colors.white, // Member name is always white
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Details using a helper row widget for consistency
                        _buildDetailRow(
                          Icons.person_outline,
                          'Membership Type',
                          log['membership_type'] ?? 'N/A',
                          iconColor, // Pass color based on status
                          status, // Pass status to detail row for text color adjustment
                        ),
                        _buildDetailRow(
                          Icons.category_outlined,
                          'Program',
                          log['program'] ?? 'N/A',
                          iconColor,
                          status,
                        ),
                        _buildDetailRow(
                          Icons.room_service_outlined,
                          'Services',
                          log['services'] ?? 'N/A',
                          iconColor,
                          status,
                        ),
                        _buildDetailRow(
                          Icons.group_outlined,
                          'Facilitator',
                          log['facilitator'] ?? 'N/A',
                          iconColor,
                          status,
                        ),
                        const SizedBox(height: 12),
                        // Scheduled Time display
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: status == ScheduleStatus.voided
                                ? Colors.red.shade900.withOpacity(0.4)
                                : status == ScheduleStatus.late
                                ? Colors.orange.shade900.withOpacity(0.4)
                                : Colors.green.shade900.withOpacity(0.4), // Green for upcoming
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: status == ScheduleStatus.voided
                                  ? Colors.red.shade400
                                  : status == ScheduleStatus.late
                                  ? Colors.orange.shade400
                                  : Colors.green.shade400, // Green for upcoming
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                color: timeTextColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  fullTimeRange, // Display the full original time range
                                  style: GoogleFonts.montserrat(
                                    color: timeTextColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Reusable widget to display a detail row with an icon, label, and value
  Widget _buildDetailRow(IconData icon, String label, String value, Color iconColor, ScheduleStatus status) {
    Color textColor;
    Color labelColor;

    switch (status) {
      case ScheduleStatus.voided:
        textColor = Colors.red.shade100;
        labelColor = Colors.red.shade200.withOpacity(0.8);
        break;
      case ScheduleStatus.late:
        textColor = Colors.orange.shade100;
        labelColor = Colors.orange.shade200.withOpacity(0.8);
        break;
      case ScheduleStatus.upcoming:
      default:
        textColor = Colors.green.shade100; // Lighter green for text in upcoming detail rows
        labelColor = Colors.green.shade200.withOpacity(0.8); // Lighter green for labels
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
