import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/mobile_access.dart';

void main() {
  test('allows only owner accounts into the mobile app', () {
    expect(mobileAccessErrorForRole('owner'), isNull);
    expect(mobileAccessErrorForRole('admin'), mobileAccessDeniedMessage);
    expect(mobileAccessErrorForRole('vet_staff'), mobileAccessDeniedMessage);
    expect(mobileAccessErrorForRole('veterinarian'), mobileAccessDeniedMessage);
    expect(mobileAccessErrorForRole(null), mobileAccessUnconfirmedMessage);
  });
}
