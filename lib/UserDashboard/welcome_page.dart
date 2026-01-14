import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slimmersworld/BranchSelection/branchselection_page.dart';
import 'package:slimmersworld/BranchSelection/branchskin_selection.dart';
import '../HistoryAndRemaining/book_remaining_schedule.dart';
import '../ServicePayment/view_schedule.dart';
import 'profile_page.dart';
import '../BranchSelection/branchbody_selection.dart';
import '../HistoryAndRemaining/view_activity.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  Map<String, dynamic>? memberDetails;
  bool isLoading = true;
  String? errorMessage;
  String? firstNameFromPrefs;
  bool isMembershipExpired = false;

  Future<void> _loadAndFetchMemberData() async {
    final prefs = await SharedPreferences.getInstance();
    final int? memberIdInt = prefs.getInt('member_id');
    String? memberId = memberIdInt?.toString() ?? prefs.getString('member_id');

    firstNameFromPrefs =
        prefs.getString('fullname')?.split(' ').first ?? 'Member';

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
        if (!mounted) return;
        setState(() {
          memberDetails = jsonResponse['member_details'] ?? {};
          // Check if membership is expired
          isMembershipExpired = memberDetails!['is_expired'] ?? false;
          isLoading = false;
          errorMessage = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage =
              jsonResponse['message'] ?? 'Failed to load member details.';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAndFetchMemberData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF253660),
      body: SafeArea(
        child: Stack(
          children: [
            // Main dashboard content (will be blurred if expired)
            LayoutBuilder(
              builder: (context, constraints) {
                return isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                    ? Center(
                    child: Text(errorMessage!,
                        style: const TextStyle(color: Colors.red)))
                    : _buildDashboardContent(constraints);
              },
            ),

            // Expired membership overlay with blur effect
            if (!isLoading && isMembershipExpired)
              _buildExpiredOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hello,",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFD3D7E0),
                    ),
                  ),
                  Text(
                    firstNameFromPrefs ?? 'Member',
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD3D7E0),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF394A7F),
                  backgroundImage: memberDetails!['photo_url'] != null &&
                      (memberDetails!['photo_url'] as String).isNotEmpty
                      ? NetworkImage(
                      'https://membership.ndasphilsinc.com/${memberDetails!['photo_url']}')
                      : null,
                  child: memberDetails!['photo_url'] == null ||
                      (memberDetails!['photo_url'] as String).isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 30)
                      : null,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _dashboardItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _buildGradientCard(
                      icon: item['icon'],
                      title: item['title'],
                      subtitle: item['subtitle'],
                      onTap: item['onTap'],
                      cardWidth: constraints.maxWidth - 32,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpiredOverlay(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Warning Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withOpacity(0.2),
                    border: Border.all(color: Colors.orange, width: 3),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 80,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 40),

                // Main Message
                Text(
                  "PLEASE RENEW YOUR",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "MEMBERSHIP",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Description
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "Your membership has expired. Renew now to continue enjoying our exclusive services and benefits.",
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: const Color(0xFFD3D7E0),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 50),

                // Renew Button
                GestureDetector(
                  onTap: () {
                    // Navigate to renewal page or contact support
                    // TODO: Add your renewal page navigation here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please contact our branch to renew your membership.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF9800),
                          Color(0xFFFF6F00),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
                          offset: const Offset(0, 8),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Renew Membership',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Contact Support Button
                TextButton(
                  onPressed: () {
                    // TODO: Add contact support navigation or action
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please contact us at your nearest branch for assistance.'),
                        backgroundColor: Color(0xFF3D5184),
                      ),
                    );
                  },
                  child: Text(
                    'Contact Support',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFD3D7E0),
                      decoration: TextDecoration.underline,
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

  final List<Map<String, dynamic>> _dashboardItems = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dashboardItems.clear();
    _dashboardItems.addAll([
      {
        'icon': Icons.fitness_center,
        'title': "Sculpt & Sweat",
        'subtitle': "Jump into Zumba or a power workout – tap to book now!",
        'onTap': () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BranchSelectionPage()));
        },
      },
      {
        'icon': Icons.spa,
        'title': "Glow & Revive",
        'subtitle': "Your glow-up starts here – reserve your skin treatment.",
        'onTap': () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BranchSkinSelectionPage()));
        },
      },
      {
        'icon': Icons.self_improvement,
        'title': "Body Luxe Retreat",
        'subtitle': "Relax your body and recharge – tap to experience it.",
        'onTap': () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BranchBodySelectionPage()));
        },
      },
      {
        'icon': Icons.calendar_today,
        'title': "Book Schedule",
        'subtitle': "Don't miss out! Book your next session now.",
        'onTap': () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BookRemainingSchedulePage()));
        },
      },
      {
        'icon': Icons.track_changes,
        'title': "View My Schedules",
        'subtitle': "See your scheduled activities.",
        'onTap': () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ViewYourSchedulePage()));
        },
      },
    ]);
  }

  Widget _buildGradientCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required double cardWidth,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: cardWidth,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF4C5C92), Color(0xFF2E3A67)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(2, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white12,
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFCED4F1),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}