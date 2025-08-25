import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import 'loading_dialog.dart';

class AddToFirebaseDatabase extends StatefulWidget {
  const AddToFirebaseDatabase({super.key});

  @override
  State<AddToFirebaseDatabase> createState() => _AddToFirebaseDatabaseState();
}

class _AddToFirebaseDatabaseState extends State<AddToFirebaseDatabase> {
  TextEditingController? source = TextEditingController(),
      sourceImageUrl = TextEditingController(),
      content = TextEditingController(),
      contentImgUrl = TextEditingController(),
      numberOfComments = TextEditingController(),
      numberOfLoved = TextEditingController(),
      buttonContent = TextEditingController(),
      buttonContentUrl = TextEditingController();
  bool _isLoading = false;
  String imagePathContent = "";
  String? selectedColor;
  String imagePathSourceUrl = "";
  List<String> navigation_menu_items = [
    'ads',
    'shop',
    'orders',
    'services',
    'education',
    'donations',
  ];
  String? _selectedValue;
  String aaaaa = 'برتقال';
  void displaySnackBar(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _databaseRef = FirebaseDatabase.instance.ref('otaibah_navigators_taps');
  }

  DatabaseReference? _databaseRef;
  @override
  Widget build(BuildContext context) {
    File? _imageFile;
    final ImagePicker _picker = ImagePicker();
    bool _isUploading = false;
    String? _uploadStatusMessage;

    // 2. قائمة الخيارات

    Future<void> uploadImageContent() async {
      if (_imageFile == null) {
        displaySnackBar('الرجاء اختيار صورة أولاً!', Colors.red);
        imagePathContent = "";
      }

      setState(() {
        _isUploading = true;
        _uploadStatusMessage = 'جاري رفع الصورة...';
      });

      try {
        // إنشاء مسار فريد للملف
        String fileName = path.basename(_imageFile!.path);
        Reference firebaseStorageRef = FirebaseStorage.instance.ref().child(
          'otaibah_main/navigation_menu_items/' + aaaaa + fileName,
        );

        // رفع الملف
        UploadTask uploadTask = firebaseStorageRef.putFile(_imageFile!);
        TaskSnapshot taskSnapshot = await uploadTask;

        // الحصول على رابط التنزيل
        imagePathContent = await taskSnapshot.ref.getDownloadURL();

        setState(() {
          _isUploading = false;
          _uploadStatusMessage =
              'تم الرفع بنجاح! رابط الصورة: $imagePathContent';
        });

        displaySnackBar('تم الرفع بنجاح!', Colors.green);
      } on FirebaseException catch (e) {
        setState(() {
          _isUploading = false;
          _uploadStatusMessage = 'فشل الرفع: ${e.message}';
        });
        displaySnackBar('فشل الرفع: ${e.message}', Colors.red);
        imagePathContent = "";
      }
    }

    // 1. دالة لاختيار الصورة من المعرض
    Future<void> _pickImageContent() async {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          if (_imageFile != null) {
            uploadImageContent();
          }
          _uploadStatusMessage = null; // إعادة تعيين الرسالة
        });
      } else {
        displaySnackBar('No image', Colors.red);
      }
      if (_imageFile == null) {
        displaySnackBar('age', Colors.red);
      }
    }

    Future<void> uploadImageSource() async {
      if (_imageFile == null) {
        displaySnackBar('الرجاء اختيار صورة أولاً!', Colors.red);
        imagePathSourceUrl = "";
      }

      setState(() {
        _isUploading = true;
        _uploadStatusMessage = 'جاري رفع الصورة...';
      });

      try {
        // إنشاء مسار فريد للملف
        String fileName = path.basename(_imageFile!.path);
        Reference firebaseStorageRef = FirebaseStorage.instance.ref().child(
          'otaibah_main/navigation_menu_items/' + aaaaa + fileName,
        );

        // رفع الملف
        UploadTask uploadTask = firebaseStorageRef.putFile(_imageFile!);
        TaskSnapshot taskSnapshot = await uploadTask;

        // الحصول على رابط التنزيل
        imagePathSourceUrl = await taskSnapshot.ref.getDownloadURL();
        setState(() {
          _isUploading = false;
          _uploadStatusMessage =
              'تم الرفع بنجاح! رابط الصورة: $imagePathSourceUrl';
        });

        displaySnackBar('تم الرفع بنجاح!', Colors.green);
      } on FirebaseException catch (e) {
        setState(() {
          _isUploading = false;
          _uploadStatusMessage = 'فشل الرفع: ${e.message}';
        });
        displaySnackBar('فشل الرفع: ${e.message}', Colors.red);
        imagePathSourceUrl = "";
      }
    }

    // 1. دالة لاختيار الصورة من المعرض
    Future<void> _pickImageSource() async {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          if (_imageFile != null) {
            uploadImageSource();
          }
          _uploadStatusMessage = null; // إعادة تعيين الرسالة
        });
      } else {
        displaySnackBar('No image', Colors.red);
      }
      if (_imageFile == null) {
        displaySnackBar('age', Colors.red);
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  DropdownButton<String>(
                    // القيمة الحالية المختارة
                    value: _selectedValue,

                    // تلميح يظهر عندما لا يتم اختيار أي قيمة
                    hint: Text('اختر قيمة'),

                    // الدالة التي يتم استدعاؤها عند تغيير القيمة
                    onChanged: (String? newValue) {
                      // تحديث حالة الودجت باستخدام setState
                      setState(() {
                        _selectedValue = newValue;
                        aaaaa = newValue.toString();
                      });
                    },

                    // قائمة العناصر التي تظهر في القائمة المنسدلة
                    items: navigation_menu_items.map<DropdownMenuItem<String>>((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  // عرض القيمة المختارة
                ],
              ),

              const SizedBox(height: 40),
              // Logo
              SvgPicture.asset(
                'assets/svg/app_logo.svg',
                height: 40,
                width: 40,
              ),
              const SizedBox(height: 8),
              const Text(
                'بلدة العتيبة',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              const Text(
                'صفحة إضافة البيانات إلى قاعدة البيانات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              // Full Name
              TextField(
                textAlign: TextAlign.right,
                obscureText: false,
                controller: source,
                decoration: InputDecoration(
                  hintText: 'مصدر الإعلان',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Email
              TextField(
                textAlign: TextAlign.right,
                obscureText: false,
                controller: sourceImageUrl,
                decoration: InputDecoration(
                  hintText: 'رابط صورة المصدر',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 16),

              // Password
              TextField(
                textAlign: TextAlign.right,
                obscureText: false,
                controller: content,
                decoration: InputDecoration(
                  hintText: 'محتوى الإعلان',
                  prefixIcon: Icon(Icons.fingerprint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 16),

              // Confirm Password
              TextField(
                textAlign: TextAlign.right,
                obscureText: false,
                controller: contentImgUrl,
                decoration: InputDecoration(
                  hintText: 'رابط الصورة لمحتوى الإعلان إن وجد',
                  prefixIcon: Icon(Icons.fingerprint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              TextField(
                textAlign: TextAlign.right,
                obscureText: false,
                controller: buttonContent,
                decoration: InputDecoration(
                  hintText: 'محتوى الزر الظاهري إن وجد',
                  prefixIcon: Icon(Icons.fingerprint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              TextField(
                textAlign: TextAlign.right,
                obscureText: false,
                controller: buttonContentUrl,
                decoration: InputDecoration(
                  hintText: 'رابط محتوى الزر إن وجد',
                  prefixIcon: Icon(Icons.fingerprint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _pickImageContent,
                icon: const Icon(Icons.photo_library),
                label: const Text('اختر صورة المحتوى ان وجد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickImageSource,
                icon: const Icon(Icons.photo_library),
                label: const Text('اختر صورة مصدر الاعلان'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 20),
              // Register Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    add();
                  },
                  child: !_isLoading
                      ? Text('إضافة', style: TextStyle(fontSize: 16))
                      : LoadingDialog(msg: 'جاري الإضافة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> add() async {
    if (true) {
      setState(() {
        _isLoading = true;
      });
      try {
        // إنشاء مفتاح فريد للعنصر الجديد
        final a = FirebaseDatabase.instance
            .ref('otaibah_navigators_taps')
            .child(aaaaa)
            .push();
        // البيانات التي تريد إضافتها
        await a.set({
          'source': source?.text,
          'dateOfPost': DateTime.now().toString(),
          'sourceImageUrl': imagePathSourceUrl,
          'content': content?.text,
          'contentImgUrl': imagePathContent,
          'numberOfComments': 21,
          'numberOfLoved': 9,
          'buttonContent': buttonContent?.text,
          'buttonContentUrl': buttonContentUrl?.text,
          'id': a.key,
        });

        setState(() {
          _isLoading = false;
        });
        displaySnackBar('تمت الإضافة بنجاح', Colors.green);
      } on FirebaseException catch (e) {
        setState(() {
          _isLoading = false;
        });
        //Future.delayed(Duration.zero);
        //Navigator.of(context, rootNavigator: true).pop();
        displaySnackBar(e.toString(), Colors.red);
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        //Future.delayed(Duration.zero);
        //Navigator.of(context, rootNavigator: true).pop();
        displaySnackBar(e.toString(), Colors.red);
      }
    } else {
      displaySnackBar('خطأ في فيربيز', Colors.red);
    }
  }
}
