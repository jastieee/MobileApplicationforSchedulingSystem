import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'book_session_page.dart'; // Import the new booking page

// Define the program types as an enum for better type safety and clarity
enum ProgramTypeFilter {
  skin,
  body,
  classType, // Renamed 'class' to 'classType' to avoid keyword conflict
  all, // Added 'all' filter back
}

class BookRemainingSchedulePage extends StatefulWidget {
  const BookRemainingSchedulePage({Key? key}) : super(key: key);

  @override
  _BookRemainingSchedulePageState createState() => _BookRemainingSchedulePageState();
}

class _BookRemainingSchedulePageState extends State<BookRemainingSchedulePage> {
  // State variables to hold fetched data and loading/error status
  List<dynamic>? remainingSchedules; // Original fetched schedules
  List<dynamic>? _filteredSchedules; // Schedules after applying filters
  bool isLoading = true;
  String? errorMessage;
  String? memberId;

  // Variables to store member details fetched from API
  Map<String, dynamic>? memberDetails;
  List<Map<String, dynamic>> availableBranches = [];
  String? firstName;
  String? mi; // Middle Initial
  String? lastName;
  String? suffix;

  // State for the segmented button filter
  Set<ProgramTypeFilter> _selectedProgramFilter = {ProgramTypeFilter.all}; // Changed initial selection to 'all'

