import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme_enhanced.dart';
import '../providers/restaurant_provider.dart';
import '../services/api_service.dart';
import '../widgets/modern_ui_components.dart';
import 'home_screen.dart';
import 'register_screen_modern.dart';
import 'restaurant_setup_screen.dart';

class LoginScreenModern extends StatefulWidget {
  const LoginScreenModern({super.key});

  @override
  State<LoginScreenModern> createState() => _LoginScreenModernState();
}

class _LoginScreenModernState extends State<LoginScreenModern>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  String? _error;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: AppThemeEnhanced.longDuration,
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorToast('Please fill in all fields');
      return;
    }

    final apiService = context.read<ApiService>();
    final restaurantProvider = context.read<RestaurantProvider>();
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      final idToken = await userCredential.user?.getIdToken();
      if (idToken != null) {
        apiService.setToken(idToken);
        await apiService.registerUser(
          _emailController.text.trim(),
          userCredential.user?.displayName ?? 'User',
          userCredential.user!.uid,
        );

        if (!mounted) return;
        await restaurantProvider.loadRestaurant();

        if (!mounted) return;
        if (restaurantProvider.restaurantId == null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const RestaurantSetupScreen(),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            ),
          );
        }

        if (mounted) {
          ModernToast.show(
            context,
            message: 'Welcome back!',
            type: ToastType.success,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseError(e);
    } catch (e) {
      _showErrorToast('An error occurred: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleFirebaseError(FirebaseAuthException e) {
    String message = 'An error occurred';
    switch (e.code) {
      case 'user-not-found':
        message = 'No account found with this email';
        break;
      case 'wrong-password':
        message = 'Incorrect password';
        break;
      case 'invalid-email':
        message = 'Invalid email format';
        break;
      case 'user-disabled':
        message = 'This account has been disabled';
        break;
      case 'too-many-requests':
        message = 'Too many login attempts. Please try later';
        break;
      default:
        message = e.message ?? 'Authentication failed';
    }
    _showErrorToast(message);
  }

  void _showErrorToast(String message) {
    ModernToast.show(
      context,
      message: message,
      type: ToastType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeController,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppThemeEnhanced.background,
                AppThemeEnhanced.secondary.withOpacity(0.1),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppThemeEnhanced.lg),
              child: Column(
                children: [
                  SizedBox(height: isSmallScreen ? 0 : AppThemeEnhanced.xl),
                  // Logo & Branding
                  _buildBranding(isSmallScreen),
                  SizedBox(height: AppThemeEnhanced.xxl),
                  // Login Form Card
                  _buildLoginCard(isSmallScreen),
                  SizedBox(height: AppThemeEnhanced.lg),
                  // Sign Up Link
                  _buildSignUpLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranding(bool isSmallScreen) {
    return Column(
      children: [
        Container(
          width: isSmallScreen ? 60 : 80,
          height: isSmallScreen ? 60 : 80,
          decoration: BoxDecoration(
            gradient: AppThemeEnhanced.primaryGradient,
            borderRadius: BorderRadius.circular(AppThemeEnhanced.radiusXl),
            boxShadow: AppThemeEnhanced.shadowGlow,
          ),
          child: Center(
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: isSmallScreen ? 36 : 48,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: AppThemeEnhanced.lg),
        Text(
          'SmartMenu',
          style: GoogleFonts.hankenGrotesk(
            fontSize: isSmallScreen ? 28 : 36,
            fontWeight: FontWeight.w800,
            color: AppThemeEnhanced.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: AppThemeEnhanced.sm),
        Text(
          'AI-Powered Restaurant Forecasting',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppThemeEnhanced.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginCard(bool isSmallScreen) {
    return ModernCard(
      width: isSmallScreen ? double.infinity : 400,
      padding: EdgeInsets.all(AppThemeEnhanced.lg),
      showGradient: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppThemeEnhanced.textPrimary,
            ),
          ),
          SizedBox(height: AppThemeEnhanced.sm),
          Text(
            'Sign in to manage your restaurant',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppThemeEnhanced.textMuted,
            ),
          ),
          SizedBox(height: AppThemeEnhanced.lg),
          // Email Field
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            enabled: !_isLoading,
          ),
          SizedBox(height: AppThemeEnhanced.md),
          // Password Field
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outlined,
            isPassword: true,
            enabled: !_isLoading,
            onPasswordToggle: () {
              setState(() => _showPassword = !_showPassword);
            },
          ),
          SizedBox(height: AppThemeEnhanced.lg),
          // Login Button
          SizedBox(
            width: double.infinity,
            child: ModernButton(
              label: 'Sign In',
              onPressed: _login,
              isLoading: _isLoading,
              isEnabled: !_isLoading,
              icon: Icons.login_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool enabled = true,
    VoidCallback? onPasswordToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppThemeEnhanced.textSecondary,
          ),
        ),
        SizedBox(height: AppThemeEnhanced.xs),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: isPassword && !_showPassword,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppThemeEnhanced.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppThemeEnhanced.primary),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: AppThemeEnhanced.textMuted,
                    ),
                    onPressed: onPasswordToggle,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppThemeEnhanced.radiusMd),
              borderSide: BorderSide(
                color: AppThemeEnhanced.divider,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppThemeEnhanced.radiusMd),
              borderSide: BorderSide(
                color: AppThemeEnhanced.divider,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppThemeEnhanced.radiusMd),
              borderSide: BorderSide(
                color: AppThemeEnhanced.primary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: AppThemeEnhanced.surfaceLight,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppThemeEnhanced.md,
              vertical: AppThemeEnhanced.md,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppThemeEnhanced.textMuted,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreenModern()),
          ),
          child: Text(
            'Sign Up',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppThemeEnhanced.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
