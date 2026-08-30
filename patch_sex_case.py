import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

old_draft = """      await repo.createDog(DogDraft(
        name: _dogName,
        sex: _dogSex.isEmpty ? null : _dogSex,
        breed: _dogBreed.isEmpty ? null : _dogBreed,
        birthdate: birthdate,
        weightKg: weightKg > 0 ? weightKg : null,
      ));"""

new_draft = """      await repo.createDog(DogDraft(
        name: _dogName,
        sex: _dogSex.isEmpty ? null : _dogSex.toLowerCase(),
        breed: _dogBreed.isEmpty ? null : _dogBreed,
        birthdate: birthdate,
        weightKg: weightKg > 0 ? weightKg : null,
      ));"""

content = content.replace(old_draft, new_draft)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
