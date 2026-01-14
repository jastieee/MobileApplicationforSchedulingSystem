import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slimmersworld/ServicePayment/viewbody_schedule.dart';
import '../ServicePayment/view_schedule.dart';
import '../ServicePayment/viewskin_schedule.dart';

class BranchBodySelectionPage extends StatefulWidget {
  const BranchBodySelectionPage({Key? key}) : super(key: key);

  @override
  _BranchBodySelectionPageState createState() => _BranchBodySelectionPageState();
}

class _BranchBodySelectionPageState extends State<BranchBodySelectionPage> {
  String? selectedBranch;
  String? selectedBranchCode;
  List<Map<String, dynamic>> branches = [];
  int? memberId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMemberId();
  }

  Future<void> loadMemberId() async {
    final prefs = await SharedPreferences.getInstance();
    memberId = prefs.getInt('member_id');
    if (memberId != null) {
      await fetchBranches();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member ID not found. Please log in again.')),
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchBranches() async {
    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/member_controller.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'member_id': memberId}),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        setState(() {
          branches = List<Map<String, dynamic>>.from(data['branches']);
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to load branches')),
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

  Future<void> saveBranchToPrefs(String branchName, String branchCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_branch_name', branchName);
    await prefs.setString('branch_code', branchCode);
  }

  Future<void> navigateToSchedule() async {
    if (selectedBranch == null || selectedBranchCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a branch first')),
      );
      return;
    }

    // Save branch info to SharedPreferences
    await saveBranchToPrefs(selectedBranch!, selectedBranchCode!);

    // Navigate to services page instead of schedule page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BranchBodyServicesPage(
          branchName: selectedBranch!,
          branchCode: selectedBranchCode!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Branch'),
        titleTextStyle:  TextStyle(color: Colors.white,  fontSize: 18),
        backgroundColor: const Color(0xFF3D5184),
      ),
      backgroundColor: const Color(0xFF253660),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_on,
              size: 80,
              color: Colors.white70,
            ),
            const SizedBox(height: 30),
            const Text(
              'Select Your Branch',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Choose the branch where you want to view skin services',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            DropdownButtonFormField<String>(
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
                  Icons.business,
                  color: Colors.white70,
                ),
              ),
              dropdownColor: const Color(0xFF2D4373),
              style: const TextStyle(color: Colors.white),
              iconEnabledColor: Colors.white,
              value: selectedBranch,
              hint: const Text(
                'Choose a branch',
                style: TextStyle(color: Colors.white70),
              ),
              items: branches.map((branch) {
                return DropdownMenuItem<String>(
                  value: branch['branch_name'],
                  child: Text(
                    branch['branch_name'],
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedBranch = value;
                  selectedBranchCode = branches.firstWhere(
                        (branch) => branch['branch_name'] == value,
                    orElse: () => {},
                  )['branch_code'];
                });

                // ✅ Show toast with selected name and code
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Selected Branch: $selectedBranch (Code: $selectedBranchCode)',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },

            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: navigateToSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedBranch != null
                      ? const Color(0xFF2E3A67)
                      : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'View Schedule',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}