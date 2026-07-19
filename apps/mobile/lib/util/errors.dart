import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// ADDED (improvement pass): one place that turns a caught error into copy
/// naming the true cause (docs/04 error-state audit) instead of a blanket
/// "something went wrong". Wording stays warm and observational; the server's
/// own message is included only when it genuinely helps.
///
/// Returns a lowercase clause that reads after a dash:
/// "Couldn't load history — you're offline or FurFeel can't be reached."
String errorCause(Object error) {
  // String matching for network failures keeps this web-safe (no dart:io) and
  // catches the http package's ClientException wrappers too.
  const networkMarkers = [
    'SocketException',
    'ClientException',
    'Failed host lookup',
    'Connection refused',
    'Connection reset',
    'Connection closed',
    'Network is unreachable',
    'XMLHttpRequest',
  ];
  if (error is AuthException) {
    return 'your session has expired, please sign out and back in';
  }
  if (error is PostgrestException) {
    final message = error.message;
    if (error.code == '42501' ||
        message.contains('row-level security') ||
        message.contains('permission denied')) {
      return "this account doesn't have permission for that";
    }
    return 'the server rejected the request ($message)';
  }
  if (error is StorageException) {
    return 'file storage error (${error.message})';
  }
  if (error is TimeoutException) {
    return 'the connection timed out';
  }
  final text = error.toString();
  if (networkMarkers.any(text.contains)) {
    return "you're offline or FurFeel can't be reached";
  }
  return 'an unexpected error occurred';
}

/// Standard load-failure copy for pull-to-refresh screens.
String loadErrorMessage(Object error, String what) =>
    "Couldn't load $what — ${errorCause(error)}. Pull to retry.";

/// Standard action-failure copy for buttons/saves.
String actionErrorMessage(Object error, String action) =>
    "$action didn't go through — ${errorCause(error)}. Please try again.";
