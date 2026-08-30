import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

req_row = """  Widget _buildRequirementRow(String text, bool met) {
    return Row(
      children: [
        Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, 
             color: met ? Colors.green : Colors.grey, size: 16),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: met ? Colors.green : Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildCreateAccount() {"""

content = content.replace("  Widget _buildCreateAccount() {", req_row)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
