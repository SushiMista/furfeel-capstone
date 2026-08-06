import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/widgets/brand_photo_frame.dart';
import 'package:furfeel_mobile/widgets/dog_avatar.dart' show DogAvatarShape;

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('falls back to the tinted mark when the asset is missing',
      (tester) async {
    await tester.pumpWidget(_host(const BrandPhotoFrame(
      asset: 'assets/photos/does_not_exist_yet.jpg',
    )));
    // Let the failed asset load resolve to the errorBuilder.
    await tester.pump();

    expect(find.byIcon(Icons.pets), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an arch frame is taller than it is wide', (tester) async {
    await tester.pumpWidget(_host(const BrandPhotoFrame(
      asset: 'assets/photos/does_not_exist_yet.jpg',
      shape: DogAvatarShape.arch,
      width: 200,
    )));
    final size = tester.getSize(find.byType(BrandPhotoFrame));
    expect(size.height, greaterThan(size.width));
  });

  testWidgets('a decorative frame (no label) is excluded from semantics',
      (tester) async {
    await tester.pumpWidget(_host(const BrandPhotoFrame(
      asset: 'assets/photos/does_not_exist_yet.jpg',
      shape: DogAvatarShape.squircle,
    )));
    final size = tester.getSize(find.byType(BrandPhotoFrame));
    expect(size.height, size.width);
  });
}
