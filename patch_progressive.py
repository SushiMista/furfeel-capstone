import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# 1. Add state variables for obscure
if "bool _obscurePassword = true;" not in content:
    content = content.replace("  String _otp = '';", "  String _otp = '';\n  bool _obscurePassword = true;\n  bool _obscureConfirm = true;")

# 2. Add Login page import if missing
if "import 'package:furfeel_mobile/screens/auth/login_page.dart';" not in content:
    content = content.replace("import 'package:furfeel_mobile/main.dart';", "import 'package:furfeel_mobile/main.dart';\nimport 'package:furfeel_mobile/screens/auth/login_page.dart';")

# 3. Update the error message in _createAccount
content = content.replace(
    "_error = 'Account already exists. Please log in instead.';",
    "_error = 'This email is already registered. Log in instead.';"
)

# 4. Replace _buildCreateAccount
import re
build_create_account_pattern = re.compile(r'  Widget _buildCreateAccount\(\) \{.*?(?=  Widget _buildOtp\(\) \{)', re.DOTALL)

new_build_create_account = """  Widget _buildRequirementRow(String text, bool met) {
    return Row(
      children: [
        Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, 
             color: met ? Colors.green : Colors.grey, size: 16),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: met ? Colors.green : Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildCreateAccount() {
    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    final isEmailValid = emailRegex.hasMatch(_emailCtrl.text.trim());
    
    final pass = _passwordCtrl.text;
    final hasLength = pass.length >= 8;
    final hasUpper = pass.contains(RegExp(r'[A-Z]'));
    final hasLower = pass.contains(RegExp(r'[a-z]'));
    final hasNumber = pass.contains(RegExp(r'[0-9]'));
    final hasSpecial = pass.contains(RegExp(r'[!@#\$%\^&\*~`\(\)\-_\+=\[\]\{\}\|;:,.<>\/?]'));
    
    int strengthCount = 0;
    if (hasLength) strengthCount++;
    if (hasUpper) strengthCount++;
    if (hasLower) strengthCount++;
    if (hasNumber) strengthCount++;
    if (hasSpecial) strengthCount++;
    
    String strengthLabel = 'Weak';
    Color strengthColor = Colors.red;
    if (strengthCount >= 3 && strengthCount < 5) {
       strengthLabel = 'Medium';
       strengthColor = Colors.orange;
    } else if (strengthCount == 5) {
       strengthLabel = 'Strong';
       strengthColor = Colors.green;
    }
    
    final isPasswordStrong = strengthCount == 5;
    final passwordsMatch = pass == _confirmCtrl.text && pass.isNotEmpty;
    
    final canContinue = isEmailValid && isPasswordStrong && passwordsMatch;

    return _buildStepContainer(
      title: "Almost there! 🎉",
      subtitle: "Secure your account.",
      canContinue: canContinue,
      onContinue: _createAccount,
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState((){}),
              decoration: InputDecoration(
                 labelText: 'Email', 
                 border: const OutlineInputBorder(),
                 errorText: (_emailCtrl.text.isNotEmpty && !isEmailValid) ? 'Enter a valid email address' : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              onChanged: (_) => setState((){}),
              decoration: InputDecoration(
                labelText: 'Password', 
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              ),
            ),
            const SizedBox(height: 8),
            if (pass.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: strengthColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(strengthLabel, style: TextStyle(color: strengthColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ]
              ),
              const SizedBox(height: 8),
              _buildRequirementRow('8+ characters', hasLength),
              const SizedBox(height: 4),
              _buildRequirementRow('Uppercase letter', hasUpper),
              const SizedBox(height: 4),
              _buildRequirementRow('Lowercase letter', hasLower),
              const SizedBox(height: 4),
              _buildRequirementRow('Number', hasNumber),
              const SizedBox(height: 4),
              _buildRequirementRow('Special character', hasSpecial),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              onChanged: (_) => setState((){}),
              decoration: InputDecoration(
                labelText: 'Confirm Password', 
                border: const OutlineInputBorder(),
                errorText: (_confirmCtrl.text.isNotEmpty && !passwordsMatch) ? 'Passwords do not match' : null,
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                )
              ),
            ),
            if (_error != null && _error!.contains('This email is already registered')) ...[
               const SizedBox(height: 16),
               TextButton(
                  onPressed: () {
                     // Pop back to Welcome Page so they can login.
                     Navigator.of(context).pop();
                  },
                  child: Text('Log in instead', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.ff.brand)),
               )
            ],
            const SizedBox(height: 32),
            const OrDivider(),
            const SizedBox(height: 16),
            GoogleSignInButton(
              busy: _busy,
              onPressed: _signInWithGoogle,
            ),
          ],
        ),
      ),
    );
  }
"""

content = build_create_account_pattern.sub(new_build_create_account, content)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
