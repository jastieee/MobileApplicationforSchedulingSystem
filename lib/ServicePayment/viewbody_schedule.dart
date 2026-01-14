import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
import 'package:slimmersworld/UserDashboard/welcome_page.dart';
import 'package:webview_flutter/webview_flutter.dart'; // Import webview_flutter
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

// A placeholder for your Welcome Page
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


// The original BranchBodyServicePage
class BranchBodyServicesPage extends StatefulWidget {
  final String branchName;
  final String branchCode; // This is the actual branch code

  const BranchBodyServicesPage({
    Key? key,
    required this.branchName,
    required this.branchCode,
  }) : super(key: key);

  @override
  _BranchBodyServicesPage createState() => _BranchBodyServicesPage();
}

class _BranchBodyServicesPage extends State<BranchBodyServicesPage> {
  String? selectedBranchName;
  String? selectedBranchCode;
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> filteredServices = [];
  bool isLoading = true;
  int? memberId;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedBranchName = widget.branchName;
    selectedBranchCode = widget.branchCode;
    loadMemberIdAndBranchInfo();
    searchController.addListener(_filterServices);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterServices() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredServices = services;
      } else {
        filteredServices = services.where((service) {
          final title = (service['title'] ?? '').toString().toLowerCase();
          return title.contains(query);
        }).toList();
      }
    });
  }

  Future<void> loadMemberIdAndBranchInfo() async {
    final prefs = await SharedPreferences.getInstance();
    memberId = prefs.getInt('member_id');

    // Load branch info from SharedPreferences
    final storedBranchName = prefs.getString('selected_branch_name');
    final storedBranchCode = prefs.getString('branch_code');

    if (storedBranchName != null) {
      selectedBranchName = storedBranchName;
    }
    if (storedBranchCode != null) {
      selectedBranchCode = storedBranchCode;
    }

    if (memberId != null && selectedBranchName != null) {
      await fetchBranchServices();
    } else {
      String errorMessage = '';
      if (memberId == null) {
        errorMessage = 'Member ID not found. Please log in again.';
      } else {
        errorMessage = 'Branch information not found. Please select a branch again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );

      if (selectedBranchName == null) {
        Navigator.pop(context);
      } else {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> fetchBranchServices() async {
    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/body_schedules.php'),
        headers: {'Content-Type': 'application/json'},
        // Use selectedBranchName as branch_code since that's what you need
        body: jsonEncode({'branch_code': selectedBranchName}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          setState(() {
            services = List<Map<String, dynamic>>.from(data['services'] ?? []);
            filteredServices = services;
            isLoading = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to load services')),
          );
          setState(() => isLoading = false);
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading services: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  Widget buildServiceCard(Map<String, dynamic> service) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceDetailPage(
              service: service,
              branchName: selectedBranchName ?? widget.branchName,
              branchCode: selectedBranchCode ?? widget.branchCode, // Pass the branchCode here
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: const Color(0xFF2D4373),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.spa,
                color: Colors.white70,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service['title'] ?? 'Unknown Service',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.currency_exchange,
                          color: Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '₱${service['price'] ?? 'N/A'} per session',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${selectedBranchName ?? widget.branchName} Services'),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        backgroundColor: const Color(0xFF3D5184),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF253660),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : services.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.spa_outlined,
              size: 80,
              color: Colors.white30,
            ),
            const SizedBox(height: 20),
            Text(
              'No Services Available',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are currently no body services\navailable at this branch.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => fetchBranchServices(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E3A67),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: fetchBranchServices,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D4373),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.white70,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedBranchName ?? widget.branchName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Text(
                          //   'Branch Code: ${selectedBranchCode ?? widget.branchCode}',
                          //   style: const TextStyle(
                          //     color: Colors.white70,
                          //     fontSize: 14,
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${filteredServices.length} Services',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2D4373),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search services by title...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white70,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        searchController.clear();
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Available Services',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filteredServices.isEmpty && searchController.text.isNotEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 80,
                        color: Colors.white30,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No services found',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your search terms',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: filteredServices.length,
                  itemBuilder: (context, index) {
                    return buildServiceCard(filteredServices[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The ServiceDetailPage
class ServiceDetailPage extends StatefulWidget {
  final Map<String, dynamic> service;
  final String branchName;
  final String branchCode; // Added branchCode

  const ServiceDetailPage({
    Key? key,
    required this.service,
    required this.branchName,
    required this.branchCode, // Required for the DoctorSelectionPage
  }) : super(key: key);

  @override
  _ServiceDetailPageState createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  String? _selectedSessionType; // 'full' or 'per_session'
  int? _selectedPerSessionCount;
  String? _selectedDay; // New state variable for the selected day
  final TextEditingController _fullSessionController = TextEditingController();
  double? _calculatedTotalPrice; // New state for calculated total price

  // List of days for the new dropdown
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _fullSessionController.text = '5'; // Default for full session display
    _updateCalculatedTotalPrice(); // Initial calculation
  }

  @override
  void dispose() {
    _fullSessionController.dispose();
    super.dispose();
  }

  void _updateCalculatedTotalPrice() {
    setState(() {
      if (_selectedSessionType == null || _selectedPerSessionCount == null) {
        _calculatedTotalPrice = null;
      } else {
        final double pricePerSession = double.tryParse(widget.service['price']?.toString() ?? '0.0') ?? 0.0;
        _calculatedTotalPrice = pricePerSession * _selectedPerSessionCount!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if proceed button should be enabled
    bool isProceedEnabled = _selectedSessionType != null &&
        ((_selectedSessionType == 'full' && _selectedPerSessionCount == 5) ||
            (_selectedSessionType == 'per_session' && _selectedPerSessionCount != null)) &&
        _selectedDay != null; // Must also have a day selected

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Sessions'),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        backgroundColor: const Color(0xFF3D5184),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF253660),
      body: SingleChildScrollView( // Make the body scrollable
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 20),
                color: const Color(0xFF2D4373),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.service['title'] ?? 'Unknown Service',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.currency_exchange,
                            color: Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Price: ₱${widget.service['price'] ?? 'N/A'} per session',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Branch: ${widget.branchName}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Text(
                'Select Session Type:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D4373),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_note, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedSessionType,
                          hint: const Text(
                            'Choose session type',
                            style: TextStyle(color: Colors.white54),
                          ),
                          dropdownColor: const Color(0xFF2D4373),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedSessionType = newValue;
                              if (_selectedSessionType == 'full') {
                                _selectedPerSessionCount = 5;
                              } else {
                                _selectedPerSessionCount = null;
                              }
                              _selectedDay = null; // Reset selected day
                              _updateCalculatedTotalPrice(); // Update total price
                            });
                          },
                          items: <String>['full', 'per_session']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value == 'full' ? 'Full Session (5 Sessions)' : 'Per Session'), // Clarified text
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_selectedSessionType == 'full') ...[
                const Text(
                  'Number of Sessions:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D4373),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.format_list_numbered, color: Colors.white70),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _fullSessionController,
                          readOnly: true,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_selectedSessionType == 'per_session') ...[
                const Text(
                  'Number of Sessions:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D4373),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.format_list_numbered, color: Colors.white70),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: _selectedPerSessionCount,
                            hint: const Text(
                              'Select number of sessions',
                              style: TextStyle(color: Colors.white54),
                            ),
                            dropdownColor: const Color(0xFF2D4373),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            onChanged: (int? newValue) {
                              setState(() {
                                _selectedPerSessionCount = newValue;
                                _selectedDay = null; // Reset selected day
                                _updateCalculatedTotalPrice(); // Update total price
                              });
                            },
                            items: <int>[1, 2, 3, 4]
                                .map<DropdownMenuItem<int>>((int value) {
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text('$value Session${value > 1 ? 's' : ''}'),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // New dropdown for "What day do you prefer?"
              if (_selectedSessionType != null && _selectedPerSessionCount != null) ...[
                const SizedBox(height: 20),
                const Text(
                  'What day do you prefer?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D4373),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white70),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedDay,
                            hint: const Text(
                              'Select a day',
                              style: TextStyle(color: Colors.white54),
                            ),
                            dropdownColor: const Color(0xFF2D4373),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedDay = newValue;
                              });
                            },
                            items: _days
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Display total price here in a Card
              if (_calculatedTotalPrice != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D4373),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Price Summary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Price per session:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '₱${(double.tryParse(widget.service['price']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sessions: ${_selectedPerSessionCount ?? 'N/A'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '₱${_calculatedTotalPrice!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              SizedBox(height: 50), // Wider gap
              Center(
                child: ElevatedButton(
                  onPressed: isProceedEnabled
                      ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorSelectionPage(
                          service: widget.service,
                          sessionType: _selectedSessionType!,
                          sessionCount: _selectedPerSessionCount!, // This is the total number of sessions in the package
                          preferredDay: _selectedDay!,
                          branchCode: widget.branchCode,
                        ),
                      ),
                    );
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5184),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Proceed',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// New DoctorSelectionPage
class DoctorSelectionPage extends StatefulWidget {
  final Map<String, dynamic> service;
  final String sessionType;
  final int sessionCount; // Total original sessions (e.g., 5 for full session, or 1-4 for per_session)
  final String preferredDay;
  final String branchCode;

  const DoctorSelectionPage({
    Key? key,
    required this.service,
    required this.sessionType,
    required this.sessionCount,
    required this.preferredDay,
    required this.branchCode,
  }) : super(key: key);

  @override
  _DoctorSelectionPageState createState() => _DoctorSelectionPageState();
}

class _DoctorSelectionPageState extends State<DoctorSelectionPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _doctors = [];
  Map<String, dynamic>? _selectedDoctor;
  String? _errorMessage;
  int? _scheduledSessionsCount; // New state for sessions to schedule

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
    // If only one session, automatically set and make it read-only
    if (widget.sessionCount == 1) {
      _scheduledSessionsCount = 1;
    }
  }

  Future<void> _fetchDoctors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/fetch_doctors.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'branch_code': widget.branchCode,
          'selected_day': widget.preferredDay.toLowerCase(), // Ensure day is lowercase for PHP
          'position': 'Doctor', // Explicitly request only Doctors
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          setState(() {
            // Filter to only include 'Doctor' position from the fetched data
            _doctors = List<Map<String, dynamic>>.from(data['facilitators'] ?? [])
                .where((f) => f['facilitator_position'] == 'Doctor')
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to load doctors.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching doctors: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isConfirmBookingEnabled = _selectedDoctor != null && _scheduledSessionsCount != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Doctor'),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        backgroundColor: const Color(0xFF3D5184),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF253660),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.withOpacity(0.7),
              ),
              const SizedBox(height: 20),
              Text(
                'Error: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchDoctors,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E3A67),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      )
          : _doctors.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 80,
                color: Colors.white30,
              ),
              const SizedBox(height: 20),
              Text(
                'No Doctors Available for ${widget.preferredDay}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please try a different day or branch.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchDoctors,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E3A67),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Refresh',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox( // Added SizedBox to explicitly make the card take full width
              width: double.infinity,
              child: Card(
                margin: const EdgeInsets.only(bottom: 20),
                color: const Color(0xFF2D4373),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service: ${widget.service['title']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sessions: ${widget.sessionCount} (${widget.sessionType == 'full' ? 'Full Session' : 'Per Session'})',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Preferred Day: ${widget.preferredDay}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Text(
              'Select Doctor:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2D4373),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white70),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        isExpanded: true,
                        value: _selectedDoctor,
                        hint: const Text(
                          'Choose a doctor',
                          style: TextStyle(color: Colors.white54),
                        ),
                        dropdownColor: const Color(0xFF2D4373),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        onChanged: (Map<String, dynamic>? newValue) {
                          setState(() {
                            _selectedDoctor = newValue;
                          });
                        },
                        items: _doctors
                            .map<DropdownMenuItem<Map<String, dynamic>>>((Map<String, dynamic> doctor) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: doctor,
                            child: Text(doctor['facilitator_name'] ?? 'Unknown Doctor'),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // New section for scheduling sessions
            const Text(
              'How many sessions do you want to schedule?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2D4373),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.numbers, color: Colors.white70),
                  const SizedBox(width: 12),
                  Expanded(
                    child: widget.sessionCount == 1
                        ? TextField(
                      controller: TextEditingController(text: '1 Session'),
                      readOnly: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(border: InputBorder.none),
                    )
                        : DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _scheduledSessionsCount,
                        hint: const Text(
                          'Select number of sessions',
                          style: TextStyle(color: Colors.white54),
                        ),
                        dropdownColor: const Color(0xFF2D4373),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        onChanged: (int? newValue) {
                          setState(() {
                            _scheduledSessionsCount = newValue;
                          });
                        },
                        items: List.generate(widget.sessionCount, (index) => index + 1)
                            .map<DropdownMenuItem<int>>((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value Session${value > 1 ? 's' : ''}'),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: isConfirmBookingEnabled
                    ? () {
                  // Navigate to DateSelectionPage
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DateSelectionPage(
                        service: widget.service,
                        sessionType: widget.sessionType,
                        sessionCount: widget.sessionCount, // Total original sessions
                        preferredDay: widget.preferredDay,
                        branchCode: widget.branchCode,
                        selectedDoctor: _selectedDoctor!,
                        scheduledSessionsCount: _scheduledSessionsCount!, // Sessions to schedule
                      ),
                    ),
                  );
                }
                    : null, // Disable button until doctor and scheduled sessions are selected
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D5184),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Confirm Booking',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// New DateSelectionPage
class DateSelectionPage extends StatefulWidget {
  final Map<String, dynamic> service;
  final String sessionType;
  final int sessionCount; // Total original sessions (e.g., 5 for full session, or 1-4 for per_session)
  final String preferredDay;
  final String branchCode;
  final Map<String, dynamic> selectedDoctor;
  final int scheduledSessionsCount; // Number of sessions user wants to schedule now

  const DateSelectionPage({
    Key? key,
    required this.service,
    required this.sessionType,
    required this.sessionCount,
    required this.preferredDay,
    required this.branchCode,
    required this.selectedDoctor,
    required this.scheduledSessionsCount,
  }) : super(key: key);

  @override
  _DateSelectionPageState createState() => _DateSelectionPageState();
}

class _DateSelectionPageState extends State<DateSelectionPage> {
  // Store selected dates with their selected times
  final Map<DateTime, String> _selectedDatesWithTimes = {};
  Map<String, dynamic>? memberData;
  bool isLoadingMember = false;

  @override
  void initState() {
    super.initState();
    _generateAndFilterDates();
    fetchMemberData(); // Fetch member data when the page initializes
  }

  // Fetches member data from API
  Future<void> fetchMemberData() async {
    setState(() {
      isLoadingMember = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final memberId = prefs.getInt('member_id');
      final savedUsername = prefs.getString('username'); // Get the saved username

      if (memberId == null) {
        if (mounted) { // Check if the widget is still in the tree
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member ID not found. Please log in again.')),
          );
        }
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
              memberData!['username'] = savedUsername; // Ensure username is in memberData
            }
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
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => isLoadingMember = false);
      }
    }
  }

  List<DateTime> _availableDates = [];

  void _generateAndFilterDates() {
    final now = DateTime.now();
    final currentYear = now.year;
    final List<DateTime> allDatesInYear = [];

    // Map day string to DateTime.weekday integer
    // Monday is 1, Sunday is 7
    int targetWeekday;
    switch (widget.preferredDay.toLowerCase()) {
      case 'monday':
        targetWeekday = DateTime.monday;
        break;
      case 'tuesday':
        targetWeekday = DateTime.tuesday;
        break;
      case 'wednesday':
        targetWeekday = DateTime.wednesday;
        break;
      case 'thursday':
        targetWeekday = DateTime.thursday;
        break;
      case 'friday':
        targetWeekday = DateTime.friday;
        break;
      case 'saturday':
        targetWeekday = DateTime.saturday;
        break;
      case 'sunday':
        targetWeekday = DateTime.sunday;
        break;
      default:
        targetWeekday = -1; // Invalid day
    }

    if (targetWeekday == -1) {
      // Handle invalid day, maybe show an error
      return;
    }

    // Generate dates for the current year
    for (int month = 1; month <= 12; month++) {
      for (int day = 1; day <= 31; day++) {
        try {
          final date = DateTime(currentYear, month, day);
          // Only add valid dates and future/present dates on the preferred day
          if (date.month == month && date.isAfter(now.subtract(Duration(days: 1)).subtract(Duration(hours: now.hour, minutes: now.minute, seconds: now.second))) && date.weekday == targetWeekday) {
            allDatesInYear.add(date);
          }
        } catch (e) {
          // Date is not valid (e.g., Feb 30)
          continue;
        }
      }
    }

    setState(() {
      _availableDates = allDatesInYear;
      // Sort dates to ensure chronological order
      _availableDates.sort((a, b) => a.compareTo(b));
    });
  }

  // Function to show time selection popup
  Future<void> _showTimePickerForDate(BuildContext context, DateTime date) async {
    List<String> availableTimes = _generateTimeSlots(date);

    String? selectedTime;

    await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D4373),
          title: Text(
            'Select Time for ${DateFormat('MMMM d, y').format(date)}',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableTimes.length,
              itemBuilder: (context, index) {
                final time = availableTimes[index];
                return ListTile(
                  title: Text(time, style: const TextStyle(color: Colors.white70)),
                  onTap: () {
                    selectedTime = time;
                    Navigator.of(dialogContext).pop(selectedTime);
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    ).then((time) {
      if (time != null) {
        setState(() {
          // Remove if already exists (for re-selection)
          _selectedDatesWithTimes.remove(date);
          // Add the new selection
          _selectedDatesWithTimes[date] = time;

          // If single session, ensure only one is selected
          if (widget.scheduledSessionsCount == 1) {
            final entry = _selectedDatesWithTimes.entries.firstWhere((e) => e.key == date, orElse: () => MapEntry(date, time));
            _selectedDatesWithTimes.clear();
            _selectedDatesWithTimes[entry.key] = entry.value;
            // For single session, immediately show summary after selecting time
            showSummaryDialog(_selectedDatesWithTimes);
          } else if (_selectedDatesWithTimes.length > widget.scheduledSessionsCount) {
            // If user somehow manages to select more, remove the oldest one
            // This scenario should be prevented by the checkbox logic itself.
            // For now, if it happens, remove the first added.
            if (_selectedDatesWithTimes.length > widget.scheduledSessionsCount) {
              final oldestKey = _selectedDatesWithTimes.keys.first;
              _selectedDatesWithTimes.remove(oldestKey);
            }
          }
        });
      }
    });
  }

  // Generate time slots (9:00 AM to 5:00 PM, 30 min duration + 10 min grace = 40 min interval)
  // Generate time slots (9:00 AM to 5:00 PM, 40 min duration)
  List<String> _generateTimeSlots(DateTime date) {
    List<String> times = [];
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    for (int hour = 9; hour <= 17; hour++) { // 9 AM to 5 PM
      for (int minute = 0; minute < 60; minute += 40) { // 40-minute interval
        final DateTime slotStartDateTime = DateTime(date.year, date.month, date.day, hour, minute);
        final DateTime slotEndDateTime = slotStartDateTime.add(const Duration(minutes: 40)); // End time is 40 minutes after start

        // Only add future time slots if it's today
        if (!isToday || slotStartDateTime.isAfter(now)) {
          final TimeOfDay startTimeOfDay = TimeOfDay.fromDateTime(slotStartDateTime);
          final TimeOfDay endTimeOfDay = TimeOfDay.fromDateTime(slotEndDateTime);
          times.add('${startTimeOfDay.format(context)} - ${endTimeOfDay.format(context)}');
        }
      }
    }
    return times;
  }

  // Helper function for summary dialog
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

  // Helper function to get branch name (for summary dialog)
  Future<String?> _getBranchName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_branch_name');
  }

  // NEW _initiatePayMongoPayment function
  Future<void> _initiatePayMongoPayment(Map<DateTime, String> selectedDatesTimesMap) async {
    if (memberData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member data not loaded. Cannot initiate payment.')),
        );
      }
      return;
    }

    // Combine all service details into a single string for metadata
    String serviceDetails = selectedDatesTimesMap.entries.map((entry) =>
    '${widget.service['title']} on ${DateFormat('MMMM d, y (EEEE)').format(entry.key)} at ${entry.value} with ${widget.selectedDoctor['facilitator_name']}'
    ).join('; ');

    // Extract member information
    final String fullName = '${memberData!['firstname'] ?? ''} ${memberData!['mi'] ?? ''} ${memberData!['lastname'] ?? ''} ${memberData!['suffix'] ?? ''}'.trim();
    final String userName = memberData!['username'] ?? memberData!['membership_code'] ?? 'unknown_user';

    // Calculate total price for the summary based on total sessions in the package
    final double pricePerSession = double.tryParse(widget.service['price']?.toString() ?? '0.0') ?? 0.0;
    final double totalPrice = pricePerSession * widget.sessionCount; // Use widget.sessionCount here


    // Show loading dialog *before* initiating PayMongo request
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
    );

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/create_payment_flutter.php'), // Your PHP endpoint
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded', // Corrected header for $_POST
        },
        body: {
          'amount': totalPrice.toStringAsFixed(2), // Ensure amount is string with 2 decimal places
          'name': fullName,
          'user_name': userName,
          'service_details': serviceDetails,
        }.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&'),
      );

      // Dismiss the initial loading indicator after getting PHP response
      if (mounted) {
        Navigator.of(context).pop();
      }

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
              programTitle: widget.service['title'] ?? 'Unknown Service', // Use service title
              selectedDatesWithTimes: selectedDatesTimesMap, // Pass the map directly
              memberData: memberData!,
              doctorId: widget.selectedDoctor['facilitator_id'] ?? 0,
              doctorName: widget.selectedDoctor['facilitator_name'] ?? 'Unknown Doctor',
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
            if (mounted) {
              _showPaymentWaitingDialog(); // Implement this new function
            }

            try {
              // Pass totalPrice (the package price) as paymentAmount to the registration function
              await _processPaymentAndRegisterSessions(selectedDatesTimesMap, finalReferenceId, totalPrice);
              // Dismiss waiting dialog if registration is successful
              if (mounted) {
                Navigator.of(context).pop(); // Dismiss _showPaymentWaitingDialog
              }

              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF2D4373),
                    title: const Text('Payment Successful!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    content: Text('Your payment for ${widget.service['title']} was successful. Reference ID: ${finalReferenceId ?? 'N/A'}. Sessions have been registered.', style: const TextStyle(color: Colors.white70)),
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
              }
            } catch (e) {
              // Dismiss waiting dialog if registration fails
              if (mounted) {
                Navigator.of(context).pop(); // Dismiss _showPaymentWaitingDialog
              }

              // If class registration fails AFTER payment success
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF2D4373),
                    title: const Text('Registration Failed!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    content: Text('Payment was successful (Ref ID: ${finalReferenceId ?? 'N/A'}), but there was an error registering your sessions. Please contact support. Error: $e', style: const TextStyle(color: Colors.white70)),
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
            }
          } else {
            // Payment failed or cancelled
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF2D4373),
                  title: const Text('Payment Failed or Cancelled', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: Text('There was an issue with your payment for ${widget.service['title']}. Please try again. Reference ID: ${finalReferenceId ?? 'N/A'}. ${errorMessage != null ? 'Error: $errorMessage' : ''}', style: const TextStyle(color: Colors.white70)),
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
          }
        } else {
          // This case handles if `Navigator.pop` returns null (e.g., if user used back button without explicit pop with result)
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF2D4373),
                title: const Text('Payment Process Interrupted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        }
      } else {
        // Error getting checkout URL from your PHP script
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? 'Failed to get PayMongo checkout URL')),
          );
        }
      }
    } catch (e) {
      // Catch any network or other unexpected errors during the initial http.post or webview push
      if (mounted) { // Check if the widget is still in the tree
        Navigator.of(context).pop(); // Dismiss loading indicator if it's still open
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initiating payment: $e')),
        );
      }
    }
  }

  // NEW _showPaymentWaitingDialog function
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
              'Payment successful, registering...',
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

// NEW _processPaymentAndRegisterSessions function
  Future<void> _processPaymentAndRegisterSessions(Map<DateTime, String> selectedDatesTimes, String? finalReferenceId, double paymentAmount) async {
    final prefs = await SharedPreferences.getInstance();
    final branchName = prefs.getString('selected_branch_name') ?? 'default';
    final tableName = '${branchName.replaceAll(' ', '_')}_logs';

    // These variables are used for both the summary and individual log entries
    final double pricePerSession = double.tryParse(widget.service['price']?.toString() ?? '0.0') ?? 0.0;
    final double totalPriceOfPackage = pricePerSession * widget.sessionCount; // Total price of the full package
    final double balanceDue = totalPriceOfPackage - paymentAmount;

    final int totalSessionsPurchased = widget.sessionCount; // Total sessions customer bought (e.g., 5-session package)
    final int scheduledSessionsCount = selectedDatesTimes.length; // How many sessions are being scheduled *now*

    try {
      // --- 1. FIRST API CALL: Insert into members_services table (SUMMARY ROW) ---
      // This call sends data for the overall purchase/transaction, not individual dates.
      final Map<String, dynamic> serviceSummaryData = {
        'nfc_uid': _sanitizeString(memberData?['nfc_uid']),
        'firstname': _sanitizeString(memberData?['firstname']),
        'mi': _sanitizeString(memberData?['mi']),
        'lastname': _sanitizeString(memberData?['lastname']),
        'suffix': _sanitizeString(memberData?['suffix']),
        'branch_code': _sanitizeString(prefs.getString('branch_code')),
        'membership_code': _sanitizeString(memberData?['membership_code']),
        'membership_type': _sanitizeString(memberData?['membership_type']),
        'program': 'body',
        'services': _sanitizeString(widget.service['title']),
        'price': totalPriceOfPackage.toStringAsFixed(2), // Total price of the package
        'payment': paymentAmount.toStringAsFixed(2), // Actual amount paid
        'balance_due': balanceDue.toStringAsFixed(2), // Balance due
        'sessions': totalSessionsPurchased.toString(),
        'track_sessions': scheduledSessionsCount.toString(),
      };

      print('Sending summary data to record_member_service.php: ${jsonEncode(serviceSummaryData)}');

      final serviceResponse = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/record_member_service.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8', // Reverting to JSON
        },
        body: jsonEncode(serviceSummaryData), // Reverting to JSON encoding
      );

      print('Response status from record_member_service.php: ${serviceResponse.statusCode}');
      print('Response body from record_member_service.php: ${serviceResponse.body}');

      final serviceResult = jsonDecode(serviceResponse.body);
      if (serviceResponse.statusCode != 200 || serviceResult['success'] != true) {
        throw Exception('Failed to record member service summary: ${serviceResult['message'] ?? 'Unknown error'}');
      }

      // --- NEW API CALL: Insert into servicesTrn_logs table (Transaction details) ---
      final Map<String, dynamic> serviceTrnData = {
        'nfc_uid': _sanitizeString(memberData?['nfc_uid']),
        'firstname': _sanitizeString(memberData?['firstname']),
        'mi': _sanitizeString(memberData?['mi']),
        'lastname': _sanitizeString(memberData?['lastname']),
        'suffix': _sanitizeString(memberData?['suffix']),
        'branch_code': _sanitizeString(prefs.getString('branch_code')),
        'membership_code': _sanitizeString(memberData?['membership_code']),
        'membership_type': _sanitizeString(memberData?['membership_type']),
        'program': 'body',
        'services': _sanitizeString(widget.service['title']),
        'price': totalPriceOfPackage.toStringAsFixed(2), // Total price of the package
        'payment': paymentAmount.toStringAsFixed(2), // Actual amount paid
        'sessions': totalSessionsPurchased.toString(),
        'payment_method': 'PayMongo',
        'recorded_by': 'Online Registration',
        'reference_id': _sanitizeString(finalReferenceId),
        'balance_due': balanceDue.toStringAsFixed(2), // Balance due
      };

      print('Sending transaction data to record_service_transaction.php: ${jsonEncode(serviceTrnData)}');
      final trnResponse = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/record_service_transaction.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8', // Reverting to JSON
        },
        body: jsonEncode(serviceTrnData), // Reverting to JSON encoding
      );

      print('Response status from record_service_transaction.php: ${trnResponse.statusCode}');
      print('Response body from record_service_transaction.php: ${trnResponse.body}');

      final trnResult = jsonDecode(trnResponse.body);
      if (trnResponse.statusCode != 200 || trnResult['success'] != true) {
        throw Exception('Failed to record service transaction: ${trnResult['message'] ?? 'Unknown error'}');
      }


      // --- 2. SECOND API CALLS (Loop): Insert into branch-specific log table (INDIVIDUAL ENTRIES) ---
      // This loop runs ONLY if the summary insertion AND transaction insertion were successful.
      for (var entry in selectedDatesTimes.entries) {
        final date = entry.key;
        final time = entry.value;
        final scheduledTime = '${DateFormat('EEEE, MMM dd, y').format(date)} at $time';

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
          'services': _sanitizeString(widget.service['title']),
          'scheduled_time': _sanitizeString(scheduledTime),
          'program': 'body',
          'branch_code': _sanitizeString(prefs.getString('branch_code')),
          'instructor_id': (widget.selectedDoctor['facilitator_id'] ?? 0).toString(),
          'instructor_name': _sanitizeString(widget.selectedDoctor['facilitator_name']),
        };

        print('Sending log data to scheduled_appointment.php for date: $scheduledTime');
        final logResponse = await http.post(
          Uri.parse('https://membership.ndasphilsinc.com/scheduled_appointment.php'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8', // Reverting to JSON
          },
          body: jsonEncode(logData), // Reverting to JSON encoding
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
      // rethrow;
    }
  }

  // Helper function to sanitize strings
  String _sanitizeString(String? input) {
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
            final double pricePerSession = double.tryParse(widget.service['price']?.toString() ?? '0.0') ?? 0.0;
            final double totalPrice = pricePerSession * widget.sessionCount; // Use widget.sessionCount here

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
                  mainAxisSize: MainAxisSize.min,
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

                    // Class Information
                    const Text(
                      'Service Details:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Service:', widget.service['title'] ?? 'N/A'),
                    _buildInfoRow('Doctor:', widget.selectedDoctor['facilitator_name'] ?? 'N/A'), // Display doctor name

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
                    ...selectedDatesTimesMap.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• ${dateFormatter.format(entry.key)} (${dayFormatter.format(entry.key)}) at ${entry.value}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )).toList(),

                    const Divider(color: Colors.white30),

                    // Payment Information
                    const Text(
                      'Booking Details:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Session Type:', widget.sessionType),
                    _buildInfoRow('Number of Sessions:', '${widget.sessionCount}'),
                    _buildInfoRow('Sessions to Schedule:', '${selectedDatesTimesMap.length}'),
                    _buildInfoRow('Total Amount:', '₱${totalPrice.toStringAsFixed(2)}'),

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
                    _initiatePayMongoPayment(selectedDatesTimesMap); // Initiate payment
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
    bool isConfirmDatesEnabled = _selectedDatesWithTimes.length == widget.scheduledSessionsCount;
    int remainingSessionsToSelect = widget.scheduledSessionsCount - _selectedDatesWithTimes.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Dates'),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        backgroundColor: const Color(0xFF3D5184),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF253660),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Updated header label within a Card
            Card(
              margin: const EdgeInsets.only(bottom: 20),
              color: const Color(0xFF2D4373),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select ${widget.scheduledSessionsCount} dates (${_selectedDatesWithTimes.length}/${widget.scheduledSessionsCount} selected)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _availableDates.isEmpty
                ? Center(
              child: Text(
                'No available ${widget.preferredDay}s for this year from today.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            )
                : Expanded(
              child: ListView.builder(
                itemCount: _availableDates.length,
                itemBuilder: (context, index) {
                  final date = _availableDates[index];
                  final isSelected = _selectedDatesWithTimes.containsKey(date);
                  final DateFormat formatter = DateFormat('MMMM d, y (EEEE)');

                  return Card(
                    color: isSelected
                        ? const Color(0xFF4CAF50) // Selected color (green)
                        : const Color(0xFF2D4373), // Default color
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: widget.scheduledSessionsCount == 1
                        ? InkWell( // Use InkWell for single selection without checkbox
                      onTap: () async {
                        await _showTimePickerForDate(context, date);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                formatter.format(date),
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                            Text(
                              'Doctor: ${widget.selectedDoctor['facilitator_name']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                          ],
                        ),
                      ),
                    )
                        : CheckboxListTile( // Keep CheckboxListTile for multiple selections
                      controlAffinity: ListTileControlAffinity.leading, // Checkbox on the left
                      title: Text(
                        formatter.format(date),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            'Doctor: ${widget.selectedDoctor['facilitator_name']}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const Spacer(),
                          const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                        ],
                      ),
                      value: isSelected,
                      onChanged: (bool? value) async {
                        if (value == true) {
                          if (_selectedDatesWithTimes.length < widget.scheduledSessionsCount) {
                            await _showTimePickerForDate(context, date);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('You can only select ${widget.scheduledSessionsCount} sessions.')),
                            );
                          }
                        } else {
                          setState(() {
                            _selectedDatesWithTimes.remove(date);
                          });
                        }
                      },
                      activeColor: const Color(0xFF5A8DCC),
                      checkColor: Colors.white,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // Conditionally display the button for multiple sessions only
            if (widget.scheduledSessionsCount > 1)
              Center(
                child: ElevatedButton(
                  onPressed: isConfirmDatesEnabled
                      ? () {
                    showSummaryDialog(_selectedDatesWithTimes);
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5184),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isConfirmDatesEnabled
                        ? 'Confirm Dates'
                        : 'Select ${remainingSessionsToSelect} more date${remainingSessionsToSelect > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// PayMongoWebViewPage class (integrated)
class PayMongoWebViewPage extends StatefulWidget {
  final String checkoutUrl;
  final String referenceId;
  final String programTitle;
  final Map<DateTime, String> selectedDatesWithTimes; // Updated to Map
  final Map<String, dynamic> memberData;
  final int doctorId; // Changed from instructorId to doctorId for clarity with previous context
  final String doctorName; // Changed from instructorName to doctorName for clarity with previous context

  const PayMongoWebViewPage({
    Key? key,
    required this.checkoutUrl,
    required this.referenceId,
    required this.programTitle,
    required this.selectedDatesWithTimes, // Updated parameter
    required this.memberData,
    required this.doctorId, // Initialize
    required this.doctorName, // Initialize
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
              if (mounted) {
                setState(() {
                  _isLoadingPage = false;
                });
              }
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoadingPage = true;
              });
            }
            print('Page started loading: $url');
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoadingPage = false;
              });
            }
            print('Page finished loading: $url');

            // Check for various success/failure indicators from the original URLs
            if (_isPaymentSuccessUrl(url)) {
              print('Payment success detected!');
              if (mounted) {
                Navigator.pop(context, {'success': true, 'referenceId': _extractRefIdFromSuccessUrl(url)});
              }
            } else if (_isPaymentFailedUrl(url)) {
              print('Payment failed/cancelled detected!');
              if (mounted) {
                Navigator.pop(context, {'success': false, 'referenceId': widget.referenceId});
              }
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
              if (mounted) {
                Navigator.pop(context, {'success': false, 'referenceId': widget.referenceId, 'error': error.description});
              }
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
