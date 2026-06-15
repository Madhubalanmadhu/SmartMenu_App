import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme_enhanced.dart';
import '../providers/restaurant_provider.dart';
import '../services/api_service.dart';
import '../widgets/modern_ui_components.dart';
import 'home_screen_modern.dart';

class RestaurantSetupScreenModern extends StatefulWidget {
  final String userToken;

  const RestaurantSetupScreenModern({super.key, required this.userToken});

  @override
  State<RestaurantSetupScreenModern> createState() =>
      _RestaurantSetupScreenModernState();
}

class _RestaurantSetupScreenModernState extends State<RestaurantSetupScreenModern>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;

  int _currentStep = 0;
  int _totalSteps = 3;

  // Step 1: Basic Info
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();

  // Step 2: Location & Weather
  final _addressController = TextEditingController();
  final _weatherCityController = TextEditingController();
  final _countryCodeController = TextEditingController(text: 'IN');

  // Step 3: Contact Info
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  // Validation states
  bool _nameValid = false;
  bool _typeValid = false;
  bool _addressValid = false;
  bool _weatherCityValid = false;
  bool _countryCodeValid = false;
  bool _phoneValid = false;
  bool _emailValid = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      duration: AppThemeEnhanced.mediumDuration,
      vsync: this,
    );
    _fadeController.forward();

    // Add listeners for validation
    _nameController.addListener(_validateStep1);
    _typeController.addListener(_validateStep1);
    _addressController.addListener(_validateStep2);
    _weatherCityController.addListener(_validateStep2);
    _countryCodeController.addListener(_validateStep2);
    _phoneController.addListener(_validateStep3);
    _emailController.addListener(_validateStep3);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _nameController.dispose();
    _typeController.dispose();
    _addressController.dispose();
    _weatherCityController.dispose();
    _countryCodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _validateStep1() {
    setState(() {
      _nameValid = _nameController.text.trim().isNotEmpty;
      _typeValid = _typeController.text.trim().isNotEmpty;
    });
  }

  void _validateStep2() {
    setState(() {
      _addressValid = _addressController.text.trim().isNotEmpty;
      _weatherCityValid = _weatherCityController.text.trim().isNotEmpty;
      _countryCodeValid =
          _countryCodeController.text.trim().isNotEmpty &&
              _countryCodeController.text.trim().length == 2;
    });
  }

  void _validateStep3() {
    setState(() {
      _phoneValid = _phoneController.text.trim().isNotEmpty &&
          _phoneController.text.trim().length >= 10;
      _emailValid = _isValidEmail(_emailController.text.trim());
    });
  }

  bool _isValidEmail(String email) {
    return email.contains('@') && email.contains('.');
  }

  bool _isStep1Valid() => _nameValid && _typeValid;
  bool _isStep2Valid() => _addressValid && _weatherCityValid && _countryCodeValid;
  bool _isStep3Valid() => _phoneValid && _emailValid;

  Future<void> _setupRestaurant() async {
    if (!_isStep1Valid() || !_isStep2Valid() || !_isStep3Valid()) {
      ModernToast.show(
        context,
        message: 'Please fill in all required fields',
        type: ToastType.error,
      );
      return;
    }

    final apiService = context.read<ApiService>();
    final restaurantProvider = context.read<RestaurantProvider>();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final restaurant = await apiService.createRestaurant(
        widget.userToken,
        _nameController.text.trim(),
        _typeController.text.trim(),
        _addressController.text.trim(),
        _phoneController.text.trim(),
        _emailController.text.trim(),
        weatherCity: _weatherCityController.text.trim(),
        countryCode: _countryCodeController.text.trim().toUpperCase(),
      );

      restaurantProvider.setRestaurant(restaurant);

      if (mounted) {
        ModernToast.show(
          context,
          message: 'Restaurant setup complete!',
          type: ToastType.success,
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreenModern()),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ModernToast.show(
          context,
          message: 'Failed to create restaurant: ${e.toString()}',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && !_isStep1Valid()) {
      ModernToast.show(
        context,
        message: 'Please fill in all fields',
        type: ToastType.warning,
      );
      return;
    }
    if (_currentStep == 1 && !_isStep2Valid()) {
      ModernToast.show(
        context,
        message: 'Please fill in all fields correctly',
        type: ToastType.warning,
      );
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: AppThemeEnhanced.mediumDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: AppThemeEnhanced.mediumDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isValid = false,
    int maxLines = 1,
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
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon),
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
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppThemeEnhanced.lg,
          vertical: AppThemeEnhanced.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Restaurant Basics',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppThemeEnhanced.textDark,
              ),
            ),
            const SizedBox(height: AppThemeEnhanced.sm),
            Text(
              'Tell us about your restaurant',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppThemeEnhanced.textSecondary,
              ),
            ),
            const SizedBox(height: AppThemeEnhanced.xxl),
            _buildTextField(
              controller: _nameController,
              label: 'Restaurant Name',
              hint: 'e.g. Madras Spice House',
              icon: Icons.restaurant_outlined,
              isValid: _nameValid,
            ),
            _buildTextField(
              controller: _typeController,
              label: 'Food Style',
              hint: 'e.g. South Indian, Biryani, Cafe',
              icon: Icons.category_outlined,
              isValid: _typeValid,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppThemeEnhanced.lg,
          vertical: AppThemeEnhanced.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Location & Weather',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppThemeEnhanced.textDark,
              ),
            ),
            const SizedBox(height: AppThemeEnhanced.sm),
            Text(
              'Help us predict weather impacts on your menu',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppThemeEnhanced.textSecondary,
              ),
            ),
            const SizedBox(height: AppThemeEnhanced.xxl),
            _buildTextField(
              controller: _addressController,
              label: 'Address',
              hint: 'Full restaurant address',
              icon: Icons.location_on_outlined,
              isValid: _addressValid,
              maxLines: 2,
            ),
            _buildTextField(
              controller: _weatherCityController,
              label: 'Forecast City',
              hint: 'e.g. Chennai, Mumbai',
              icon: Icons.cloud_queue_outlined,
              isValid: _weatherCityValid,
            ),
            _buildTextField(
              controller: _countryCodeController,
              label: 'Country Code',
              hint: 'IN, US, UK',
              icon: Icons.public_outlined,
              isValid: _countryCodeValid,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppThemeEnhanced.lg,
          vertical: AppThemeEnhanced.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Contact Information',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppThemeEnhanced.textDark,
              ),
            ),
            const SizedBox(height: AppThemeEnhanced.sm),
            Text(
              'How can we reach your restaurant?',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppThemeEnhanced.textSecondary,
              ),
            ),
            const SizedBox(height: AppThemeEnhanced.xxl),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: '+91 98765 43210',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              isValid: _phoneValid,
            ),
            _buildTextField(
              controller: _emailController,
              label: 'Restaurant Email',
              hint: 'hello@restaurant.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              isValid: _emailValid,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          _prevStep();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppThemeEnhanced.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppThemeEnhanced.backgroundColor,
          elevation: 0,
          leading: _currentStep > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _prevStep,
                )
              : null,
          title: Text(
            'Setup Step ${_currentStep + 1}/$_totalSteps',
            style: GoogleFonts.hankenGrotesk(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        body: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppThemeEnhanced.lg,
                vertical: AppThemeEnhanced.md,
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppThemeEnhanced.borderRadius),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _totalSteps,
                  minHeight: 4,
                  backgroundColor: AppThemeEnhanced.backgroundColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppThemeEnhanced.primaryColor,
                  ),
                ),
              ),
            ),
            // Steps
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentStep = index);
                  _fadeController.reset();
                  _fadeController.forward();
                },
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: AppThemeEnhanced.lg,
            right: AppThemeEnhanced.lg,
            top: AppThemeEnhanced.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentStep == _totalSteps - 1)
                ModernButton(
                  label: _isLoading ? 'Setting up...' : 'Complete Setup',
                  onPressed:
                      _isStep3Valid() && !_isLoading ? () => _setupRestaurant() : null,
                  isLoading: _isLoading,
                  gradient: LinearGradient(
                    colors: [
                      AppThemeEnhanced.primaryColor,
                      AppThemeEnhanced.accentColor,
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: ModernButton(
                          label: 'Back',
                          onPressed: _prevStep,
                          isPrimary: false,
                        ),
                      ),
                    if (_currentStep > 0)
                      const SizedBox(width: AppThemeEnhanced.md),
                    Expanded(
                      child: ModernButton(
                        label: 'Next',
                        onPressed: _nextStep,
                        gradient: LinearGradient(
                          colors: [
                            AppThemeEnhanced.primaryColor,
                            AppThemeEnhanced.accentColor,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppThemeEnhanced.md),
            ],
          ),
        ),
      ),
    );
  }
}
