import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DisplayURLScreen extends StatelessWidget {
  final String downloadURL;

  const DisplayURLScreen({super.key, required this.downloadURL});

  Future<void> _launchURL(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image URL')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Image uploaded successfully!'),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _launchURL(context, downloadURL),
              child: Text(
                'Click to view image',
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
