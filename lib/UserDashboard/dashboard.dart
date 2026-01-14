import 'package:flutter/material.dart';
import 'package:slimmersworld/NewMembers/newmember.dart';
import '../NewMembers/oldmember.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

  void _handleNewMember(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) =>  OnlineRegistrationPage()),
    );
  }

  void _handleOldMember(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OldMemberSearchPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Deep navy background color
      backgroundColor: const Color(0xFF253660),
      body: Stack(
        children: [
          // Top curved gradient area - slightly lighter gradient for depth
          ClipPath(
            clipper: CurvedTopClipper(),
            child: Container(
              height: 250,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF394C7A),
                    Color(0xFF253660),
                  ],
                ),
              ),
            ),
          ),
          // Bottom curved gradient area - inverse lighter gradient for balance
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: CurvedBottomClipper(),
              child: Container(
                height: 200,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Color(0xFF394C7A),
                      Color(0xFF253660),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Buttons centered in the middle
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // New Member button with gradient and elegant style
                  GestureDetector(
                    onTap: () => _handleNewMember(context),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF7F8AA8),
                            Color(0xFF3D5184),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            offset: const Offset(0, 6),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'New Member',
                        style: TextStyle(
                          color: Color(0xFFD3D7E0),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Old Member button with same style but reversed gradient direction
                  GestureDetector(
                    onTap: () => _handleOldMember(context),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF3D5184),
                            Color(0xFF7F8AA8),
                          ],
                          begin: Alignment.bottomRight,
                          end: Alignment.topLeft,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            offset: const Offset(0, 6),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Old Member',
                        style: TextStyle(
                          color: Color(0xFFD3D7E0),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class CurvedTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.moveTo(0, 0);

    // Smooth wide arc dipping near center-bottom
    path.quadraticBezierTo(
      size.width * 0.15,
      140,          // deeper dip, more elegance
      size.width * 0.5,
      130,
    );

    // Gentle rise toward top-right with smooth control point
    path.quadraticBezierTo(
      size.width * 0.85,
      110,
      size.width,
      70,
    );

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class CurvedBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.moveTo(0, size.height);

    // Gentle upward curve near left edge
    path.quadraticBezierTo(
      size.width * 0.15,
      size.height - 130,
      size.width * 0.5,
      size.height - 100,
    );

    // Smooth downward curve near right edge
    path.quadraticBezierTo(
      size.width * 0.85,
      size.height - 80,
      size.width,
      size.height - 50,
    );

    path.lineTo(size.width, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

