import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

old_otp = """  Widget _buildOtp() {
    return _buildStepContainer(
      title: "Check your email",
      subtitle: "We sent a 6-digit code to $_email.",
      onContinue: _verifyOtp,
      canContinue: _otp.length == 6,
      child: Column(
        children: [
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            style: const TextStyle(fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              counterText: '',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _otp = v.trim()),
            onSubmitted: (_) { if (_otp.length == 6) _verifyOtp(); },
          ),
        ],
      ),
    );
  }"""

new_otp = """  Widget _buildOtp() {
    return _buildStepContainer(
      title: "Check your email",
      subtitle: "If $_email is new, we just sent a 6-digit code.",
      onContinue: _verifyOtp,
      canContinue: _otp.length == 6,
      child: Column(
        children: [
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            style: const TextStyle(fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              counterText: '',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _otp = v.trim()),
            onSubmitted: (_) { if (_otp.length == 6) _verifyOtp(); },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.ff.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  "Didn't receive a code?",
                  style: TextStyle(fontWeight: FontWeight.bold, color: context.ff.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  "If you already have an account with us, no code will be sent for security reasons.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: context.ff.inkMuted, height: 1.4),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(), // Pops back to WelcomePage to Log In
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    foregroundColor: context.ff.brand,
                    side: BorderSide(color: context.ff.brand.withValues(alpha: 0.5)),
                  ),
                  child: const Text('Log in instead'),
                )
              ],
            ),
          )
        ],
      ),
    );
  }"""

content = content.replace(old_otp, new_otp)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
