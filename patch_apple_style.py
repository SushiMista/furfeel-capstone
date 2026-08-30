import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# 1. Remove Emojis
content = content.replace("Let's get you set up 👋", "Let's get you set up")
content = content.replace("what's your dog's name? 🐶", "what's your dog's name?")
content = content.replace("Almost there! 🎉", "Almost there")
content = content.replace("You're all set! 🐾", "You're all set")

# 2. Thin out progress bar
content = content.replace("height: 6,", "height: 3,")

# 3. Refine _buildStepContainer Typography
old_step_container = """            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.ff.brandInk,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: FurFeelTokens.space2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: context.ff.inkMuted,
                ),
              ),
            ],"""

new_step_container = """            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: context.ff.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: FurFeelTokens.space3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: context.ff.inkMuted,
                  height: 1.3,
                ),
              ),
            ],"""
content = content.replace(old_step_container, new_step_container)

# 4. Refine _buildSelectionCard to be minimal Apple style (solid color when selected)
old_selection_card_pattern = re.compile(r'  Widget _buildSelectionCard.*?Widget _buildDogSex', re.DOTALL)

new_selection_card = """  Widget _buildSelectionCard(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: isSelected ? context.ff.brand : context.ff.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: isSelected ? Colors.white : context.ff.inkMuted),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : context.ff.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDogSex"""

content = old_selection_card_pattern.sub(new_selection_card, content)

# 5. Refine ChoiceChips for Breed
old_chip_pattern = re.compile(r"ChoiceChip\([\s\S]*?padding: const EdgeInsets\.symmetric\(horizontal: 12, vertical: 8\),[\s\S]*?onSelected: \(val\) \{[\s\S]*?\},[\s\S]*?\)\)\.toList\(\),")

new_chip = """ChoiceChip(
              label: Text(b, style: TextStyle(fontSize: 16, color: _dogBreed == b ? Colors.white : context.ff.ink, fontWeight: FontWeight.w500)),
              selected: _dogBreed == b,
              selectedColor: context.ff.brand,
              backgroundColor: context.ff.surfaceAlt,
              showCheckmark: false,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onSelected: (val) {
                if (val) {
                  setState(() { _dogBreed = b; _dogBreedCtrl.text = b; });
                  Future.delayed(250.ms, _next);
                }
              },
            )).toList(),"""
content = old_chip_pattern.sub(new_chip, content)


# 6. Refine TextFields in _buildCreateAccount to use softer borders
content = content.replace("border: const OutlineInputBorder(),", "border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.ff.surfaceAlt)),\n                 enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.ff.surfaceAlt)),")

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
