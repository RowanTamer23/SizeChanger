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
  File? _TakenImage;
  String? downloadURL;
  bool _isUploading = false;
  bool _showContainer = false;

  Future<void> _TakeAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) {
        print("No image selected.");
        return;
      }

      setState(() {
        _TakenImage = File(image.path);
      });

      await _uploadImageToFirebase(image.path);
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _uploadImageToFirebase(String imagePath) async {
    try {
      setState(() {
        _isUploading = true;
      });
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage
          .ref()
          .child('images/${DateTime.now().millisecondsSinceEpoch}.jpg');

      File imageFile = File(imagePath);
      await ref.putFile(imageFile);

      String url = await ref.getDownloadURL();
      print("Image uploaded! Download URL: $url");

      if (mounted) {
        setState(() {
          downloadURL = url;
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
      });
      print('Error uploading image: $e');
    }
  }

  void _toggleContainer() {
    setState(() {
      _showContainer = !_showContainer;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take Picture')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _TakeAndUploadImage,
                child: const Text('Take Picture'),
              ),
              if (_TakenImage != null)
                Column(children: [
                  ElevatedButton(
                    onPressed: _toggleContainer,
                    child: Text(_showContainer ? 'hide' : 'show'),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  if (_showContainer)
                    Container(
                      width: 400,
                      height: 250,
                      alignment: Alignment.center,
                      child: Image.file(
                        _TakenImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  SizedBox(
                    height: 20,
                  )
                ]),
              const SizedBox(height: 20),
              if (downloadURL != null) // Show only if URL is available
                ElevatedButton(
                  onPressed: () => _launchURL(downloadURL!),
                  child: const Text('View'),
                ),
              if (_isUploading) const CircularProgressIndicator()
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }
}
