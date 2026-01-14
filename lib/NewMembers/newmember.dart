import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:webview_flutter/webview_flutter.dart';

class OnlineRegistrationPage extends StatefulWidget {
  const OnlineRegistrationPage({Key? key}) : super(key: key);

  @override
  State<OnlineRegistrationPage> createState() => _OnlineRegistrationPageState();
}

class _OnlineRegistrationPageState extends State<OnlineRegistrationPage> {
  final _formKeyPage1 = GlobalKey<FormState>();
  final _formKeyPage2 = GlobalKey<FormState>();
  int _currentStep = 0;
  WebViewController? _webViewController;
  bool _showWebView = false;
  // Page 1 controllers
  final _firstnameController = TextEditingController();
  final _miController = TextEditingController();
  final _lastnameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _addressController = TextEditingController();

  // Page 1 gender field
  String? _gender;
  String? _paymentType; // New: Full or Partial

  // Page 2 fields
  String? _checkoutUrl;
  String? _referenceId;
  bool _paymentCompleted = false;
  String? _membershipType;
  String? _location;
  String? _duration;
  final _priceController = TextEditingController();
  final _branchCodeController = TextEditingController();
  File? _selectedImage;

  final List<String> _membershipTypes = ['AA', 'A', 'G', 'E'];
  final List<String> _durations = ['1 month', '3 months', '6 months', '1 year', 'lifetime'];
  List<String> _availableLocations = [];
  Map<String, String> _locationToBranchCode = {};

  Future<void> _fetchBranchOptions() async {
    if (_membershipType == null) return;
    final regularAccess = (_membershipType == 'AA' || _membershipType == 'A') ? 0 : 1;

    final response = await http.post(
      Uri.parse('https://membership.ndasphilsinc.com/get_branch_access.php'),
      body: {'regular_access': '$regularAccess'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      setState(() {
        _availableLocations.clear();
        _locationToBranchCode.clear();
        for (final branch in jsonData) {
          final branchName = branch['branch_name'];
          final branchCode = branch['branch_code'];
          _availableLocations.add(branchName);
          _locationToBranchCode[branchName] = branchCode;
        }
      });
    }
  }

  // Elegant color scheme
  static const Color primaryBackground = Color(0xFF253660);
  static const Color textColor = Color(0xFFD3D7E0);
  static const Color cardBackground = Color(0xFF2D4373);
  static const Color inputFillColor = Color(0xFF364A7A);
  static const Color borderColor = Color(0xFF4A5F8F);
  static const List<Color> gradientColors = [Color(0xFF7F8AA8), Color(0xFF3D5184)];

  @override
  void initState() {
    super.initState();
    _loadEmailFromPrefs();
  }

  @override
  void dispose() {
    _firstnameController.dispose();
    _miController.dispose();
    _lastnameController.dispose();
    _suffixController.dispose();
    _birthdateController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _contactNumberController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _branchCodeController.dispose();

    super.dispose();
  }

  Future<void> _loadEmailFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email') ?? '';
    setState(() {
      _emailController.text = savedEmail;
    });
  }

  double _fullPrice = 0.0; // Store the actual full price
  final _paymentController = TextEditingController(); // For amount being paid

  void _updatePrice() {
    if (_membershipType != null && _duration != null) {
      final priceTable = {
        'AA': {
          '1 month': '1000',
          '3 months': '2500',
          '6 months': '4000',
          '1 year': '7000',
          'lifetime': '15000'
        },
        'A': {
          '1 month': '900',
          '3 months': '2300',
          '6 months': '3800',
          '1 year': '6500',
          'lifetime': '14000'
        },
        'G': {
          '1 month': '800',
          '3 months': '2000',
          '6 months': '3500',
          '1 year': '6000',
          'lifetime': '13000'
        },
        'E': {
          '1 month': '700',
          '3 months': '1800',
          '6 months': '3000',
          '1 year': '5500',
          'lifetime': '12000'
        },
      };

      final rawPrice = priceTable[_membershipType!]?[_duration!];
      if (rawPrice != null) {
        _fullPrice = double.tryParse(rawPrice) ?? 0; // Store full price
        _priceController.text = _fullPrice.round().toString(); // Show full price initially

        if (_paymentType == 'Partial') {
          double paymentAmount = _fullPrice * 0.20; // Fixed 20% down payment
          _paymentController.text = paymentAmount.round().toString();
          _priceController.text = "₱${_fullPrice.round()} (Down Payment: ₱${paymentAmount.round()})";
        } else {
          _paymentController.text = _fullPrice.round().toString();
          _priceController.text = _fullPrice.round().toString();
        }
      }
    }
  }



