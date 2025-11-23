import 'package:flutter/material.dart';

/// Upload button with icon
class UploadButton extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onPressed;

  const UploadButton({
    super.key,
    required this.isProcessing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isProcessing ? null : onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            gradient: isProcessing
                ? const LinearGradient(
                    colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isProcessing
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isProcessing)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              else
                const Icon(
                  Icons.upload_file,
                  size: 32,
                  color: Colors.white,
                ),
              const SizedBox(width: 12),
              Text(
                isProcessing ? 'Processing...' : 'Upload Audio File',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