  // NEW: State for branch filtering
  String? _selectedBranchFilter; // To hold the selected branch name

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // Orchestrating function to fetch all necessary data
  Future<void> _loadAllData() async {
    setState(() {
      isLoading = true;
      errorMessage = null; // Clear previous errors
    });

    final prefs = await SharedPreferences.getInstance();
    final int? memberIdInt = prefs.getInt('member_id');
    memberId = memberIdInt?.toString() ?? prefs.getString('member_id');

    if (memberId == null || memberId!.isEmpty) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'No member ID found. Please log in again.';
      });
      return;
    }

    try {
      // Step 1: Fetch member details using check_member_type.php
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/check_member_type.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'member_id': memberId}),
      );

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['success'] == true) {
        if (!mounted) return;
        setState(() {
          memberDetails = jsonResponse['member_details'] ?? {};
          firstName = memberDetails!['firstname']?.toString();
          mi = memberDetails!['mi']?.toString();
          lastName = memberDetails!['lastname']?.toString();
          suffix = memberDetails!['suffix']?.toString();

          if (memberDetails!.containsKey('membership_type')) {
            memberDetails!['member_type'] = memberDetails!['membership_type'];
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = jsonResponse['message'] ?? 'Failed to load member details.';
          isLoading = false;
        });
        return;
      }

      // Step 2: Fetch branches (as provided in your previous snippet)
      if (memberDetails != null) {
        await _fetchMemberBranches(memberId!);
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Could not retrieve member details to fetch branches.';
          isLoading = false;
        });
        return;
      }

      // Step 3: Fetch remaining schedules
      await _fetchRemainingSchedules(memberId!);

    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error during data loading: ${e.toString()}';
        isLoading = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // User-provided _fetchMemberBranches function
  Future<void> _fetchMemberBranches(String memberId) async {
    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/member_controller.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'member_id': memberId}),
      );

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['success'] == true) {
        if (!mounted) return;
        setState(() {
          availableBranches = List<Map<String, dynamic>>.from(jsonResponse['branches'] ?? []);
          // NEW: Initialize _selectedBranchFilter to 'All Branches' if available, or null
          if (availableBranches.isNotEmpty) {
            _selectedBranchFilter = 'All Branches';
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = errorMessage ?? 'Error fetching branches: ${jsonResponse['message'] ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = errorMessage ?? 'Network or parsing error for branches: ${e.toString()}';
      });
    }
  }

  // Function to fetch remaining schedules from get_remaining_schedule.php
  Future<void> _fetchRemainingSchedules(String memberId) async {
    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/get_remaining_schedule.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'member_id': memberId}),
      );

      print('Response body from get_remaining_schedule.php: ${response.body}');

      if (response.body.isEmpty) {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Empty response from schedule API. Please check the server.';
        });
        return;
      }

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['success'] == true) {
        if (!mounted) return;
        setState(() {
          remainingSchedules = jsonResponse['remaining_schedules'] ?? [];
          _applyFilters(); // Apply filters immediately after fetching schedules
          errorMessage = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = jsonResponse['message'] ?? 'Failed to load remaining schedules.';
        });
      }
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to parse schedule data: Invalid JSON format. Error: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error fetching remaining schedules: ${e.toString()}';
      });
    }
  }

  // Function to apply filters to the schedules
  void _applyFilters() {
    if (remainingSchedules == null) {
      _filteredSchedules = [];
      return;
    }

    List<dynamic> tempFilteredList = List.from(remainingSchedules!);

    // Apply Program Type Filter
    if (!_selectedProgramFilter.contains(ProgramTypeFilter.all) && _selectedProgramFilter.isNotEmpty) {
      tempFilteredList = tempFilteredList.where((schedule) {
        final program = schedule['program']?.toString().toLowerCase() ?? '';
        bool matchesProgram = false;
        if (_selectedProgramFilter.contains(ProgramTypeFilter.skin) && program.contains('skin')) {
          matchesProgram = true;
        }
        if (_selectedProgramFilter.contains(ProgramTypeFilter.body) && program.contains('body')) {
          matchesProgram = true;
        }
        if (_selectedProgramFilter.contains(ProgramTypeFilter.classType) && program.contains('class')) {
          matchesProgram = true;
        }
        return matchesProgram;
      }).toList();
    }

    // NEW: Apply Branch Filter
    if (_selectedBranchFilter != null && _selectedBranchFilter != 'All Branches') {
      tempFilteredList = tempFilteredList.where((schedule) {
        final branchName = schedule['branch_name']?.toString() ?? '';
        return branchName == _selectedBranchFilter;
      }).toList();
    }

    setState(() {
      _filteredSchedules = tempFilteredList;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF253660),
      appBar: AppBar(
        title: Text(
          "Book Remaining Schedule",
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF253660),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // For back button icon
      ),
      body: SafeArea(
        child: isLoading
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
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "Hello ${firstName ?? 'Member'},\nYour remaining schedules are:",
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            // Segmented Button for Program Filtering
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ProgramTypeFilter>(
                  segments: const <ButtonSegment<ProgramTypeFilter>>[
                    ButtonSegment<ProgramTypeFilter>(
                      value: ProgramTypeFilter.all,
                      label: Text('All'),
                      icon: Icon(Icons.category, size: 12),
                    ),
                    ButtonSegment<ProgramTypeFilter>(
                      value: ProgramTypeFilter.skin,
                      label: Text('Skin'),
                      icon: Icon(Icons.spa, size: 12),
                    ),
                    ButtonSegment<ProgramTypeFilter>(
                      value: ProgramTypeFilter.body,
                      label: Text('Body'),
                      icon: Icon(Icons.fitness_center, size: 12),
                    ),
                    ButtonSegment<ProgramTypeFilter>(
                      value: ProgramTypeFilter.classType,
                      label: Text('Class'),
                      icon: Icon(Icons.people, size: 12),
                    ),
                  ],
                  selected: _selectedProgramFilter,
                  onSelectionChanged: (Set<ProgramTypeFilter> newSelection) {
                    setState(() {
                      if (newSelection.contains(ProgramTypeFilter.all)) {
                        _selectedProgramFilter = {ProgramTypeFilter.all};
                      } else if (newSelection.isNotEmpty) {
                        _selectedProgramFilter = {newSelection.last};
                      } else {
                        _selectedProgramFilter = {};
                      }
                      _applyFilters();
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    backgroundColor: const Color(0xFF394A7F),
                    selectedBackgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white70,
                    selectedForegroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(48),
                    textStyle: GoogleFonts.montserrat(fontSize: 12),
                  ),
                ),
              ),
            ),
            // NEW: Dropdown for Branch Filtering
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF394A7F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedBranchFilter,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white),
                    dropdownColor: const Color(0xFF394A7F),
                    hint: Text(
                      availableBranches.isEmpty ? 'No Branches' : 'Filter by Branch',
                      style: GoogleFonts.montserrat(color: Colors.white70),
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedBranchFilter = newValue;
                        _applyFilters(); // Apply filters when branch changes
                      });
                    },
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'All Branches',
                        child: Text(
                          'All Branches',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      ...availableBranches.map<DropdownMenuItem<String>>((Map<String, dynamic> branch) {
                        return DropdownMenuItem<String>(
                          value: branch['branch_name']!.toString(), // Assuming 'branch_name' key exists
                          child: Text(
                            branch['branch_name']!.toString(),
                            style: GoogleFonts.montserrat(color: Colors.white),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _filteredSchedules == null || _filteredSchedules!.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    "No schedules found for the selected program type or branch.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: _filteredSchedules!.length,
                itemBuilder: (context, index) {
                  final schedule = _filteredSchedules![index];
                  return _buildScheduleCard(schedule);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build a single schedule card
  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    // Extract service_name and branch_name from the schedule map
    final String serviceName = schedule['service_name'] ?? schedule['program'] ?? 'Unknown Program';
    final String branchName = schedule['branch_name'] ?? 'N/A';

    return GestureDetector( // Make the card clickable
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookSessionPage(
              serviceName: serviceName,
              branchName: branchName,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF394A7F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service Name/Program Title
              Text(
                serviceName, // Use the extracted serviceName
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              // Branch Name
              Text(
                "Branch: $branchName", // Use the extracted branchName
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              // Status (if available)
              if (schedule['status'] != null)
                Text(
                  "Status: ${schedule['status']}",
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              // Remaining Sessions
              if (schedule['remaining_sessions'] != null)
                Text(
                  "Remaining Sessions: ${schedule['remaining_sessions']}",
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
