import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final envFile = File('env.json');
  final text = envFile.readAsStringSync();
  final urlMatch = RegExp(r'"SUPABASE_URL"\s*:\s*"([^"]+)"').firstMatch(text);
  final keyMatch = RegExp(r'"SUPABASE_ANON_KEY"\s*:\s*"([^"]+)"').firstMatch(text);
  
  final url = urlMatch!.group(1)!;
  final key = keyMatch!.group(1)!;
  
  final client = SupabaseClient(url, key);
  
  try {
    print('Attempting to sign up...');
    final response = await client.auth.signUp(
      email: 'test_signup_agent_4@furfeel.site',
      password: 'TestPassword123!',
      data: {'name': 'Agent Test'}
    );
    print('Success! Session is null? ${response.session == null}');
  } catch (e, st) {
    print('Error: $e');
    print('StackTrace: $st');
  }
  exit(0);
}
