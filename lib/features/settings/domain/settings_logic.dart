import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/ui_kit.dart';

/// Opens [url] in the system browser, telling the user when it can't be done
/// instead of failing silently.
Future<void> openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    if (context.mounted) showAppSnack(context, 'Invalid link.', isError: true);
    return;
  }
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showAppSnack(context, 'Could not open the link.', isError: true);
    }
  } catch (_) {
    if (context.mounted) {
      showAppSnack(context, 'Could not open the link.', isError: true);
    }
  }
}

class StickSetUrl {
  const StickSetUrl._();

  static const String privacyPolicy =
      'https://www.termsfeed.com/live/d522b279-66da-4876-adb0-99bf978f34d9';
  static const String termsOfUse =
      'https://www.termsfeed.com/live/830b24eb-7c46-4cc7-abdc-ef6c50ee5554';
  static const String support = 'https://form.jotform.com/260295634784467';
}