  Future<void> _pickImage(bool fromCamera) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }


  Future<void> _submitFormAfterPayment() async {
    final uri = Uri.parse("https://membership.ndasphilsinc.com/upload_mem.php");
    final request = http.MultipartRequest("POST", uri);

    String paymentStatus = _paymentType == 'Full' ? 'Fully Paid' : 'Partial';
    double paymentAmount = double.tryParse(_paymentController.text.replaceAll(',', '')) ?? 0;
    double balance = _fullPrice - paymentAmount;

    final paymentStatuses = await _checkPaymentStatus();

    String actualPaymentMethod = 'PayMongo'; // default
    if (paymentStatuses != null) {
      actualPaymentMethod = paymentStatuses['payment_method'] ?? 'PayMongo';
    }

    // Debug: Print values being sent
    print("Sending data:");
    print("Price: ${_fullPrice.toString()}");
    print("Payment: ${paymentAmount.toString()}");
    print("Balance: ${balance.toString()}");
    print("Payment Status: $paymentStatus");

    // Add form fields with proper validation
    request.fields['firstname'] = _firstnameController.text.trim();
    request.fields['mi'] = _miController.text.trim();
    request.fields['lastname'] = _lastnameController.text.trim();
    request.fields['suffix'] = _suffixController.text.trim();
    request.fields['birthdate'] = _birthdateController.text.trim();
    request.fields['age'] = _ageController.text.trim();
    request.fields['gender'] = _gender ?? '';
    request.fields['email'] = _emailController.text.trim();
    request.fields['contact_number'] = _contactNumberController.text.trim();
    request.fields['address'] = _addressController.text.trim();
    request.fields['membership_type'] = _membershipType ?? '';
    request.fields['location'] = _location ?? '';
    request.fields['branch_code'] = _branchCodeController.text.trim();
    request.fields['duration'] = _duration ?? '';

    // Send as strings without commas
    request.fields['price'] = _fullPrice.toStringAsFixed(2);
    request.fields['payment'] = paymentAmount.toStringAsFixed(2);
    request.fields['balance'] = balance.toStringAsFixed(2);
    request.fields['payment_status'] = paymentStatus;
    request.fields['reference_id'] = _referenceId ?? '';
    request.fields['payment_method'] = actualPaymentMethod;

    // Add image if selected
    if (_selectedImage != null) {
      final mimeType = lookupMimeType(_selectedImage!.path) ?? 'image/jpeg';
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo_url',
          _selectedImage!.path,
          contentType: MediaType.parse(mimeType),
        ),
      );
    }

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x99253660), Color(0x99000000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Card(
            color: cardBackground,
            elevation: 8,
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F8AA8)),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Creating your membership...',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      Navigator.of(context).pop();

      // Debug: Print response
      print("Response Status: ${response.statusCode}");
      print("Response Body: $responseBody");

      if (response.statusCode == 200) {
        try {
          final jsonResponse = json.decode(responseBody);
          if (jsonResponse['status'] == 'success') {
            _showSuccessWithLogout();
          } else {
            _showElegantSnackBar('Error: ${jsonResponse['message']}');
          }
        } catch (e) {
          print("JSON decode error: $e");
          _showElegantSnackBar('Invalid server response');
        }
      } else {
        _showElegantSnackBar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.of(context).pop();
      print("Request error: $e");
      _showElegantSnackBar('Network error: $e');
    }
  }

