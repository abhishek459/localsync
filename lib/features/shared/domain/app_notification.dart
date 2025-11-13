import 'package:flutter/foundation.dart';

/// Defines the severity of the notification, so the UI can react appropriately.
enum NotificationType {
  /// A simple, non-blocking notification (e.g., SnackBar).
  toast,

  /// A blocking notification that requires user acknowledgment (e.g., Dialog).
  dialog,

  /// A critical, app-breaking error (e.g., navigate to a dedicated error screen).
  critical,

  /// A notification for a successful operation (e.g., green SnackBar).
  success,

  /// An informational notification (e.g., default SnackBar).
  info,
}

/// A data class to hold rich notification information.
@immutable
class AppNotification {
  const AppNotification({
    required this.message,
    this.originalError,
    this.type = NotificationType.toast,
    this.stackTrace,
  });

  /// The user-friendly message to be shown in the UI.
  final String message;

  /// The original Exception or Error object, if one exists.
  final Object? originalError;

  /// The severity/type of the notification.
  final NotificationType type;

  /// The StackTrace, if one exists.
  final StackTrace? stackTrace;

  @override
  String toString() {
    if (originalError != null) {
      return 'AppNotification(message: $message, type: $type, error: $originalError)';
    }
    return 'AppNotification(message: $message, type: $type)';
  }
}
