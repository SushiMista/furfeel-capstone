import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/widgets/dog_avatar.dart';

import 'fakes.dart';

const _biscuit = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');
const _mochi = Dog(id: 'dog-2', ownerUserId: 'user-1', name: 'Mochi');

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('a dog keeps the same tint across separate builds', (tester) async {
    final repo = FakeRepository();

    // Resolved from the avatar's own element: Scaffold and MaterialApp both
    // build Centers internally, so find.byType(Center) is ambiguous here.
    Color tintOf(Dog dog) => dogTint(tester.element(find.byType(DogAvatar)), dog);

    await tester.pumpWidget(_host(DogAvatar(dog: _biscuit, repository: repo)));
    final first = tintOf(_biscuit);

    // Rebuild from scratch — the tint must survive, since it is part of how an
    // owner recognises their dog in a list.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(_host(DogAvatar(dog: _biscuit, repository: repo)));

    expect(tintOf(_biscuit), first);
  });

  testWidgets('the tint comes from the id, not the list position', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(_host(DogAvatar(dog: _biscuit, repository: repo)));
    final context = tester.element(find.byType(DogAvatar));

    // Same dog, different identity object: still the same tint.
    const sameDogRebuilt = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');
    expect(dogTint(context, sameDogRebuilt), dogTint(context, _biscuit));

    // Different dogs draw from the palette rather than all landing on one tint.
    final palette = FurFeelPalette.light;
    final tints = {palette.tintBlue, palette.tintTeal, palette.tintPeriwinkle, palette.tintSlate};
    expect(tints, contains(dogTint(context, _mochi)));
  });

  testWidgets('every shape renders without overflow', (tester) async {
    final repo = FakeRepository();
    for (final shape in DogAvatarShape.values) {
      await tester.pumpWidget(
        _host(DogAvatar(dog: _biscuit, repository: repo, shape: shape)),
      );
      expect(tester.takeException(), isNull, reason: 'shape $shape threw');
    }
  });

  testWidgets('the photoless placeholder is a mark on a tint, never a blank box',
      (tester) async {
    final repo = FakeRepository();
    for (final shape in DogAvatarShape.values) {
      await tester.pumpWidget(
        _host(DogAvatar(dog: _biscuit, repository: repo, shape: shape)),
      );
      expect(find.byType(SvgPicture), findsOneWidget, reason: 'shape $shape lost its mark');
    }
  });

  testWidgets('an explicit backgroundColor still wins over the derived tint',
      (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(
      _host(DogAvatar(dog: _biscuit, repository: repo, backgroundColor: const Color(0xFF123456))),
    );
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, const Color(0xFF123456));
  });
}