// 2. New success dialog with logout
  void _showSuccessWithLogout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: gradientColors),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Success',
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Membership created successfully! You will be logged out now.',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildGradientButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Clear user session and navigate to login
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                text: 'OK',
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<Map<String, dynamic>?> _createPayMongoCheckout() async {
    if (_paymentController.text.isEmpty) {
      _showElegantSnackBar('Payment amount not available');
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? '';

    if (username.isEmpty) {
      _showElegantSnackBar('Username not found');
      return null;
    }

    final paymentAmount = double.tryParse(_paymentController.text) ?? 0;
    final amountInCentavos = (paymentAmount * 1).toInt();
    final fullName = '${_firstnameController.text} ${_lastnameController.text}';

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/create_payment_flutter.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amountInCentavos.toString(),
          'name': fullName,
          'user_name': username,
          'use_deep_links': 'false', // Change this to false
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return {
            'checkout_url': responseData['checkout_url'],
            'reference_id': responseData['reference_id'],
          };
        } else {
          print('Backend Error: ${responseData['message']}');
          return null;
        }
      } else {
        print('HTTP Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception: $e');
      return null;
    }
  }

  // Replace your _launchPayMongoCheckout method with this updated version:

  Future<void> _launchPayMongoCheckout() async {
    final checkoutData = await _createPayMongoCheckout();
    if (checkoutData == null) {
      _showElegantSnackBar('Failed to create payment session');
      return;
    }

    final url = checkoutData['checkout_url'];
    final referenceId = checkoutData['reference_id'];

    if (url == null || url.isEmpty) {
      _showElegantSnackBar('Checkout URL missing');
      return;
    }

    setState(() {
      _referenceId = referenceId;
    });

    // WebView controller setup with improved navigation detection
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('Page started loading: $url');
          },
          onPageFinished: (String url) {
            print('Page finished loading: $url');

            // Check for various success indicators
            if (_isPaymentSuccessUrl(url)) {
              print('Payment success detected!');
              Navigator.of(context).pop(); // Close WebView Dialog
              _showPaymentWaitingDialog();
            } else if (_isPaymentFailedUrl(url)) {
              print('Payment failed detected!');
              Navigator.of(context).pop();
              _showElegantSnackBar('Payment was cancelled or failed.');
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    // Open the WebView in a fullscreen dialog
    _showWebViewDialogEnhanced();
  }

// New method to detect payment success URLs
  bool _isPaymentSuccessUrl(String url) {
    // PayMongo success patterns
    return url.contains('success') ||
        url.contains('paid') ||
        url.contains('payment_intent_id') ||
        url.contains('completed') ||
        url.contains('payment_method_id') ||
        // Add your app's success redirect URL if you have one
        url.contains('your-success-redirect-url');
  }

// New method to detect payment failure URLs
  bool _isPaymentFailedUrl(String url) {
    return url.contains('cancel') ||
        url.contains('failed') ||
        url.contains('error') ||
        url.contains('cancelled');
  }

// Alternative approach - Monitor URL changes more aggressively
  Future<void> _launchPayMongoCheckoutWithTimer() async {
    final checkoutData = await _createPayMongoCheckout();
    if (checkoutData == null) {
      _showElegantSnackBar('Failed to create payment session');
      return;
    }

    final url = checkoutData['checkout_url'];
    final referenceId = checkoutData['reference_id'];

    if (url == null || url.isEmpty) {
      _showElegantSnackBar('Checkout URL missing');
      return;
    }

    setState(() {
      _referenceId = referenceId;
    });

    // WebView controller setup
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            print('Page finished loading: $url');

            // More comprehensive URL checking
            if (url.contains('payment_intent_id') && url.contains('message=true')) {
              print('PayMongo payment page loaded - user can now pay');
              // Don't auto-close here, let user complete payment
            } else if (_isPaymentSuccessUrl(url)) {
              Navigator.of(context).pop();
              _showPaymentWaitingDialog();
            } else if (_isPaymentFailedUrl(url)) {
              Navigator.of(context).pop();
              _showElegantSnackBar('Payment was cancelled or failed.');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            print('Navigation request: ${request.url}');

            // Allow all navigation but log it
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    // Open the WebView with enhanced dialog
    _showWebViewDialogEnhanced();
  }

// Most reliable approach - Let user manually confirm
  Future<void> _launchPayMongoCheckoutManual() async {
    final checkoutData = await _createPayMongoCheckout();
    if (checkoutData == null) {
      _showElegantSnackBar('Failed to create payment session');
      return;
    }

    final url = checkoutData['checkout_url'];
    final referenceId = checkoutData['reference_id'];

    if (url == null || url.isEmpty) {
      _showElegantSnackBar('Checkout URL missing');
      return;
    }

    setState(() {
      _referenceId = referenceId;
    });

    // Simple WebView without automatic detection
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            // Just log, don't auto-detect
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    // Show WebView with manual confirmation
    _showWebViewDialogWithStatusCheck();
  }

// New WebView dialog with status check button
  void _showWebViewDialogWithStatusCheck() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Complete Payment'),
          actions: [
            // Add a "Payment Done" button in the app bar
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showPaymentStatusDialog();
              },
              child: const Text(
                'Payment Done?',
                style: TextStyle(color: Colors.white),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.pop(context);
                _showPaymentStatusDialog();
              },
            )
          ],
        ),
        body: SafeArea(
          child: WebViewWidget(controller: _webViewController!),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.pop(context);
            _showPaymentStatusDialog();
          },
          label: const Text('Payment Complete'),
          icon: const Icon(Icons.check_circle),
          backgroundColor: const Color(0xFF7F8AA8),
        ),
      ),
    );
  }

  void _showWebViewDialogEnhanced() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Complete Payment'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.pop(context);
                _showPaymentStatusDialog();
              },
            )
          ],
        ),
        body: SafeArea(
          child: WebViewWidget(controller: _webViewController!),
        ),
      ),
    );
  }

  void _handlePaymentSuccess() {
    setState(() {
      _showWebView = false;
      _paymentCompleted = true;
    });
    _showElegantSnackBar('Payment completed successfully!');
    // Submit form after successful payment
    _submitFormAfterPayment();
  }

  // 6. Add payment cancel handler
  void _handlePaymentCancel() {
    setState(() {
      _showWebView = false;
    });
    _showElegantSnackBar('Payment was cancelled');
  }

  void _showPaymentStatusDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.help_outline,
                color: Color(0xFF7F8AA8),
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Status',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Did you complete your payment successfully?',
                style: TextStyle(
                  color: Color(0xFFB0B8CC),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildGradientButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Submit form immediately - payment successful
                        _submitFormAfterPayment();
                      },
                      text: 'Yes, Paid',
                      icon: Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGradientButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Show waiting dialog for manual status check
                        _showPaymentWaitingDialog();
                      },
                      text: 'Not Sure',
                      icon: Icons.help,
                      isSecondary: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Try payment again
                  _launchPayMongoCheckout();
                },
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: Color(0xFFB0B8CC)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // 8. Add WebView payment widget
  Widget _buildWebViewPayment() {
    return Scaffold(
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: cardBackground,
        title: const Text(
          'Complete Payment',
          style: TextStyle(color: textColor, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: textColor),
          onPressed: () {
            setState(() {
              _showWebView = false;
            });
          },
        ),
        elevation: 0,
      ),
      body: _webViewController != null
          ? WebViewWidget(controller: _webViewController!)
          : const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F8AA8)),
        ),
      ),
    );
  }

