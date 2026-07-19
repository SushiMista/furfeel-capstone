import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/util/errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('errorCause names the true cause per error family', () {
    expect(errorCause(Exception('SocketException: Failed host lookup')),
        contains('offline'));
    expect(errorCause(const AuthException('JWT expired')),
        contains('session has expired'));
    expect(
        errorCause(const PostgrestException(
            message: 'permission denied for table dogs', code: '42501')),
        contains("doesn't have permission"));
    expect(errorCause(const PostgrestException(message: 'duplicate key')),
        contains('duplicate key'));
    expect(errorCause(TimeoutException('slow')), contains('timed out'));
    expect(errorCause(StateError('bug')), contains('unexpected'));
  });

  test('message builders compose readable owner copy', () {
    final load = loadErrorMessage(TimeoutException('t'), 'history');
    expect(load, "Couldn't load history — the connection timed out. Pull to retry.");
    final action = actionErrorMessage(TimeoutException('t'), 'Sending');
    expect(action,
        "Sending didn't go through — the connection timed out. Please try again.");
  });
}
