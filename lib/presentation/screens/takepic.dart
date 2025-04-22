import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'display_url_screen.dart';

class TakepicScreen extends StatefulWidget {
  const TakepicScreen({super.key});

  @override
  _TakepicScreenState createState() => _TakepicScreenState();
}

class _TakepicScreenState extends State<TakepicScreen> {
  File? _takenImage;
  String? _downloadUrl;
  bool _isUploading = false;
  bool _showContainer = false;
  String? _errorMessage;

  Future<void> _takeAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        maxWidth: 1920,
      );

      if (image == null) {
        _showError('No image was selected');
        return;
      }

      setState(() {
        _takenImage = File(image.path);
        _errorMessage = null;
      });

      await _uploadImageToFirebase(image.path);
    } catch (e) {
      _showError('Error taking picture: $e');
    }
  }

  Future<void> _uploadImageToFirebase(String imagePath) async {
    try {
      setState(() {
        _isUploading = true;
        _errorMessage = null;
      });

      final storage = FirebaseStorage.instance;
      final ref = storage
          .ref()
          .child('images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final imageFile = File(imagePath);

      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _downloadUrl = url;
          _isUploading = false;
        });
      }

      await FirebaseFirestore.instance.collection('images').add({
        'url': url,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DisplayURLScreen(downloadURL: url),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Error uploading image: $e';
      });
    }
  }

  void _toggleContainer() {
    setState(() {
      _showContainer = !_showContainer;
    });
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Picture'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _takeAndUploadImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Picture'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              if (_takenImage != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _toggleContainer,
                  child: Text(_showContainer ? 'Hide Preview' : 'Show Preview'),
                ),
                const SizedBox(height: 20),
                if (_showContainer)
                  Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.file(
                        _takenImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              if (_downloadUrl != null)
                ElevatedButton.icon(
                  onPressed: () => _launchURL(_downloadUrl!),
                  icon: const Icon(Icons.link),
                  label: const Text('View Uploaded Image'),
                ),
              if (_isUploading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }
}
