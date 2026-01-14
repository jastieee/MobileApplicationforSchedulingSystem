import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../UserDashboard/dashboard.dart'; // Assuming DashboardPage is where a successful signup navigates

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _acceptedPrivacy = false;
  bool _obscurePassword = true;

  Future<void> _showSnackBar(String message, {bool error = false}) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _saveUserToPrefs(String username, String email, [String? password]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setString('email', email);
    if (password != null && password.isNotEmpty) {
      await prefs.setString('password', password);
    } else {
      await prefs.remove('password');
    }
  }

  Future<void> _onGoogleSignUp() async {
    if (!_acceptedPrivacy) {
      await _showSnackBar('You must accept the Privacy Policy to continue.', error: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _isLoading = false);
        return;
      }

      final username = account.displayName ?? account.email.split('@')[0];
      final email = account.email;
      final provider = 'google';
      final providerId = account.id;

      final data = {
        "username": username,
        "email": email,
        "provider": provider,
        "provider_id": providerId,
      };

      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/signup.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      final responseJson = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseJson['error'] != null) {
          await _showSnackBar('Signup failed: ${responseJson['error']}', error: true);
        } else {
          await _saveUserToPrefs(username, email);
          await _showSnackBar('Signup successful! Welcome, $username');
          // Navigate to Dashboard after successful signup
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        }
      } else {
        await _showSnackBar('Server error: ${response.statusCode}', error: true);
      }
    } catch (error) {
      await _showSnackBar('Google sign-in error: $error', error: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _onRegularSignUp() async {
    if (!_acceptedPrivacy) {
      await _showSnackBar('You must accept the Privacy Policy to continue.', error: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    final data = {
      "username": username,
      "email": email,
      "password": password,
      "provider": null,
      "provider_id": null,
    };

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/signup.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      final responseJson = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseJson['error'] != null) {
          await _showSnackBar('Signup failed: ${responseJson['error']}', error: true);
        } else {
          await _saveUserToPrefs(username, email, password);
          await _showSnackBar('Signup successful! Welcome, $username');
          // Navigate to Dashboard after successful signup
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        }
      } else {
        await _showSnackBar('Server error: ${response.statusCode}', error: true);
      }
    } catch (e) {
      await _showSnackBar('Signup error: $e', error: true);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _showTermsDialog() async {
    bool accepted = false;
    bool canAccept = false;
    final ScrollController scrollController = ScrollController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          scrollController.addListener(() {
            if (scrollController.offset >= scrollController.position.maxScrollExtent && !canAccept) {
              setStateDialog(() {
                canAccept = true;
              });
            }
          });

          return AlertDialog(
            backgroundColor: const Color(0xFF2E3C5D), // Aligned with input field background
            title: const Text('Privacy Policy and Terms of Use', style: TextStyle(color: Color(0xFFD3D7E0))),
            content: SizedBox(
              height: 300,
              width: 300,
              child: Scrollbar(
                thumbVisibility: true,
                controller: scrollController,
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: const Text(
                    '''
Privacy Policy

Your privacy is important to us. We collect and use your information in accordance with our privacy policy.

1. We collect your email and username to create your account.
2. We do not share your personal information with third parties without your consent.
3. You can request deletion of your data anytime.
4. For more information, visit our website or contact support.

Terms of Use

By using our service, you agree to the following terms:

1. You shall provide accurate information.
2. You shall not misuse the service.
3. We reserve the right to terminate accounts violating the terms.
4. The service is provided "as is" without warranty.
                    ''',
                    style: TextStyle(color: Color(0xFFB0B4C5)), // Adjusted text color
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: canAccept
                    ? () {
                  accepted = true;
                  Navigator.of(context).pop();
                }
                    : null,
                child: Text('Accept', style: TextStyle(color: canAccept ? Color(0xFF9FC5E8) : Colors.grey)), // Dynamic color for button
              ),
            ],
          );
        });
      },
    );

    if (accepted) {
      setState(() => _acceptedPrivacy = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF253660),
      body: LayoutBuilder( // Using LayoutBuilder for responsive sizing
        builder: (context, constraints) {
          return Stack( // Use Stack to place back button above content
            children: [
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight, // Ensure content can fill height if needed
                    maxWidth: 350, // Constrain horizontal width
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start, // Align to top
                          mainAxisSize: MainAxisSize.min, // Use min size to avoid overflow
                          children: [
                            Image.asset('images/slimmerswhite.png', width: 80, height: 80), // Reduced size
                            const SizedBox(height: 10),
                            const Text(
                              "Welcome to Slimmers World!",
                              style: TextStyle(
                                fontSize: 20, // Slightly reduced font size
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD3D7E0),
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Create your account",
                              style: TextStyle(fontSize: 15, color: Color(0xFFD3D7E0)), // Slightly reduced font size
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(Icons.person, 'Username', controller: _usernameController),
                            const SizedBox(height: 15),
                            _buildInputField(Icons.email, 'Email',
                                keyboardType: TextInputType.emailAddress, controller: _emailController),
                            const SizedBox(height: 15),
                            _buildInputField(Icons.lock, 'Password',
                                obscureText: true, controller: _passwordController),
                            const SizedBox(height: 15),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Checkbox(
                                  value: _acceptedPrivacy,
                                  checkColor: const Color(0xFF253660),
                                  fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                                    if (states.contains(MaterialState.selected)) {
                                      return const Color(0xFF7F8AA8);
                                    }
                                    return Colors.grey;
                                  }),
                                  onChanged: (val) async {
                                    if (val == true) {
                                      await _showTermsDialog();
                                    } else {
                                      setState(() => _acceptedPrivacy = false);
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      text: 'I accept the ',
                                      style: const TextStyle(color: Color(0xFFD3D7E0)),
                                      children: [
                                        TextSpan(
                                          text: 'Privacy Policy and Terms of Use',
                                          style: const TextStyle(
                                            color: Color(0xFF7F8AA8),
                                            decoration: TextDecoration.underline,
                                          ),
                                          recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _onRegularSignUp,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                  padding: EdgeInsets.zero,
                                  elevation: 5,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF7F8AA8),
                                        Color(0xFF3D5184),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    constraints: const BoxConstraints(minHeight: 50),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(color: Color(0xFFD3D7E0))
                                        : const Text(
                                      'Sign up',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFFD3D7E0),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15), // Reduced spacing
                            const Text(
                              "─────────  Or sign up with  ─────────",
                              style: TextStyle(color: Color(0xFFD3D7E0)),
                            ),
                            const SizedBox(height: 15), // Reduced spacing
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center, // Changed to center
                              children: [
                                _buildSocialIcon('images/google.png', () => _onGoogleSignUp()),
                                SizedBox(width: width * 0.05), // Added spacing
                                _buildSocialIcon('images/facebook.png', () {}),
                              ],
                            ),
                            const SizedBox(height: 30), // Reduced spacing
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(color: Color(0xFFD3D7E0), fontSize: 14),
                                children: [
                                  const TextSpan(text: "Already have an account? "),
                                  TextSpan(
                                    text: 'Sign in here',
                                    style: const TextStyle(
                                      color: Color(0xFF7F8AA8),
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.of(context).pop();
                                      },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 10), // Added small padding at bottom
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned( // Custom back button
                top: 10 + MediaQuery.of(context).padding.top, // Adjust for status bar
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputField(IconData icon, String label,
      {TextEditingController? controller,
        bool obscureText = false,
        TextInputType? keyboardType}) {
    bool isPassword = label == 'Password';

    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : obscureText,
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
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        if (label == 'Email' && !RegExp(r'\S+@\S+\.\S+').hasMatch(value.trim())) {
          return 'Enter a valid email address';
        }
        if (label == 'Password' && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildSocialIcon(String assetPath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        assetPath,
        width: 40, // Increased size for equal appearance
        height: 40, // Increased size for equal appearance
      ),
    );
  }
}