// Enhanced payment waiting dialog with retry option
  void _showPaymentWaitingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F8AA8)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment In Progress',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete your payment in the browser/app that opened.\n\nClick "Check Status" when payment is completed.',
                style: TextStyle(
                  color: Color(0xFFB0B8CC),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildGradientButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Submit form immediately when check status is clicked
                        _submitFormAfterPayment();
                      },
                      text: 'Check Status',
                      icon: Icons.refresh,
                    ),
                  ),
                  // const SizedBox(width: 12),
                  // Expanded(
                  //   child: _buildGradientButton(
                  //     onPressed: () {
                  //       Navigator.of(context).pop();
                  //       _launchPayMongoCheckout();
                  //     },
                  //     text: 'Retry',
                  //     isSecondary: true,
                  //   ),
                  // ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFFB0B8CC)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Remove automatic status checking since user will manually click
    // _checkPaymentStatusPeriodically();
  }

// Function to check payment status from your backend
  Future<Map<String, dynamic>?> _checkPaymentStatus() async {
    if (_referenceId == null) return null;

    try {
      final response = await http.post(
        Uri.parse('https://membership.ndasphilsinc.com/check_payment_status.php'),
        body: {'reference_id': _referenceId},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'payment_method': data['payment_method'], // Will be "Gcash", "Paymaya", or "Card"
            'payment_status': data['payment_status'],
            'amount_paid': data['amount_paid']
          };
        }
      }
    } catch (e) {
      print('Payment status check error: $e');
    }
    return null;
  }

