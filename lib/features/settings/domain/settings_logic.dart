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
  static const String setone =
      'https://www.termsfeed.com/live/d522b279-66da-4876-adb0-99bf978f34d9';
  static const String settwo =
      'https://www.termsfeed.com/live/830b24eb-7c46-4cc7-abdc-ef6c50ee5554';
  static const String setthree = 'https://form.jotform.com/260295634784467';
}
