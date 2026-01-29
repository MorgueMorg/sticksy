import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void stickWbLnch(BuildContext context, String djlrf) async {
  final Uri ssla = Uri.parse(djlrf);
  if (!await launchUrl(ssla)) {
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(
      // ignore: use_build_context_synchronously
      context,
    ).showSnackBar(SnackBar(content: Text('Could not launch $ssla')));
  }
}

class StickSetUrl {
  static const String setone = 'https://pub.dev/';
  static const String settwo = 'https://pub.dev/';
  static const String setthree = 'https://pub.dev/';
}
