import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OldMemberSearchPage extends StatefulWidget {
  const OldMemberSearchPage({Key? key}) : super(key: key);

  @override
  _OldMemberSearchPageState createState() => _OldMemberSearchPageState();
}

final TextStyle cardTextStyle = const TextStyle(color: Color(0xFFD3D7E0));

class _OldMemberSearchPageState extends State<OldMemberSearchPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _verificationCodeController = TextEditingController();
  bool _isLoading = false;
  String? _resultMessage;
  Map<String, String>? _memberInfo;
  bool _showVerificationPopup = false;
  String? _maskedEmail;
  Timer? _resendTimer;
  int _resendCountdown = 0;
  Timer? _expirationTimer;
  int _expirationCountdown = 0;
  bool _isVerifying = false;
  bool _isResending = false;

  bool _isSubmittingEmailReplacement = false; // Add this at the top with other state variables
  bool _showEmailMismatchPopup = false;
  bool _showEmailReplacementForm = false;
  String? _newEmail;
  String? _selectedIdType;
  File? _frontIdImage;
  File? _backIdImage;
  final TextEditingController _newEmailController = TextEditingController();

  Future<void> _searchMember() async {
    setState(() {
      _isLoading = true;
      _resultMessage = null;
      _memberInfo = null;
    });

    final response = await http.post(
      Uri.parse('https://membership.ndasphilsinc.com/oldmember.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'firstname': _firstNameController.text.trim(),
        'lastname': _lastNameController.text.trim(),
      }),
    );

    final jsonResponse = json.decode(response.body);
    setState(() => _isLoading = false);

    if (!jsonResponse['found']) {
      setState(() {
        _resultMessage = jsonResponse['message'] ?? 'Member not found.';
      });
      return;
    }

    final m = jsonResponse['member'];
    final birthdateStr = m['birthdate'];
    final age = (birthdateStr != null && birthdateStr.isNotEmpty)
        ? DateTime.now().year - DateTime.parse(birthdateStr).year
        : 0;

    setState(() {
      _memberInfo = {
        'id': (m['id'] ?? '').toString(),
        'firstname': m['firstname'] ?? '',
        'lastname': m['lastname'] ?? '',
        'fullname': [
          m['firstname'] ?? '',
          m['mi'] ?? '',
          m['lastname'] ?? '',
          if ((m['suffix'] ?? '').isNotEmpty) m['suffix']
        ].join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
        'branchCode': m['branch_code'] ?? '',
        'gender': m['gender'] ?? '',
        'birthdate': birthdateStr ?? '',
        'age': age.toString(),
        'email': m['email'] ?? '',
        'membershipType': m['membership_type'] ?? '',
        'suffix': m['suffix'] ?? '',
        'mi': m['mi'] ?? '',
        'photo_url': m['photo_url'] ?? '',
      };
    });
  }

  final List<String> _idTypes = [
    'PhilSys',
    'Passport',
    'Postal ID',
    'TIN',
    'PhilHealth',
    'Driver\'s License',
    'PRC'
  ];
  Future<void> _registerAndNavigate() async {
    if (_memberInfo == null) return;

    FocusScope.of(context).unfocus();

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Registration'),
        content: Text('Register yourself as ${_memberInfo!['fullname']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _attemptRegistration();
  }

  Future<void> _attemptRegistration({String? verificationCode}) async {
    setState(() {
      _isLoading = true;
      _resultMessage = null;
      if (verificationCode != null) {
        _isVerifying = true;
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? '';
      final email = prefs.getString('email') ?? '';
      final memberId = _memberInfo!['id'].toString();
      final fullname = _memberInfo!['fullname']!;
      final memberEmail = _memberInfo!['email']!;

      // Check if emails match
      if (email.toLowerCase().trim() != memberEmail.toLowerCase().trim() && verificationCode == null) {
        setState(() {
          _showEmailMismatchPopup = true;
        });
        _showEmailMismatchDialog();
        return;
      }

      final requestBody = {
        'member_id': memberId,
        'fullname': fullname,
        'username': username,
        'email': email,
      };

      if (verificationCode != null) {
        requestBody['verification_code'] = verificationCode;
      }

      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/register_old_member.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        await prefs.clear();
        _cancelVerification();

        if (!mounted) return;

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Registration Successful'),
            content: const Text('Registered successfully! Please log in again to refresh your dashboard.'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else if (jsonResponse['requires_verification'] == true) {
        setState(() {
          _showVerificationPopup = true;
          _maskedEmail = jsonResponse['masked_email'];
        });
        _showVerificationDialog();
        _startExpirationTimer();
        _startResendTimer();
      } else {
        setState(() {
          _resultMessage = jsonResponse['error'] ?? 'Registration failed.';
        });
      }
    } catch (e) {
      setState(() {
        _resultMessage = 'Error: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isVerifying = false;
      });
    }
  }

  Future<void> _submitEmailReplacement(BuildContext dialogContext) async {
    if (_isSubmittingEmailReplacement) return; // Prevent multiple submissions

    setState(() {
      _isLoading = true;
      _isSubmittingEmailReplacement = true; // Disable button
    });

    try {
      final newEmail = _newEmailController.text.trim();
      final memberInfo = _memberInfo!;

      // Convert images to base64
      final frontIdBase64 = base64Encode(await _frontIdImage!.readAsBytes());
      final backIdBase64 = base64Encode(await _backIdImage!.readAsBytes());

      // Prepare request data
      final requestData = {
        'member_id': memberInfo['id'],
        'member_name': memberInfo['fullname'],
        'old_email': memberInfo['email'],
        'new_email': newEmail,
        'id_type': _selectedIdType,
        'front_id': frontIdBase64,
        'back_id': backIdBase64,
      };

      // Send to PHP endpoint
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/email_replacement_request.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      final jsonResponse = jsonDecode(response.body);

      Navigator.of(dialogContext).pop();

      if (jsonResponse['success'] == true) {
        setState(() {
          _resultMessage = 'Email replacement request submitted successfully! You will receive a confirmation once reviewed.';
        });

        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Color(0xFF3D5184),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Processing', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(
              'Your email replacement request has been submitted successfully. '
                  'An admin will review your ID documents and notify you via email.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF3D5184),
                ),
                child: Text('OK'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _resultMessage = 'Failed to submit request: ${jsonResponse['error']}';
        });
      }
    } catch (e) {
      Navigator.of(dialogContext).pop();
      setState(() {
        _resultMessage = 'Error submitting request: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isSubmittingEmailReplacement = false; // Re-enable button
      });
      _resetEmailReplacement();
    }
  }

  void _resetEmailReplacement() {
    setState(() {
      _showEmailMismatchPopup = false;
      _showEmailReplacementForm = false;
      _newEmail = null;
      _selectedIdType = null;
      _frontIdImage = null;
      _backIdImage = null;
    });
    _newEmailController.clear();
  }
  // New method to show email mismatch dialog
  void _showEmailMismatchDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF3D5184),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Wrong Email', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Your registered email doesn\'t match the member\'s email. Would you like to change it?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _showEmailMismatchPopup = false;
              });
            },
            child: Text('No', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _showEmailReplacementForm = true;
              });
              _showEmailReplacementDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF3D5184),
            ),
            child: Text('Yes'),
          ),
        ],
      ),
    );
  }

