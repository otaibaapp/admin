import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import 'loading_dialog.dart';

class AddToFirebaseDatabase extends StatefulWidget {
  const AddToFirebaseDatabase({super.key});

  @override
  State<AddToFirebaseDatabase> createState() => _AddToFirebaseDatabaseState();
}

class _AddToFirebaseDatabaseState extends State<AddToFirebaseDatabase> {
  final TextEditingController source = TextEditingController();
  final TextEditingController content = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String imagePathContent = "";
  String imagePathSourceUrl = "";

  void displaySnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _pickImage(bool isContentImage) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      displaySnackBar('لم يتم اختيار صورة', Colors.red);
      return;
    }

    setState(() {
      _imageFile = File(pickedFile.path);
    });

    await _uploadImage(isContentImage);
  }

  Future<void> _uploadImage(bool isContentImage) async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String fileName = path.basename(_imageFile!.path);
      Reference firebaseStorageRef = FirebaseStorage.instance.ref().child(
        'otaibah_main/announcements/${DateTime.now().millisecondsSinceEpoch}/$fileName',
      );

      UploadTask uploadTask = firebaseStorageRef.putFile(_imageFile!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        if (isContentImage) {
          imagePathContent = downloadUrl;
        } else {
          imagePathSourceUrl = downloadUrl;
        }
      });

      displaySnackBar('تم رفع الصورة بنجاح ✅', Colors.green);
    } on FirebaseException catch (e) {
      displaySnackBar('فشل رفع الصورة: ${e.message}', Colors.red);
    } catch (e) {
      displaySnackBar('حدث خطأ أثناء رفع الصورة', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> add() async {
    if (source.text.isEmpty) {
      displaySnackBar('يرجى كتابة مصدر الإعلان!', Colors.red);
      return;
    }

    if (content.text.isEmpty) {
      displaySnackBar('يرجى كتابة محتوى الإعلان!', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final ref = FirebaseDatabase.instance.ref('otaibah_announcements').push();
      DateTime date = DateTime.now();
      String formattedDate = "${date.year}/${date.month}/${date.day}";

      await ref.set({
        'source': source.text,
        'dateOfPost': formattedDate,
        'sourceImageUrl': imagePathSourceUrl,
        'content': content.text,
        'contentImgUrl': imagePathContent,
        'numberOfComments': 0,
        'numberOfLoved': 0,
        'id': ref.key,
      });

      setState(() {
        _isLoading = false;
        source.clear();
        content.clear();
        imagePathContent = "";
        imagePathSourceUrl = "";
      });

      displaySnackBar('تمت إضافة الإعلان بنجاح 🎉', Colors.green);
    } on FirebaseException catch (e) {
      displaySnackBar('خطأ من Firebase: ${e.message}', Colors.red);
    } catch (e) {
      displaySnackBar('حدث خطأ أثناء الإضافة', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('إضافة إعلان جديد', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // مصدر الإعلان
              TextField(
                textAlign: TextAlign.right,
                controller: source,
                decoration: InputDecoration(
                  hintText: 'مصدر الإعلان',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),

              const SizedBox(height: 24),

              // محتوى الإعلان
              TextField(
                textAlign: TextAlign.right,
                controller: content,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: '...محتوى الإعلان',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),

              const SizedBox(height: 24),

              // زر اختيار صورة الإعلان
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(true),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('اختيار صورة الإعلان'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF988561),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // زر اختيار صورة المصدر
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(false),
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('اختيار صورة مصدر الإعلان'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF988561),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // زر الإضافة
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLoading ? null : add,
                  child: _isLoading
                      ? const LoadingDialog(msg: 'جاري الإضافة...')
                      : const Text('إضافة الإعلان', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
