import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton service for logging mobile app owner events to public.audit_logs.
class AuditService {
  AuditService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Records an audit log event asynchronously.
  /// Fails silently to ensure user experience is never blocked.
  static Future<void> logEvent({
    required String action,
    required String targetResource,
    String? targetId,
    String? clinicId,
    Map<String, dynamic>? details,
    String severity = 'info',
  }) async {
    try {
      final user = _client.auth.currentUser;
      final actorId = user?.id;
      final actorEmail = user?.email ?? 'owner@mobile.app';

      await _client.from('audit_logs').insert({
        'actor_id': actorId,
        'actor_email': actorEmail,
        'actor_role': 'owner',
        'surface': 'mobile',
        'action': action,
        'target_resource': targetResource,
        'target_id': targetId,
        'clinic_id': clinicId,
        'details': details ?? {},
        'severity': severity,
      });
    } catch (e) {
      debugPrint('AuditService log error: $e');
    }
  }
}
