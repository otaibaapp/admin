import 'package:flutter/material.dart';

class LoadingDialog extends StatelessWidget {
  final String msg;

  const LoadingDialog({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF988561)),
              ),
              const SizedBox(height: 20),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