// New method to show email replacement form
  void _showEmailReplacementDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7F8AA8), Color(0xFF3D5184)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Icon(Icons.email_outlined, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Email Replacement Request',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  SizedBox(height: 20),

                  // New Email Field
                  TextField(
                    controller: _newEmailController,
                    decoration: InputDecoration(
                      labelText: 'New Email Address',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      prefixIcon: Icon(Icons.email, color: Colors.white70),
                    ),
                    style: TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 16),

                  // ID Type Dropdown
                  Text('Select ID Type:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedIdType,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        prefixIcon: Icon(Icons.credit_card, color: Colors.white70),
                      ),
                      dropdownColor: Color(0xFF3D5184),
                      style: TextStyle(color: Colors.white),
                      hint: Text('Choose ID Type', style: TextStyle(color: Colors.white70)),
                      items: _idTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type, style: TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          _selectedIdType = newValue;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 20),

                  // ID Images Section
                  Text('Upload ID Images:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(height: 12),

                  // Front ID
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('Front ID', style: TextStyle(color: Colors.white70)),
                            SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _showImageSourceDialog(true, setDialogState),
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white54, style: BorderStyle.solid),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white12,
                                ),
                                child: _frontIdImage != null
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(_frontIdImage!, fit: BoxFit.cover),
                                )
                                    : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate, color: Colors.white54, size: 40),
                                    Text('Tap to add', style: TextStyle(color: Colors.white54)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            Text('Back ID', style: TextStyle(color: Colors.white70)),
                            SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _showImageSourceDialog(false, setDialogState),
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white54, style: BorderStyle.solid),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white12,
                                ),
                                child: _backIdImage != null
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(_backIdImage!, fit: BoxFit.cover),
                                )
                                    : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate, color: Colors.white54, size: 40),
                                    Text('Tap to add', style: TextStyle(color: Colors.white54)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetEmailReplacement();
                        },
                        child: Text('Cancel', style: TextStyle(color: Colors.white70)),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: (_canSubmitEmailReplacement() && !_isSubmittingEmailReplacement)
                            ? () => _submitEmailReplacement(context)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF3D5184),
                        ),
                        child: _isSubmittingEmailReplacement
                            ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Color(0xFF3D5184)),
                          ),
                        )
                            : Text('Submit Request'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// Helper methods for image selection and email replacement
  void _showImageSourceDialog(bool isFront, StateSetter setDialogState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF3D5184),
        title: Text('Select Image Source', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.white),
              title: Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isFront, setDialogState);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.white),
              title: Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isFront, setDialogState);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, bool isFront, StateSetter setDialogState) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setDialogState(() {
        if (isFront) {
          _frontIdImage = File(pickedFile.path);
        } else {
          _backIdImage = File(pickedFile.path);
        }
      });
    }
  }

  bool _canSubmitEmailReplacement() {
    return _newEmailController.text.trim().isNotEmpty &&
        _selectedIdType != null &&
        _frontIdImage != null &&
        _backIdImage != null;
  }
  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Timer to refresh countdown
          Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted && _showVerificationPopup) {
              setDialogState(() {});
            } else {
              timer.cancel();
            }
          });

          // Determine expiration text color
          final expColor = _expirationCountdown <= 10
              ? Colors.red
              : Colors.white;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7F8AA8), Color(0xFF3D5184)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Row(
                    children: [
                      Icon(Icons.email, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Email Verification Required',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'We sent a verification code to\n${_maskedEmail ?? 'your registered email'}',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Code input
                  TextField(
                    controller: _verificationCodeController,
                    decoration: InputDecoration(
                      labelText: 'Enter 6‑digit code',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      prefixIcon: Icon(Icons.security, color: Colors.white70),
                      counterText: '',
                      helperText: 'Check your email for the code',
                      helperStyle: TextStyle(color: Colors.white60),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Countdown panel
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _expirationCountdown > 0
                              ? 'Expires in: ${_formatTime(_expirationCountdown)}'
                              : 'Code has expired',
                          style: TextStyle(
                            color: _expirationCountdown > 0 ? expColor : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resend button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_resendCountdown > 0 || _isResending)
                          ? null
                          : () async {
                        await _resendVerificationCode();
                        setDialogState(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isResending
                          ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                          : Icon(Icons.refresh, color: Colors.white70),
                      label: Text(
                        _isResending
                            ? 'Sending...'
                            : _resendCountdown > 0
                            ? 'Resend (${_formatTime(_resendCountdown)})'
                            : 'Resend Code',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _cancelVerification();
                          Navigator.of(context).pop();
                        },
                        child: Text('Cancel', style: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: (_isVerifying || _expirationCountdown <= 0)
                            ? null
                            : () {
                          Navigator.of(context).pop();
                          _verifyCode();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF3D5184),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: _isVerifying
                            ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Color(0xFF3D5184)),
                          ),
                        )
                            : Text('Verify'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyCode() async {
    final code = _verificationCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _resultMessage = 'Please enter the verification code.';
      });
      return;
    }

    if (code.length != 6) {
      setState(() {
        _resultMessage = 'Please enter a valid 6-digit verification code.';
      });
      return;
    }

    await _attemptRegistration(verificationCode: code);
  }

  Future<void> _resendVerificationCode() async {
    if (_memberInfo == null || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/resend_code.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'member_id': _memberInfo!['id'],
        }),
      );

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['success'] == true) {
        setState(() {
          _resultMessage = 'New verification code sent!';
          _maskedEmail = jsonResponse['masked_email'];
        });
        _startResendTimer(); // Start 1-minute resend timer
        _startExpirationTimer(); // Reset 2-minute expiration timer
      } else {
        setState(() {
          _resultMessage = jsonResponse['error'] ?? 'Failed to resend code.';
        });
      }
    } catch (e) {
      setState(() {
        _resultMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60; // 1 minute
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _startExpirationTimer() {
    _expirationTimer?.cancel();
    setState(() {
      _expirationCountdown = 120; // 2 minutes
    });

    _expirationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_expirationCountdown > 0) {
            _expirationCountdown--;
          } else {
            timer.cancel();
            _resultMessage = 'Verification code has expired. Please request a new one.';
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _cancelVerification() {
    _resendTimer?.cancel();
    _expirationTimer?.cancel();
    _verificationCodeController.clear();
    setState(() {
      _showVerificationPopup = false;
      _maskedEmail = null;
      _resendCountdown = 0;
      _expirationCountdown = 0;
      _isVerifying = false;
      _isResending = false;
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _verificationCodeController.dispose();
    _newEmailController.dispose(); // Add this line
    _resendTimer?.cancel();
    _expirationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF253660),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 30),
                Text(
                  'Old Member Lookup',
                  style: TextStyle(
                    color: const Color(0xFFD3D7E0),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 30),
                _buildStyledTextField(_firstNameController, 'First Name'),
                const SizedBox(height: 16),
                _buildStyledTextField(_lastNameController, 'Last Name'),
                const SizedBox(height: 24),
                _buildGradientButton('Search Member', _searchMember),
                const SizedBox(height: 24),
                if (_isLoading) const CircularProgressIndicator(color: Color(0xFFD3D7E0)),
                if (_resultMessage != null && !_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _resultMessage!,
                      style: TextStyle(
                          fontSize: 16,
                          color: _resultMessage!.contains('successfully') || _resultMessage!.contains('sent')
                              ? Colors.green
                              : Colors.redAccent
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_memberInfo != null) ...[
                  GestureDetector(
                    onTap: _registerAndNavigate,
                    child: Card(
                      elevation: 8,
                      margin: const EdgeInsets.only(top: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF566180),
                              Color(0xFF37415B),
                              Color(0xFFBEC3D1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [0.0, 0.6, 1.0],
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            if ((_memberInfo!['photo_url'] ?? '').isNotEmpty)
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: NetworkImage(
                                  'https://membership.ndasphilsinc.com/${_memberInfo!['photo_url']}',
                                ),
                              )
                            else
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[300],
                                child: const Icon(Icons.person, size: 50, color: Colors.grey),
                              ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _memberInfo!['fullname']!,
                                    style: cardTextStyle.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Branch Code: ${_memberInfo!['branchCode']}', style: cardTextStyle),
                                  Text('Gender: ${_memberInfo!['gender']}', style: cardTextStyle),
                                  Text('Birthdate: ${_memberInfo!['birthdate']}', style: cardTextStyle),
                                  Text('Age: ${_memberInfo!['age']}', style: cardTextStyle),
                                  Text('Email: ${_memberInfo!['email']}', style: cardTextStyle),
                                  Text('Membership Type: ${_memberInfo!['membershipType']}', style: cardTextStyle),
                                  if ((_memberInfo!['suffix'] ?? '').isNotEmpty)
                                    Text('Suffix: ${_memberInfo!['suffix']}', style: cardTextStyle),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tap the card above to register and continue.',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFFD3D7E0)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xFFD3D7E0)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFD3D7E0)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFD3D7E0)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: const Color(0xFF2E3D59),
      ),
    );
  }

  Widget _buildGradientButton(String text, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7F8AA8), Color(0xFF3D5184)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            offset: Offset(0, 4),
            blurRadius: 6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFD3D7E0),
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}