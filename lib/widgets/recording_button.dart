import 'package:flutter/material.dart';

/// Premium recording button with pulse animation
class RecordingButton extends StatelessWidget {
  final bool isRecording;
  final bool isProcessing;
  final VoidCallback onPressed;
  final AnimationController pulseController;

  const RecordingButton({
    super.key,
    required this.isRecording,
    required this.isProcessing,
    required this.onPressed,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = isRecording || isProcessing;

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF6366F1)
                          .withOpacity(0.3 + pulseController.value * 0.2),
                      blurRadius: 20 + pulseController.value * 10,
                      spreadRadius: 2 + pulseController.value * 3,
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled ? null : onPressed,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  gradient: isDisabled
                      ? const LinearGradient(
                          colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(20),
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
                      Icon(
                        isRecording ? Icons.stop_circle : Icons.mic,
                        size: 32,
                        color: Colors.white,
                      ),
                    const SizedBox(width: 12),
                    Text(
                      _getButtonText(),
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
          ),
        );
      },
    );
  }

  String _getButtonText() {
    if (isProcessing) return 'Processing...';
    if (isRecording) return 'Recording...';
    return 'Start Recording';
  }
}
