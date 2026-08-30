import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/main.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/widgets/auth_form.dart';
import 'package:furfeel_mobile/widgets/auth_pattern_background.dart';

class ProgressiveSignUpPage extends StatefulWidget {
  const ProgressiveSignUpPage({super.key, required this.client});
  final SupabaseClient client;

  @override
  State<ProgressiveSignUpPage> createState() => _ProgressiveSignUpPageState();
}

class _ProgressiveSignUpPageState extends State<ProgressiveSignUpPage> {
  final _pageController = PageController();
  int _currentIndex = 0;
  bool _busy = false;
  String? _error;
  
  late final StreamSubscription<AuthState> _authStateSub;
  bool _dogSaved = false;

  // State
  String _userName = '';
  String _dogName = '';
  String _dogSex = '';
  String _dogBreed = '';
  int _ageIndex = 11; // Default to '1 year'
  bool _isKg = true;
  int _weightValue = 10;
  String _email = '';
  String _password = '';
  String _otp = '';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _dogNameCtrl = TextEditingController();
  final _dogBreedCtrl = TextEditingController();
  final _dogAgeCtrl = TextEditingController();
  final _dogWeightCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  void _next() async {
    FocusScope.of(context).unfocus();
    _error = null;
    
    // Backup state to SharedPreferences in case OS kills app during Google OAuth
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('backup_dog_name', _dogName);
    prefs.setString('backup_dog_sex', _dogSex);
    prefs.setString('backup_dog_breed', _dogBreed);
    prefs.setInt('backup_dog_age_index', _ageIndex);
    prefs.setBool('backup_dog_is_kg', _isKg);
    prefs.setInt('backup_dog_weight', _weightValue);

    if (_currentIndex < 9) {
      _pageController.nextPage(duration: 400.ms, curve: Curves.easeOutCubic);
      setState(() => _currentIndex++);
    }
  }

  void _back() {
    FocusScope.of(context).unfocus();
    _error = null;
    if (_currentIndex > 0) {
      _pageController.previousPage(duration: 400.ms, curve: Curves.easeOutCubic);
      setState(() => _currentIndex--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      await widget.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'io.furfeel.app://login-callback',
        authScreenLaunchMode: LaunchMode.platformDefault,
        queryParams: {'prompt': 'select_account'},
      );
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _busy = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not start Google sign-in. Check your connection.'; _busy = false; });
    }
  }

