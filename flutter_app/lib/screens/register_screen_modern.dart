import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme_enhanced.dart';
import '../services/api_service.dart';
import '../widgets/modern_ui_components.dart';
import 'restaurant_setup_screen_modern.dart';

class RegisterScreenModern extends StatefulWidget {
  const RegisterScreenModern({super.key});

  @override
  State<RegisterScreenModern> createState() => _RegisterScreenModernState();
}

class _RegisterScreenModernState extends State<RegisterScreenModern>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _error;
  String? _successMessage;

  // Form validation states
  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  bool _passwordsMatch = false;
  bool _isNameValid = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppThemeEnhanced.mediumDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        );

    _controller.forward();

    // Add listeners for real-time validation
    _emailController.addListener(_validateEmail);
    _nameController.addListener(_validateName);
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _validateEmail() {
    setState(() {
      _isEmailValid = _isValidEmail(_emailController.text.trim());
    });
  }

  void _validateName() {
    setState(() {
      _isNameValid = _nameController.text.trim().isNotEmpty &&
          _nameController.text.trim().length >= 2;
    });
  }

  void _validatePassword() {
    setState(() {
      _isPasswordValid = _passwordController.text.length >= 6;
      _passwordsMatch = _passwordController.text ==
              _confirmPasswordController.text &&
          _confirmPasswordController.text.isNotEmpty;
    });
  }

  bool _isValidEmail(String email) {
    return email.contains('@') && email.contains('.');
  }

  bool _isFormValid() {
    return _isNameValid &&
        _isEmailValid &&
        _isPasswordValid &&
        _passwordsMatch &&
        !_isLoading;
  }

  Future<void> _register() async {
    // Final validation
    if (!_isFormValid()) {
      _showErrorToast('Please fill in all fields correctly');
      return;
    }

    final apiService = context.read<ApiService>();
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      // Create user with Firebase
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      final idToken = await userCredential.user?.getIdToken();
      final firebaseUid = userCredential.user?.uid;

      if (idToken == null || firebaseUid == null) {
        throw Exception('Failed to authenticate new user');
      }

      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      // Register with backend API
      apiService.setToken(idToken);
      await apiService.registerUser(
        _emailController.text.trim(),
        _nameController.text.trim(),
        firebaseUid,
      );

      TextInput.finishAutofillContext(shouldSave: true);

      if (mounted) {
        ModernToast.show(
          context,
          message: 'Account created successfully!',
          type: ToastType.success,
        );

        // Navigate to restaurant setup
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => RestaurantSetupScreenModern(userToken: idToken),
              ),
            );
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      final errorMsg = _handleFirebaseError(e.code);
      if (mounted) {
        _showErrorToast(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        _showErrorToast('An error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _handleFirebaseError(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password is too weak. Use 6+ characters.';
      case 'email-already-in-use':
        return 'Email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Registration is temporarily disabled.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      default:
        return 'Registration failed. Please try again.';
    }
  }

  void _showErrorToast(String message) {
    ModernToast.show(
      context,
      message: message,
      type: ToastType.error,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    Widget? suffixIcon,
    List<String>? autofillHints,
    bool isValid = false,
    TextInputAction textInputAction = TextInputAction.next,
    VoidCallback? onSubmit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppThemeEnhanced.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppThemeEnhanced.textDark,
                ),
              ),
              const SizedBox(width: 4),
              if (controller.text.isNotEmpty)
                Icon(
                  isValid ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: isValid
                      ? AppThemeEnhanced.successColor
                      : AppThemeEnhanced.errorColor,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            autofillHints: autofillHints,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon),
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppThemeEnhanced.borderRadius),
                borderSide: BorderSide(
                  color: controller.text.isEmpty
                      ? AppThemeEnhanced.inputBorder
                      : (isValid
                          ? AppThemeEnhanced.successColor
                          : AppThemeEnhanced.errorColor),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppThemeEnhanced.borderRadius),
                borderSide: BorderSide(
                  color: controller.text.isEmpty
                      ? AppThemeEnhanced.inputBorder
                      : (isValid
                          ? AppThemeEnhanced.successColor
                          : AppThemeEnhanced.errorColor),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppThemeEnhanced.borderRadius),
                borderSide: BorderSide(
                  color: AppThemeEnhanced.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            keyboardType: keyboardType,
            obscureText: obscureText,
            textInputAction: textInputAction,
            onSubmitted: (_) => onSubmit?.call(),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool showPassword,
    required VoidCallback onToggle,
    required bool isValid,
  }) {
    return _buildTextField(
      controller: controller,
      label: label,
      hint: hint,
      icon: Icons.lock_outline,
      obscureText: !showPassword,
      suffixIcon: IconButton(
        icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
        onPressed: onToggle,
      ),
      autofillHints: const [AutofillHints.newPassword],
      isValid: isValid,
      textInputAction:
          label == 'Password' ? TextInputAction.next : TextInputAction.done,
    );
  }

  Widget _buildBranding() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppThemeEnhanced.primaryColor,
                  AppThemeEnhanced.accentColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.circular(AppThemeEnhanced.borderRadiusLarge),
              boxShadow: AppThemeEnhanced.shadowGlow,
            ),
            child: const Icon(
              Icons.restaurant,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: AppThemeEnhanced.lg),
          Text(
            'SmartMenu',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppThemeEnhanced.primaryColor,
            ),
          ),
          const SizedBox(height: AppThemeEnhanced.sm),
          Text(
            'Create your restaurant account',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppThemeEnhanced.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterCard() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Your name',
                      icon: Icons.person_outline,
                      autofillHints: const [AutofillHints.name],
                      isValid: _isNameValid,
                    ),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'your@email.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.email,
                        AutofillHints.newUsername,
                      ],
                      isValid: _isEmailValid,
                    ),
                    _buildPasswordField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'At least 6 characters',
                      showPassword: _showPassword,
                      onToggle: () =>
                          setState(() => _showPassword = !_showPassword),
                      isValid: _isPasswordValid,
                    ),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      hint: 'Re-enter your password',
                      showPassword: _showConfirmPassword,
                      onToggle: () => setState(
                          () => _showConfirmPassword = !_showConfirmPassword),
                      isValid: _passwordsMatch,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppThemeEnhanced.lg),
              ModernButton(
                label: _isLoading ? 'Creating Account...' : 'Create Account',
                onPressed: _isFormValid() ? () => _register() : null,
                isLoading: _isLoading,
                gradient: LinearGradient(
                  colors: [
                    AppThemeEnhanced.primaryColor,
                    AppThemeEnhanced.accentColor,
                  ],
                ),
              ),
              const SizedBox(height: AppThemeEnhanced.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppThemeEnhanced.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Login',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppThemeEnhanced.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeEnhanced.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppThemeEnhanced.lg,
              vertical: AppThemeEnhanced.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBranding(),
                  const SizedBox(height: AppThemeEnhanced.xxl),
                  _buildRegisterCard(),
                  const SizedBox(height: AppThemeEnhanced.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppThemeEnhanced.md),
                    child: Text(
                      'By creating an account, you agree to our Terms of Service and Privacy Policy',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppThemeEnhanced.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
