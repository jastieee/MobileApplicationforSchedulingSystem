import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class MemberDetailsPage extends StatefulWidget {
  const MemberDetailsPage({Key? key}) : super(key: key);

  @override
  _MemberDetailsPageState createState() => _MemberDetailsPageState();
}

class _MemberDetailsPageState extends State<MemberDetailsPage> {
  Map<String, dynamic>? memberDetails;
  String? photoUrl;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMemberDetailsAutomatically();
  }

  Future<void> _fetchMemberDetailsAutomatically() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      memberDetails = null;
      photoUrl = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final int? memberIdInt = prefs.getInt('member_id');
      String? memberId = memberIdInt?.toString() ?? prefs.getString('member_id');

      if (memberId == null || memberId.isEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
            errorMessage = 'Member ID not found. Please ensure you are logged in.';
          });
        }
        return;
      }

      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/check_member_type.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'member_id': memberId,
        }),
      );

      print('Response from check_member_type.php: ${response.body}');

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['success'] == true) {
        if (mounted) {
          setState(() {
            memberDetails = jsonResponse['member_details'] ?? {};
            final photoPath = memberDetails!['photo_url'] as String?;
            photoUrl = photoPath != null && photoPath.isNotEmpty
                ? 'https://membership.ndasphilsinc.com/$photoPath'
                : null;
            isLoading = false;
            errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = jsonResponse['message'] ?? 'Failed to load member details.';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error fetching member details: $e';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF253660),
      appBar: AppBar(
        backgroundColor: const Color(0xFF253660),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your Profile Details',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : errorMessage != null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Member Details Display Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF394A7F),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member Details',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Member Photo
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                        child: photoUrl == null
                            ? const Icon(Icons.person, size: 40, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Basic Member Information
                    _buildDetailRow('ID', memberDetails!['id']?.toString() ?? 'N/A'), // Changed key from member_id to id
                    _buildDetailRow('Full Name', _formatFullName(
                      memberDetails!['firstname'],
                      memberDetails!['mi'],
                      memberDetails!['lastname'],
                      memberDetails!['suffix'],
                    )),
                    _buildDetailRow('Email', memberDetails!['email']?.toString() ?? 'N/A'),
                    _buildDetailRow('Phone', memberDetails!['contact_number']?.toString() ?? 'N/A'), // Changed to contact_number based on previous PHP
                    _buildDetailRow('Membership Code', memberDetails!['membership_code']?.toString() ?? 'N/A'),
                    _buildDetailRow('Membership Type', memberDetails!['membership_type']?.toString() ?? 'N/A'),
                    _buildDetailRow('Date Registered', memberDetails!['date_registered']?.toString() ?? 'N/A'), // Changed label and key

                    // Dynamically display all other fields from memberDetails
                    ...memberDetails!.entries
                        .where((entry) => ![
                      'id', // Changed from member_id
                      'fullname', // 'fullname' is typically derived or combined
                      'firstname', 'mi', 'lastname', 'suffix', // Handled by _formatFullName
                      'email',
                      'phone', // Changed to contact_number
                      'contact_number', // Exclude both phone and contact_number to avoid duplication
                      'membership_code',
                      'membership_type',
                      'status',
                      'date_registered', // Changed from registration_date
                      'photo_url',
                    ].contains(entry.key))
                        .map((entry) => _buildDetailRow(
                      _formatFieldName(entry.key),
                      entry.value?.toString() ?? 'N/A',
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130, // Adjusted width for better alignment
            child: Text(
              '$label:',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFCED4F1),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFieldName(String fieldName) {
    return fieldName
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatFullName(String? firstName, String? mi, String? lastName, String? suffix) {
    String fullName = '';
    if (firstName != null && firstName.isNotEmpty) fullName += firstName;
    if (mi != null && mi.isNotEmpty) fullName += ' $mi';
    if (lastName != null && lastName.isNotEmpty) fullName += ' $lastName';
    if (suffix != null && suffix.isNotEmpty) fullName += ' $suffix';
    return fullName.trim().isEmpty ? 'N/A' : fullName.trim();
  }
}
