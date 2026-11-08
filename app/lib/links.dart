import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openExternal(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {
    /* The source address remains available in the information dialog. */
  }
  if (messenger.mounted) {
    messenger.showSnackBar(const SnackBar(content: Text('暂时无法打开链接，请稍后重试。')));
  }
}
