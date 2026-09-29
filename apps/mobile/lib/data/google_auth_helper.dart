import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const _googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

/// Performs native Google Sign-In on iOS/Android, and standard OAuth on Web.
Future<AuthResponse?> performGoogleSignIn(SupabaseClient client) async {
  // 1. On Web: Use standard browser OAuth redirect flow
  if (kIsWeb || _googleWebClientId.isEmpty) {
    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : 'io.furfeel.app://login-callback',
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      queryParams: {'prompt': 'select_account'},
    );
    return null;
  }

  // 2. On Mobile (Android & iOS): Native Google Sign-In SDK
  final googleSignIn = GoogleSignIn(
    serverClientId: _googleWebClientId,
    clientId: _googleIosClientId.isNotEmpty ? _googleIosClientId : null,
  );

  // Clear any cached account so the system always displays the account chooser dialog
  try {
    await googleSignIn.signOut();
  } catch (_) {}

  final googleUser = await googleSignIn.signIn();
  if (googleUser == null) {
    // User cancelled
    return null;
  }

  final googleAuth = await googleUser.authentication;
  final accessToken = googleAuth.accessToken;
  final idToken = googleAuth.idToken;

  if (idToken == null) {
    throw const AuthException('No Google ID Token found from Google sign-in.');
  }

  return await client.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
    accessToken: accessToken,
  );
}