// Modified submit function - now launches payment first
  Future<void> _submitForm() async {
    if (!_formKeyPage2.currentState!.validate()) return;
    if (_selectedImage == null) {
      _showElegantSnackBar('Please select a photo');
      return;
    }

    // Launch PayMongo payment
    await _launchPayMongoCheckout();
  }

  void _showElegantSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: cardBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: textColor, fontSize: 14),
    filled: true,
    fillColor: const Color(0xFF2E3C5D),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: const BorderSide(color: Color(0xFF7F8AA8)),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: borderColor, width: 1),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFE57373), width: 1),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFE57373), width: 2),
    ),
    errorStyle: const TextStyle(color: Color(0xFFE57373)),
  );

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required String text,
    IconData? icon,
    double? width,
    bool isSecondary = false,
  }) {
    return Container(
      width: width,
      height: 48,
      decoration: BoxDecoration(
        gradient: isSecondary
            ? const LinearGradient(colors: [Color(0xFF5A6B8A), Color(0xFF435274)])
            : const LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isSecondary ? Colors.black26 : const Color(0xFF3D5184).withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     backgroundColor: primaryBackground,
  //     body: Container(
  //       decoration: const BoxDecoration(
  //         gradient: LinearGradient(
  //           begin: Alignment.topCenter,
  //           end: Alignment.bottomCenter,
  //           colors: [primaryBackground, Color(0xFF1E2B4F)],
  //         ),
  //       ),
  //       child: _currentStep == 0 ? _buildPersonalInfoForm() : _buildMembershipForm(),
  //     ),
  //   );
  // }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: _showWebView ? _buildWebViewPayment() : Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryBackground, Color(0xFF1E2B4F)],
          ),
        ),
        child: _currentStep == 0 ? _buildPersonalInfoForm() : _buildMembershipForm(),
      ),
    );
  }

  Widget _buildPersonalInfoForm() {
    return Form(
      key: _formKeyPage1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          color: cardBackground.withOpacity(0.7),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please provide your personal details',
                  style: TextStyle(
                    color: Color(0xFFB0B8CC),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _firstnameController,
                  style: const TextStyle(color: textColor),
                  decoration: _inputDecoration('First Name'),
                  validator: (val) => val == null || val.isEmpty ? 'Enter first name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _miController,
                  style: const TextStyle(color: textColor),
                  decoration: _inputDecoration('Middle Initial'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastnameController,
                  style: const TextStyle(color: textColor),
                  decoration: _inputDecoration('Last Name'),
                  validator: (val) => val == null || val.isEmpty ? 'Enter last name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _suffixController,
                  style: const TextStyle(color: textColor),
                  decoration: _inputDecoration('Suffix'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _gender,
                  style: const TextStyle(color: textColor),
                  dropdownColor: cardBackground,
                  decoration: _inputDecoration('Gender'),
                  items: ['Male', 'Female', 'Other']
                      .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(color: textColor)),
                  ))
                      .toList(),
                  onChanged: (val) => setState(() => _gender = val),
                  validator: (val) => val == null ? 'Select gender' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _birthdateController,
                  style: const TextStyle(color: textColor),
                  readOnly: true,
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF7F8AA8),
                              surface: cardBackground,
                              onSurface: textColor,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _birthdateController.text =
                        pickedDate.toLocal().toIso8601String().split('T')[0];
                        final now = DateTime.now();
                        int age = now.year - pickedDate.year;
                        if (now.month < pickedDate.month ||
                            (now.month == pickedDate.month && now.day < pickedDate.day)) {
                          age--;
                        }
                        _ageController.text = age.toString();
                      });
                    }
                  },
                  decoration: _inputDecoration('Birthdate (YYYY-MM-DD)'),
                  validator: (val) => val == null || val.isEmpty ? 'Select birthdate' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  style: const TextStyle(color: textColor),
                  readOnly: true,
                  decoration: _inputDecoration('Age'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: textColor),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('Email'),
                  enabled: false, // disable editing
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactNumberController,
                  style: const TextStyle(color: textColor),
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Contact Number'),
                  validator: (val) => val == null || val.isEmpty ? 'Enter contact number' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  style: const TextStyle(color: textColor),
                  decoration: _inputDecoration('Address'),
                  validator: (val) => val == null || val.isEmpty ? 'Enter address' : null,
                ),
                const SizedBox(height: 32),
                _buildGradientButton(
                  onPressed: () {
                    if (_formKeyPage1.currentState!.validate()) {
                      setState(() => _currentStep = 1);
                    }
                  },
                  text: 'Continue',
                  icon: Icons.arrow_forward,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipForm() {
    return Form(
      key: _formKeyPage2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          color: cardBackground.withOpacity(0.7),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Membership Details',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose your membership plan and upload your photo',
                  style: TextStyle(
                    color: Color(0xFFB0B8CC),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _membershipType,
                  decoration: _inputDecoration('Membership Type'),
                  dropdownColor: cardBackground,
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white),
                  items: _membershipTypes
                      .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(color: Colors.white)),
                  ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _membershipType = val;
                      _location = null;
                      _branchCodeController.clear();
                      _availableLocations.clear();
                    });
                    _fetchBranchOptions();
                  },
                  validator: (val) => val == null ? 'Select membership type' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _location,
                  decoration: _inputDecoration('Preferred Location'),
                  dropdownColor: cardBackground,
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white),
                  items: _availableLocations
                      .map((loc) => DropdownMenuItem(
                    value: loc,
                    child: Text(loc, style: const TextStyle(color: Colors.white)),
                  ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _location = val;
                      _branchCodeController.text = _locationToBranchCode[val!] ?? '';
                    });
                  },
                  validator: (val) => val == null ? 'Select location' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _branchCodeController,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Branch Code'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _duration,
                  decoration: _inputDecoration('Duration'),
                  dropdownColor: cardBackground,
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white),
                  items: _durations.map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _duration = val;
                      _updatePrice();
                    });
                  },
                  validator: (val) => val == null ? 'Select duration' : null,
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _paymentType,
                  decoration: _inputDecoration('Payment Type'),
                  dropdownColor: cardBackground,
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white),
                  items: ['Full', 'Partial'].map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _paymentType = val;
                      _updatePrice();
                    });
                  },
                  validator: (val) => val == null ? 'Select payment type' : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _priceController,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Price (₱)'),
                ),

                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: inputFillColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Profile Photo',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _selectedImage == null
                          ? Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: primaryBackground.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: borderColor, style: BorderStyle.solid),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person,
                                color: Color(0xFFB0B8CC), size: 48),
                            SizedBox(height: 8),
                            Text(
                              'No photo selected',
                              style: TextStyle(
                                  color: Color(0xFFB0B8CC), fontSize: 12),
                            ),
                          ],
                        ),
                      )
                          : Container(
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_selectedImage!,
                              fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGradientButton(
                              onPressed: () => _pickImage(true),
                              text: 'Camera',
                              icon: Icons.camera_alt,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildGradientButton(
                              onPressed: () => _pickImage(false),
                              text: 'Gallery',
                              icon: Icons.photo_library,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: _buildGradientButton(
                        onPressed: () => setState(() => _currentStep = 0),
                        text: 'Back',
                        icon: Icons.arrow_back,
                        isSecondary: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGradientButton(
                        onPressed: () {
                          if (_formKeyPage2.currentState!.validate()) {
                            _submitForm();
                          }
                        },
                        text: 'Submit',
                        icon: Icons.check,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}