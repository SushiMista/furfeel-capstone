import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# Replace _buildDogName to _buildDogWeight with the new implementations
pattern = re.compile(r'  Widget _buildDogName\(\) \{.*?(?=  Widget _buildCreateAccount\(\) \{)', re.DOTALL)

new_builders = """  Widget _buildDogName() {
    return _buildStepContainer(
      title: "What's your dog's name? 🐶",
      canContinue: _dogName.isNotEmpty,
      onContinue: _next,
      child: Column(
        children: [
          TextField(
            controller: _dogNameCtrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: "Dog's name",
              border: InputBorder.none,
            ),
            onChanged: (v) => setState(() => _dogName = v.trim()),
            onSubmitted: (_) { if (_dogName.isNotEmpty) _next(); },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).extension<FurFeelPalette>()!.brand.withValues(alpha: 0.1) : Theme.of(context).extension<FurFeelPalette>()!.surfaceAlt,
          border: Border.all(
            color: isSelected ? Theme.of(context).extension<FurFeelPalette>()!.brand : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: isSelected ? Theme.of(context).extension<FurFeelPalette>()!.brand : Theme.of(context).extension<FurFeelPalette>()!.inkMuted),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Theme.of(context).extension<FurFeelPalette>()!.brand : Theme.of(context).extension<FurFeelPalette>()!.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDogSex() {
    return _buildStepContainer(
      title: "Is $_dogName a boy or a girl?",
      canContinue: _dogSex.isNotEmpty,
      onContinue: _next,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSelectionCard('Male', Icons.male, _dogSex == 'Male', () {
            setState(() => _dogSex = 'Male');
            Future.delayed(250.ms, _next);
          }),
          _buildSelectionCard('Female', Icons.female, _dogSex == 'Female', () {
            setState(() => _dogSex = 'Female');
            Future.delayed(250.ms, _next);
          }),
        ],
      ),
    );
  }

  Widget _buildDogBreed() {
    return _buildStepContainer(
      title: "What breed is $_dogName?",
      canContinue: _dogBreed.isNotEmpty,
      onContinue: _next,
      child: Column(
        children: [
          TextField(
            controller: _dogBreedCtrl,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: 'e.g. Golden Retriever',
              border: InputBorder.none,
            ),
            onChanged: (v) => setState(() => _dogBreed = v.trim()),
            onSubmitted: (_) { if (_dogBreed.isNotEmpty) _next(); },
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              'Mixed breed', 'Labrador', 'Golden Retriever', 'French Bulldog', 'German Shepherd', 'Poodle'
            ].map((b) => ChoiceChip(
              label: Text(b, style: const TextStyle(fontSize: 16)),
              selected: _dogBreed == b,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onSelected: (val) {
                if (val) {
                  setState(() { _dogBreed = b; _dogBreedCtrl.text = b; });
                  Future.delayed(250.ms, _next);
                }
              },
            )).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildDogAge() {
    final ages = ['1 month', '2 months', '3 months', '4 months', '5 months', '6 months', '7 months', '8 months', '9 months', '10 months', '11 months'];
    for (int i = 1; i <= 25; i++) {
      ages.add('$i ${i == 1 ? 'year' : 'years'}');
    }

    return _buildStepContainer(
      title: "How old is $_dogName?",
      canContinue: true,
      onContinue: _next,
      child: SizedBox(
        height: 240,
        child: CupertinoPicker(
          itemExtent: 56,
          scrollController: FixedExtentScrollController(initialItem: _ageIndex),
          onSelectedItemChanged: (index) => setState(() => _ageIndex = index),
          children: ages.asMap().entries.map((entry) {
            final isSelected = entry.key == _ageIndex;
            return Center(
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: isSelected ? 28 : 22,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Theme.of(context).extension<FurFeelPalette>()!.brandInk : Theme.of(context).extension<FurFeelPalette>()!.inkMuted,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDogWeight() {
    return _buildStepContainer(
      title: "How much does $_dogName weigh?",
      canContinue: true,
      onContinue: _next,
      child: Column(
        children: [
          SizedBox(
            width: 200,
            child: CupertinoSlidingSegmentedControl<bool>(
              groupValue: _isKg,
              children: const {
                true: Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Text('KG', style: TextStyle(fontWeight: FontWeight.bold))),
                false: Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Text('LBS', style: TextStyle(fontWeight: FontWeight.bold))),
              },
              onValueChanged: (val) {
                if (val != null) {
                  setState(() {
                    if (val) {
                      _weightValue = (_weightValue / 2.20462).round();
                    } else {
                      _weightValue = (_weightValue * 2.20462).round();
                    }
                    if (_weightValue < 1) _weightValue = 1;
                    _isKg = val;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 240,
            child: CupertinoPicker.builder(
              key: ValueKey(_isKg),
              itemExtent: 56,
              childCount: _isKg ? 100 : 250,
              scrollController: FixedExtentScrollController(initialItem: _weightValue - 1),
              onSelectedItemChanged: (index) => setState(() => _weightValue = index + 1),
              itemBuilder: (context, index) {
                final isSelected = (index + 1) == _weightValue;
                return Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: isSelected ? 40 : 28,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                      color: isSelected ? Theme.of(context).extension<FurFeelPalette>()!.brandInk : Theme.of(context).extension<FurFeelPalette>()!.inkMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

"""

content = pattern.sub(new_builders, content)

# I should also update _buildName to center the text field like _buildDogName
name_pattern = re.compile(r'  Widget _buildName\(\) \{.*?(?=  Widget _buildDogName\(\) \{)', re.DOTALL)
new_build_name = """  Widget _buildName() {
    return _buildStepContainer(
      title: "What's your name?",
      subtitle: "We'll use this to personalize your experience.",
      canContinue: _userName.isNotEmpty,
      onContinue: _next,
      child: Column(
        children: [
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: 'Your name',
              border: InputBorder.none,
            ),
            onChanged: (v) => setState(() => _userName = v.trim()),
            onSubmitted: (_) { if (_userName.isNotEmpty) _next(); },
          ),
        ],
      ),
    );
  }

"""
content = name_pattern.sub(new_build_name, content)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
