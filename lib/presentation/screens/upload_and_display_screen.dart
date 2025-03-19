import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'display_url_screen.dart';
import 'takepic.dart';

class UploadAndDisplayScreen extends StatefulWidget {
  const UploadAndDisplayScreen({super.key});

  @override
  _UploadAndDisplayScreenState createState() => _UploadAndDisplayScreenState();
}

class _UploadAndDisplayScreenState extends State<UploadAndDisplayScreen> {
  File? _selectedImage;
  String? downloadURL;
  bool _isUploading = false;
  bool _showContainer = false;

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        print("No image selected.");
        return;
      }
      setState(() {
        _selectedImage = File(image.path);
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

  imagepicker(BuildContext) async {
    return showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(title: Text('select image'), children: [
          SimpleDialogOption(
            child: const Text('Take Picture'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => TakepicScreen(),
              ));
            },
          ),
          SimpleDialogOption(
              child: const Text('Select from Gallery'),
              onPressed: () {
                Navigator.pop(context);
                _pickAndUploadImage();
              })
        ]);
      },
    );
  }

  Future<void> deleteImage(String docId, String imagePath) async {
    bool confirmDelete = await _showDeleteConfirmation();
    if (!confirmDelete) return;

    try {
      await FirebaseStorage.instance.ref(imagePath).delete();
      await FirebaseFirestore.instance.collection('images').doc(docId).delete();
      print('Image deleted successfully!');
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Delete Image"),
            content: const Text("Are you sure you want to delete this image?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text("Delete", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _toggleContainer() {
    setState(() {
      _showContainer = !_showContainer;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Image')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: () => imagepicker(context),
                  child: Text('Select Image')),
              const SizedBox(height: 20),
              if (_selectedImage != null)
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
                        _selectedImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  SizedBox(
                    height: 20,
                  )
                ]),
              if (downloadURL != null) // Show only if URL is available
                ElevatedButton(
                  onPressed: () => _launchURL(downloadURL!),
                  child: const Text('View in firebase'),
                ),
              if (_isUploading)
                Column(
                  children: [
                    Text("uploading image to firebase... "),
                    SizedBox(
                      height: 15,
                    ),
                    const CircularProgressIndicator(),
                  ],
                )
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
