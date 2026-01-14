import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveUserToPreferences({
  required String firstname,
  required String membershipType,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isLoggedIn', true);
  await prefs.setString('firstname', firstname);
  await prefs.setString('membershipType', membershipType);
}

Future<void> clearUserPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}