  Future<void> _createAccount() async {
    _email = _emailCtrl.text.trim();
    _password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (_email.isEmpty || _password.length < 8) {
      setState(() => _error = 'Please enter a valid email and at least 8 characters for password.');
      return;
    }
    if (_password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await widget.client.auth.signUp(
        email: _email,
        password: _password,
        data: {'name': _userName},
      );
      if (!mounted) return;
      
      if (response.session == null) {
        // Needs OTP
        _pageController.animateToPage(8, duration: 400.ms, curve: Curves.easeOutCubic);
        setState(() {
          _currentIndex = 8;
          _busy = false;
        });
      } else {
        // Authenticated (e.g. if email confirmation is disabled)
        await _handleSuccessfulAuth();
      }
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('user already registered')) {
        setState(() {
          _error = 'This email is already registered. Log in instead.';
          _busy = false;
        });
        return;
      }
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _busy = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    _otp = _otpCtrl.text.trim();
    if (_otp.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await widget.client.auth.verifyOTP(
        type: OtpType.signup,
        email: _email,
        token: _otp,
      );
      if (!mounted) return;
      
      if (response.session != null) {
        await _handleSuccessfulAuth();
      } else {
        setState(() {
          _error = 'Verification failed. Try again.';
          _busy = false;
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not verify code.';
        _busy = false;
      });
    }
  }

  Future<void> _saveDogProfile() async {
    try {
      final repo = SupabaseFurFeelRepository(widget.client);
      final weightKg = _isKg ? _weightValue.toDouble() : _weightValue / 2.20462;
      
      // Calculate approx birthdate from ageIndex
      // 0-10 are months 1-11. 11+ are years 1-25.
      int daysToSubtract = 0;
      if (_ageIndex <= 10) {
        daysToSubtract = (_ageIndex + 1) * 30;
      } else {
        daysToSubtract = (_ageIndex - 10) * 365;
      }
      final birthdate = DateTime.now().subtract(Duration(days: daysToSubtract)).toIso8601String();

      await repo.createDog(DogDraft(
        name: _dogName,
        sex: _dogSex.isEmpty ? null : _dogSex.toLowerCase(),
        breed: _dogBreed.isEmpty ? null : _dogBreed,
        birthdate: birthdate,
        weightKg: weightKg > 0 ? weightKg : null,
      ));
    } catch (e) {
      debugPrint('Failed to save dog profile: $e');
      if (mounted) setState(() => _error = 'Failed to save dog: $e');
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    FurFeelApp.isProgressiveOnboarding = true;
    _authStateSub = widget.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        _handleSuccessfulAuth();
      }
    });
  }

  bool _isSavingDog = false;

  Future<void> _handleSuccessfulAuth() async {
    if (_dogSaved || _isSavingDog) return;
    _isSavingDog = true; // Lock immediately to prevent race conditions
    setState(() => _busy = true);
    
    // If state was lost (OS kill), attempt restore from backup
    if (_dogName.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _dogName = prefs.getString('backup_dog_name') ?? '';
      _dogSex = prefs.getString('backup_dog_sex') ?? '';
      _dogBreed = prefs.getString('backup_dog_breed') ?? '';
      _ageIndex = prefs.getInt('backup_dog_age_index') ?? 0;
      _isKg = prefs.getBool('backup_dog_is_kg') ?? true;
      _weightValue = prefs.getInt('backup_dog_weight') ?? 10;
    }

    // Safety check
    if (_dogName.isEmpty) {
       _dogSaved = true;
       if (!mounted) return;
       _pageController.animateToPage(9, duration: 400.ms, curve: Curves.easeOutCubic);
       setState(() {
         _currentIndex = 9;
         _busy = false;
       });
       return;
    }

    try {
      await _saveDogProfile();
      _dogSaved = true;
      
      // Clean up the temporary backup now that it's safely in the database
      final prefs = await SharedPreferences.getInstance();
      for (final key in ['backup_dog_name', 'backup_dog_sex', 'backup_dog_breed', 'backup_dog_age_index', 'backup_dog_is_kg', 'backup_dog_weight']) {
        prefs.remove(key);
      }
      
      if (!mounted) return;
      _pageController.animateToPage(9, duration: 400.ms, curve: Curves.easeOutCubic);
      setState(() {
        _currentIndex = 9;
        _busy = false;
      });
    } catch (e) {
      _isSavingDog = false; // Unlock so they can retry
      setState(() { _busy = false; _error = 'Could not save dog: $e'; });
    }
  }

  @override
  void dispose() {
    _authStateSub.cancel();
    FurFeelApp.isProgressiveOnboarding = false;
    _pageController.dispose();
    _nameCtrl.dispose();
    _dogNameCtrl.dispose();
    _dogBreedCtrl.dispose();
    _dogAgeCtrl.dispose();
    _dogWeightCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Widget _buildStepContainer({
    required String title,
    String? subtitle,
    required Widget child,
    required VoidCallback onContinue,
    bool canContinue = true,
    bool showBack = true,
  }) {
    final textTheme = Theme.of(context).textTheme;
    
    // Calculate progress based on current index
    double progress = 0.0;
    switch (_currentIndex) {
      case 0: progress = 0.0; break;
      case 1: progress = 0.60; break;
      case 2: progress = 0.70; break;
      case 3: progress = 0.75; break;
      case 4: progress = 0.80; break;
      case 5: progress = 0.85; break;
      case 6: progress = 0.90; break;
      case 7: progress = 0.95; break;
      case 8: progress = 0.98; break;
      case 9: progress = 1.00; break;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showBack)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _busy ? null : _back,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              )
            else
              const SizedBox(height: 48),
            
            const SizedBox(height: FurFeelTokens.space2),
            
            // 1. Large question/title
            Text(
              title,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.ff.brandInk,
              ),
            ).animate().fadeIn().slideY(begin: 0.1, duration: 400.ms),
            
            // 2. Optional short supporting text
            if (subtitle != null) ...[
              const SizedBox(height: FurFeelTokens.space2),
              Text(
                subtitle,
                style: textTheme.titleMedium?.copyWith(
                  color: context.ff.inkMuted,
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, duration: 400.ms),
            ],
            
            // 3. Progress bar (Only show if past welcome)
            if (_currentIndex > 0) ...[
              const SizedBox(height: FurFeelTokens.space5),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        width: constraints.maxWidth,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.ff.hairline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: 500.ms,
                        curve: Curves.easeOutCubic,
                        height: 8,
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          color: context.ff.brand,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  );
                },
              ).animate().fadeIn(delay: 100.ms),
            ],
            
            // 4. Interactive input/selector
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: child,
                ),
              ),
            ),
            
            // Inline error if any
            if (_error != null) ...[
              InlineFormError(message: _error!),
              const SizedBox(height: FurFeelTokens.space4),
            ],
            
            // 5. Continue button
            ElevatedButton(
              onPressed: canContinue && !_busy ? onContinue : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: context.ff.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd)),
                elevation: 0,
              ),
              child: _busy
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, duration: 400.ms),
            const SizedBox(height: FurFeelTokens.space3),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ff.surface,
      body: AuthPatternBackground(
        color: context.ff.hairline,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildWelcome(),
            _buildName(),
            _buildDogName(),
            _buildDogSex(),
            _buildDogBreed(),
            _buildDogAge(),
            _buildDogWeight(),
            _buildCreateAccount(),
            _buildOtp(),
            _buildCompletion(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return _buildStepContainer(
      title: "Let's get you set up",
      subtitle: "It'll only take a minute.",
      showBack: true, // They can go back to WelcomePage
      onContinue: _next,
      child: Center(
        child: Image.asset('assets/photos/app_logo.png', width: 160).animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.easeOutBack),
      ),
    );
  }

  Widget _buildName() {
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
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
            
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

  Widget _buildDogName() {
    return _buildStepContainer(
      title: "Hi ${_userName.split(' ').first},\nwhat's your dog's name?",
      canContinue: _dogName.isNotEmpty,
      onContinue: _next,
      child: Column(
        children: [
          TextField(
            controller: _dogNameCtrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
            
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
            
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
            
            children: [
              'Mixed breed', 'Labrador', 'Golden Retriever', 'French Bulldog', 'German Shepherd', 'Poodle'
            ].map((b) => ChoiceChip(
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
                  color: isSelected ? context.ff.brandInk : context.ff.inkMuted,
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
                      color: isSelected ? context.ff.brandInk : context.ff.inkMuted,
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

  Widget _buildRequirementRow(String text, bool met) {
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
      title: "Almost there",
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
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.ff.surfaceAlt)),
                 enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.ff.surfaceAlt)),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.ff.surfaceAlt)),
                 enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.ff.surfaceAlt)),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.ff.surfaceAlt)),
                 enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.ff.surfaceAlt)),
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
  Widget _buildOtp() {
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
  }

  Widget _buildCompletion() {
    return _buildStepContainer(
      title: "You're all set",
      subtitle: "$_dogName's profile is ready.",
      showBack: false,
      onContinue: () {
        // Pop all the way to root shell
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Center(
        child: const Icon(Icons.check_circle, size: 100, color: Colors.green)
            .animate().scale(delay: 100.ms, curve: Curves.easeOutBack),
      ),
    );
  }
}
