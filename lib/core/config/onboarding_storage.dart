import 'package:shared_preferences/shared_preferences.dart';

const _keyOnboardingCompleted = 'onboarding_completed';

Future<bool> getOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keyOnboardingCompleted) ?? false;
}

Future<void> setOnboardingCompleted(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keyOnboardingCompleted, value);
}
