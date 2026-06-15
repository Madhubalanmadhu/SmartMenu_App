import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme_enhanced.dart';

/// Modern animated button with ripple effect
class ModernButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final IconData? icon;
  final Gradient? gradient;
  final bool isPrimary;

  const ModernButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.icon,
    this.gradient,
    this.isPrimary = true,
  }) : super(key: key);

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppThemeEnhanced.shortDuration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultBgColor = widget.isPrimary
        ? (widget.backgroundColor ?? AppThemeEnhanced.primary)
        : (widget.backgroundColor ?? AppThemeEnhanced.surfaceLight);
    final defaultTextColor = widget.isPrimary
        ? (widget.textColor ?? Colors.white)
        : (widget.textColor ?? AppThemeEnhanced.textPrimary);

    final buttonGradient = widget.gradient ??
        LinearGradient(
          colors: [
            defaultBgColor,
            defaultBgColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    return GestureDetector(
      onTapDown: widget.isEnabled && !widget.isLoading
          ? (_) => _controller.forward()
          : null,
      onTapUp: widget.isEnabled && !widget.isLoading
          ? (_) {
              _controller.reverse();
              widget.onPressed();
            }
          : null,
      onTapCancel: widget.isEnabled && !widget.isLoading
          ? () => _controller.reverse()
          : null,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 0.95).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Container(
          width: widget.width,
          decoration: BoxDecoration(
            gradient: buttonGradient,
            borderRadius:
                BorderRadius.circular(AppThemeEnhanced.radiusMd),
            boxShadow: widget.isEnabled && widget.isPrimary
                ? AppThemeEnhanced.shadowMd
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isEnabled && !widget.isLoading
                  ? widget.onPressed
                  : null,
              borderRadius:
                  BorderRadius.circular(AppThemeEnhanced.radiusMd),
              child: Padding(
                padding: EdgeInsets.all(AppThemeEnhanced.md),
                child: widget.isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            defaultTextColor,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: defaultTextColor,
                              size: 20,
                            ),
                            SizedBox(width: AppThemeEnhanced.sm),
                          ],
                          Text(
                            widget.label,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: defaultTextColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern loading skeleton with shimmer effect
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius = AppThemeEnhanced.radiusMd,
  }) : super(key: key);

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppThemeEnhanced.surfaceLight,
                AppThemeEnhanced.surfaceHighest,
                AppThemeEnhanced.surfaceLight,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Modern card with gradient and shadow
class ModernCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool showGradient;
  final Color? backgroundColor;

  const ModernCard({
    Key? key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(AppThemeEnhanced.md),
    this.onTap,
    this.showGradient = false,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppThemeEnhanced.surface,
        gradient: showGradient
            ? LinearGradient(
                colors: [
                  AppThemeEnhanced.surface,
                  AppThemeEnhanced.surfaceLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(AppThemeEnhanced.radiusLg),
        border: Border.all(
          color: AppThemeEnhanced.divider,
          width: 1,
        ),
        boxShadow: AppThemeEnhanced.shadowMd,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Modern toast notification
class ModernToast extends StatefulWidget {
  final String message;
  final Duration duration;
  final Color backgroundColor;
  final IconData icon;

  const ModernToast({
    Key? key,
    required this.message,
    this.duration = const Duration(seconds: 3),
    required this.backgroundColor,
    required this.icon,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required String message,
    required ToastType type,
  }) {
    final colors = {
      ToastType.success: AppThemeEnhanced.success,
      ToastType.error: AppThemeEnhanced.error,
      ToastType.warning: AppThemeEnhanced.warning,
      ToastType.info: AppThemeEnhanced.info,
    };

    final icons = {
      ToastType.success: Icons.check_circle_rounded,
      ToastType.error: Icons.error_rounded,
      ToastType.warning: Icons.warning_rounded,
      ToastType.info: Icons.info_rounded,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ModernToast(
          message: message,
          backgroundColor: colors[type]!,
          icon: icons[type]!,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(AppThemeEnhanced.md),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  State<ModernToast> createState() => _ModernToastState();
}

enum ToastType { success, error, warning, info }

class _ModernToastState extends State<ModernToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppThemeEnhanced.mediumDuration,
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      )),
      child: Container(
        padding: EdgeInsets.all(AppThemeEnhanced.md),
        decoration: BoxDecoration(
          color: widget.backgroundColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(AppThemeEnhanced.radiusMd),
          boxShadow: AppThemeEnhanced.shadowLg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: AppThemeEnhanced.md),
            Expanded(
              child: Text(
                widget.message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern loading indicator
class ModernLoadingIndicator extends StatelessWidget {
  final String? label;
  final Color? color;

  const ModernLoadingIndicator({
    Key? key,
    this.label,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? AppThemeEnhanced.primary,
              ),
            ),
          ),
          if (label != null) ...[
            SizedBox(height: AppThemeEnhanced.lg),
            Text(
              label!,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppThemeEnhanced.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state widget
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  const EmptyStateWidget({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onActionPressed,
    this.actionLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppThemeEnhanced.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppThemeEnhanced.primary.withOpacity(0.5),
            ),
            SizedBox(height: AppThemeEnhanced.lg),
            Text(
              title,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppThemeEnhanced.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppThemeEnhanced.sm),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppThemeEnhanced.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (onActionPressed != null && actionLabel != null) ...[
              SizedBox(height: AppThemeEnhanced.lg),
              ModernButton(
                label: actionLabel!,
                onPressed: onActionPressed!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
