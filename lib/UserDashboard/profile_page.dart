import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'member_details_page.dart'; // Add this import

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? photoUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPhoto();
  }

  Future<void> fetchPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final int? memberIdInt = prefs.getInt('member_id');
    String? memberId = memberIdInt?.toString() ?? prefs.getString('member_id');

    if (memberId == null || memberId.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/check_member_type.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'member_id': memberId}),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final photoPath = data['member_details']['photo_url'] as String?;
        if (mounted) {
          setState(() {
            photoUrl = photoPath != null && photoPath.isNotEmpty
                ? 'https://membership.ndasphilsinc.com/$photoPath'
                : null;
            isLoading = false;
          });
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = [Color(0xFF7F8AA8), Color(0xFF3D5184)];

    return Scaffold(
      backgroundColor: const Color(0xFF253660),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          Column(
            children: [
              ClipPath(
                clipper: WaveClipper(),
                child: Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl!) : null,
                      child: photoUrl == null
                          ? const Icon(Icons.person,
                          size: 40, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GradientButton(
                      icon: Icons.person,
                      label: "Your Profile",
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                            builder: (context) => const MemberDetailsPage(),
                        ),
                        );
                      },
                      gradientColors: gradientColors,
                    ),
                    const SizedBox(height: 12),
                    GradientButton(
                      icon: Icons.settings,
                      label: "Settings",
                      onPressed: () {},
                      gradientColors: gradientColors,
                    ),
                    const SizedBox(height: 12),
                    GradientButton(
                      icon: Icons.logout,
                      label: "Logout",
                      onPressed: () async {
                        SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login', (route) => false);
                        }
                      },
                      gradientColors: gradientColors,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Back button on top-left
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

  class GradientButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final List<Color> gradientColors;

  const GradientButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ).copyWith(
        backgroundColor: MaterialStateProperty.all(Colors.transparent),
        foregroundColor: MaterialStateProperty.all(Colors.white),
        elevation: MaterialStateProperty.all(0),
      ),
    ).decoratedWithGradient(gradientColors); // ✅ Correct usage
  }
}

extension GradientExtension on Widget {
  Widget decoratedWithGradient(List<Color> gradientColors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: this,
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 60);
    var firstControlPoint = Offset(size.width / 2, size.height);
    var firstEndPoint = Offset(size.width, size.height - 60);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
