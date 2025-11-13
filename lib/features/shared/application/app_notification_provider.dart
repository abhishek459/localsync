import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:local_sync/features/shared/domain/app_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_notification_provider.g.dart';

/// A single, app-wide stream controller for broadcasting notifications.
/// This is managed internally and not exposed via a provider.
final _notificationStreamController =
    StreamController<AppNotification>.broadcast();

/// A provider that exposes the stream of application notifications.
///
/// The UI (e.g., `main.dart`) will listen to this stream to show
/// SnackBars or Dialogs.
@Riverpod(keepAlive: true)
Stream<AppNotification> appNotificationStream(Ref ref) {
  /// Dispose the controller when the app closes.
  ref.onDispose(() {
    _notificationStreamController.close();
  });

  /// Return the stream for the UI to listen to.
  return _notificationStreamController.stream;
}

/// A utility class to globally report notifications to the `appNotificationStreamProvider`.
///
/// This decouples the "reporting" of a notification (from any feature)
/// from the "handling" of that notification (in the main UI).
class NotificationReporter {
  /// The core method to add an [AppNotification] to the stream.
  ///
  /// This is also a great place to hook in centralized logging
  /// (e.g., to Sentry, Firebase, etc.).
  static void report(AppNotification notification) {
    // Log the error to the console for debugging if it's an error
    if (notification.originalError != null) {
      debugPrint(notification.toString());
      if (notification.stackTrace != null) {
        debugPrint(notification.stackTrace.toString());
      }
    }

    // Add the notification to the stream for the UI to handle
    _notificationStreamController.add(notification);
  }

  /// Helper for reporting when you have an `Exception`/`Error` object.
  ///
  /// Use this in `try-catch` blocks or for `AsyncError` states from Riverpod.
  /// [userFriendlyMessage] is optional. If not provided, `error.toString()` is used.
  static void reportError(
    Object error, {
    StackTrace? stack,
    NotificationType type = NotificationType.toast,
    String? userFriendlyMessage,
  }) {
    final message = userFriendlyMessage ?? error.toString();

    report(
      AppNotification(
        message: message,
        originalError: error,
        stackTrace: stack,
        type: type,
      ),
    );
  }

  /// Helper for reporting simple string messages.
  ///
  /// Use this for business logic failures (e.g., "Invalid password")
  /// or simple notifications where no `Exception` was thrown.
  static void reportMessage(
    String message, {
    NotificationType type = NotificationType.toast,
  }) {
    report(
      AppNotification(
        message: message,
        originalError: null,
        stackTrace: null,
        type: type,
      ),
    );
  }

  /// Helper for reporting simple success messages.
  static void reportSuccess(String message) {
    report(AppNotification(message: message, type: NotificationType.success));
  }

  /// Helper for reporting simple informational messages.
  static void reportInfo(String message) {
    report(AppNotification(message: message, type: NotificationType.info));
  }
}
