import 'package:flutter/material.dart';

enum AppNotificationType { success, warning, info, error }

class CustomAppNotification extends StatelessWidget {
  final AppNotificationType type;
  final String title;
  final String message;
  final VoidCallback? onClose;

  const CustomAppNotification({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.onClose,
  });

  // Colors based on type
  Color _backgroundColor() {
    switch (type) {
      case AppNotificationType.success:
        return const Color(0xFFDFF6DD);
      case AppNotificationType.warning:
        return const Color(0xFFFFF4CC);
      case AppNotificationType.info:
        return const Color(0xFFDDEBFF);
      case AppNotificationType.error:
        return const Color(0xFFFDE2E1);
    }
  }

  IconData _icon() {
    switch (type) {
      case AppNotificationType.success:
        return Icons.check_circle_rounded;
      case AppNotificationType.warning:
        return Icons.warning_amber_rounded;
      case AppNotificationType.info:
        return Icons.info_rounded;
      case AppNotificationType.error:
        return Icons.error_rounded;
    }
  }

  Color _iconColor() {
    switch (type) {
      case AppNotificationType.success:
        return Colors.green.shade700;
      case AppNotificationType.warning:
        return Colors.orange.shade700;
      case AppNotificationType.info:
        return Colors.blue.shade700;
      case AppNotificationType.error:
        return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center( // Center agar posisi di tengah (atau bisa Align topCenter)
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          // 🟢 Membatasi lebar agar standar seperti notif web
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: _backgroundColor(),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon(), color: _iconColor(), size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _iconColor(),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          color: _iconColor().withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onClose != null)
                  GestureDetector(
                    onTap: onClose,
                    child: Icon(Icons.close, color: _iconColor(), size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}