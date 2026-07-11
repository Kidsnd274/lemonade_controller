import 'package:flutter/material.dart';

/// Runs [action] and surfaces any thrown exception to the user as a SnackBar.
///
/// Load/unload/download-control calls are triggered fire-and-forget from the
/// UI. Without this, a thrown [LemonadeApiException] (or any other error)
/// becomes an uncaught async error and the user gets no feedback that the
/// action failed — the spinner simply clears.
Future<void> runWithErrorFeedback(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
