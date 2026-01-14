import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'NewMembers/signup.dart';
import 'UserDashboard/welcome_page.dart';
import 'Const/splash.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slimmers World',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF253660),
        fontFamily: 'Helvetica',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/welcome': (context) => const WelcomePage(),
        '/signup': (context) => const SignUpPage(),
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final String checkUserUrl = 'https://membership.ndasphilsinc.com/login.php';
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();

  Future<void> saveUserData({
    required String username,
    required String password,
    required String email,
    required String fullname,
    required int memberId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setString('password', password);
    await prefs.setString('email', email);
    await prefs.setString('fullname', fullname);
    await prefs.setInt('member_id', memberId);
  }

  void _onSignUpTap(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SignUpPage()));
  }

  void _onGoogleSignIn(BuildContext context) async {
    final GoogleSignIn _googleSignIn = GoogleSignIn();

    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) return;

      final email = account.email;

      final response = await http.post(
        Uri.parse(checkUserUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['exists'] == true) {
        await saveUserData(
          username: jsonResponse['username'] ?? email,
          password: '',
          email: email,
          fullname: jsonResponse['fullname'] ?? account.displayName ?? '',
          memberId: jsonResponse['member_id'] ?? 0,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome back, ${jsonResponse['fullname'] ?? account.displayName}!')),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomePage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No account found. Please sign up first.')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in error: $error')),
      );
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final TextEditingController _emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2E3C5D),
          title: const Text('Forgot Password', style: TextStyle(color: Color(0xFFD3D7E0))),
          content: TextField(
            controller: _emailController,
            style: const TextStyle(color: Color(0xFFD3D7E0)),
            decoration: const InputDecoration(
              hintText: 'Enter your email',
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFD3D7E0))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D5184),
              ),
              onPressed: () async {
                final email = _emailController.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter your email')),
                  );
                  return;
                }

                final response = await http.post(
                  Uri.parse('https://membership.ndasphilsinc.com/forgot_password.php'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'email': email}),
                );

                Navigator.pop(context);
                final result = jsonDecode(response.body);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'] ?? 'Email sent')),
                );
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final response = await http.post(
        Uri.parse(checkUserUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['success'] == true) {
        await saveUserData(
          username: username,
          password: password,
          email: jsonResponse['email'] ?? '',
          fullname: jsonResponse['fullname'] ?? '',
          memberId: jsonResponse['member_id'] ?? 0,
        );

        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomePage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid username or password')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.08, vertical: height * 0.05),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('images/slimmerswhite.png', width: width * 0.3),
                    SizedBox(height: height * 0.03),
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFFD3D7E0)),
                    ),
                    const Text(
                      'Sign in to your account',
                      style: TextStyle(fontSize: 16, color: Color(0xFFB0B4C5)),
                    ),
                    SizedBox(height: height * 0.03),
                    _buildInputField(
                      icon: Icons.person,
                      label: 'Username',
                      controller: _usernameController,
                      obscureText: false,
                      keyboardType: TextInputType.text,
                      isPassword: false,
                    ),
                    SizedBox(height: height * 0.02),
                    _buildInputField(
                      icon: Icons.lock,
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      keyboardType: TextInputType.text,
                      isPassword: true,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          splashColor: const Color(0xFF3D5184), // Use one color from your gradient
                          onTap: () => _showForgotPasswordDialog(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text('Forgot Password?', style: TextStyle(color: Color(0xFFB0B4C5))),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: height * 0.02),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          elevation: 6, // shadow depth
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          padding: EdgeInsets.zero, // removes default padding for full gradient
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.black45, // shadow color
                        ).copyWith(
                          // Use a gradient background with Ink feature (works well with MaterialStateProperty)
                          backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                                (Set<MaterialState> states) {
                              if (states.contains(MaterialState.pressed)) {
                                return const Color(0xFF3D5184); // darker blue when pressed
                              }
                              return null; // defer to gradient container below
                            },
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7F8AA8), Color(0xFF3D5184)],
                            ),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: const Text('Sign in', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: height * 0.04),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFF7F8AA8), thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'Or sign in with',
                            style: TextStyle(color: Color(0xFFB0B4C5)),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFF7F8AA8), thickness: 1)),
                      ],
                    ),
                    SizedBox(height: height * 0.02),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center, // Changed to center
                      children: [
                        _buildSocialIcon('images/google.png', () => _onGoogleSignIn(context)),
                        SizedBox(width: width * 0.05), // Added spacing
                        _buildSocialIcon('images/facebook.png', () {}),
                      ],
                    ),
                    SizedBox(height: height * 0.06),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Color(0xFFD3D7E0), fontSize: 14),
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Sign up here',
                            style: const TextStyle(
                              color: Color(0xFF9FC5E8), // lighter blue for better visibility
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()..onTap = () => _onSignUpTap(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFFD3D7E0)),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF7F8AA8)),
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFB0B4C5)),
        filled: true,
        fillColor: const Color(0xFF2E3C5D),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Color(0xFF7F8AA8)),
        ),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF7F8AA8),
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        )
            : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
    );
  }

  Widget _buildSocialIcon(String assetPath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(assetPath, width: 40, height: 40), // Increased size for equal appearance
    );
  }
}
