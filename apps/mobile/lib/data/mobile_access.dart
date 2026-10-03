const mobileAccessDeniedMessage =
    'Access Denied: Clinic staff & admin accounts must log in via the FurFeel Web Dashboard.';

const mobileAccessUnconfirmedMessage =
    'We could not confirm this account is an owner account. Please try again.';

String? mobileAccessErrorForRole(String? role) {
  if (role == 'owner') return null;
  if (role == null) return mobileAccessUnconfirmedMessage;
  return mobileAccessDeniedMessage;
}
