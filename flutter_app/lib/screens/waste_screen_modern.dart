import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme_enhanced.dart';
import '../models/dish.dart';
import '../providers/analytics_provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/waste_provider.dart';
import '../widgets/modern_ui_components.dart';

class WasteScreenModern extends StatefulWidget {
  const WasteScreenModern({super.key});

  @override
  State<WasteScreenModern> createState() => _WasteScreenModernState();
}

class _WasteScreenModernState extends State<WasteScreenModern>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: AppThemeEnhanced.mediumDuration,
      vsync: this,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final restaurantId = context.read<RestaurantProvider>().restaurantId;
      if (restaurantId != null) {
        context.read<WasteProvider>().loadWaste(restaurantId);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _openWasteDialog(int restaurantId) async {
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();
    final dateController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );
    int? selectedDishId;

    final wasteProvider = context.read<WasteProvider>();
    final dishes = wasteProvider.dishes;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppThemeEnhanced.borderRadiusLarge),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppThemeEnhanced.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Log Waste',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppThemeEnhanced.textDark,
                        ),
                      ),
                      const SizedBox(height: AppThemeEnhanced.md),
                      Divider(
                        color: AppThemeEnhanced.dividerColor,
                        height: 1,
                      ),
                      const SizedBox(height: AppThemeEnhanced.lg),
                      _buildDialogTextField(
                        label: 'Select Dish',
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedDishId,
                          decoration: InputDecoration(
                            hintText: 'Choose a dish',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppThemeEnhanced.borderRadius,
                              ),
                            ),
                            prefixIcon: const Icon(Icons.restaurant_outlined),
                          ),
                          items: dishes.map((dish) {
                            return DropdownMenuItem(
                              value: dish.id,
                              child: Text(dish.name),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setDialogState(() => selectedDishId = value),
                        ),
                      ),
                      _buildDialogTextField(
                        label: 'Quantity Wasted',
                        child: TextField(
                          controller: quantityController,
                          decoration: InputDecoration(
                            hintText: '0',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppThemeEnhanced.borderRadius,
                              ),
                            ),
                            prefixIcon: const Icon(Icons.delete_outline),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      _buildDialogTextField(
                        label: 'Waste Reason',
                        child: TextField(
                          controller: reasonController,
                          decoration: InputDecoration(
                            hintText:
                                'e.g. Spoiled, Leftover, Damaged, Burned',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppThemeEnhanced.borderRadius,
                              ),
                            ),
                            prefixIcon: const Icon(Icons.info_outline),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      _buildDialogTextField(
                        label: 'Date',
                        child: TextField(
                          controller: dateController,
                          decoration: InputDecoration(
                            hintText: 'YYYY-MM-DD',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppThemeEnhanced.borderRadius,
                              ),
                            ),
                            prefixIcon: const Icon(Icons.calendar_today),
                          ),
                          keyboardType: TextInputType.datetime,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(height: AppThemeEnhanced.lg),
                      Row(
                        children: [
                          Expanded(
                            child: ModernButton(
                              label: 'Cancel',
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              isPrimary: false,
                            ),
                          ),
                          const SizedBox(width: AppThemeEnhanced.md),
                          Expanded(
                            child: ModernButton(
                              label: 'Log Waste',
                              onPressed: () async {
                                final quantity = int.tryParse(
                                      quantityController.text.trim(),
                                    ) ??
                                    0;
                                final reason =
                                    reasonController.text.trim();
                                final wasteDate =
                                    dateController.text.trim();

                                if (selectedDishId == null ||
                                    quantity <= 0 ||
                                    reason.isEmpty ||
                                    wasteDate.isEmpty) {
                                  if (dialogContext.mounted) {
                                    ModernToast.show(
                                      dialogContext,
                                      message:
                                          'Please fill all fields correctly',
                                      type: ToastType.error,
                                    );
                                  }
                                  return;
                                }

                                await context
                                    .read<WasteProvider>()
                                    .logWaste(
                                      restaurantId,
                                      selectedDishId!,
                                      quantity,
                                      reason,
                                      wasteDate,
                                    );

                                if (context.mounted) {
                                  await context
                                      .read<AnalyticsProvider>()
                                      .loadAnalytics(restaurantId);
                                }

                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                  ModernToast.show(
                                    context,
                                    message: 'Waste logged successfully',
                                    type: ToastType.success,
                                  );
                                }
                              },
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
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    quantityController.dispose();
    reasonController.dispose();
    dateController.dispose();
  }

  Widget _buildDialogTextField({
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppThemeEnhanced.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppThemeEnhanced.textDark,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  String _dishName(List<Dish> dishes, String dishId) {
    final parsedId = int.tryParse(dishId);
    if (parsedId == null) return 'Dish #$dishId';
    for (final dish in dishes) {
      if (dish.id == parsedId) return dish.name;
    }
    return 'Dish #$dishId';
  }

  int _totalWaste(Map<String, dynamic>? patterns) {
    if (patterns == null) return 0;
    return patterns.values.fold<int>(0, (sum, value) {
      final row = value is Map ? value : const {};
      return sum + ((row['total_wasted'] as num?)?.toInt() ?? 0);
    });
  }

  int _reasonCount(Map<String, dynamic>? patterns) {
    if (patterns == null) return 0;
    return patterns.values.fold<int>(0, (sum, value) {
      final row = value is Map ? value : const {};
      final reasons = row['reasons'];
      return sum + (reasons is Map ? reasons.length : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final restaurantId = context.watch<RestaurantProvider>().restaurantId;
    final wasteProvider = context.watch<WasteProvider>();
    final patterns =
        wasteProvider.wastePatterns?['patterns'] as Map<String, dynamic>?;
    final totalUnits = _totalWaste(patterns);
    final reasonCount = _reasonCount(patterns);

    return Scaffold(
      backgroundColor: AppThemeEnhanced.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppThemeEnhanced.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                FadeTransition(
                  opacity: Tween<double>(begin: 0, end: 1)
                      .animate(_fadeController),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Waste Analysis',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppThemeEnhanced.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track waste patterns & improve margins',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppThemeEnhanced.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (restaurantId != null)
                        IconButton.filled(
                          icon: const Icon(Icons.add),
                          onPressed: () => _openWasteDialog(restaurantId),
                          style: IconButton.styleFrom(
                            backgroundColor: AppThemeEnhanced.errorColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppThemeEnhanced.xxl),

                // Metrics
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    final childWidth = isMobile
                        ? constraints.maxWidth
                        : (constraints.maxWidth - AppThemeEnhanced.md) / 2;

                    return Wrap(
                      spacing: AppThemeEnhanced.md,
                      runSpacing: AppThemeEnhanced.md,
                      children: [
                        SizedBox(
                          width: childWidth,
                          child: _buildMetricCard(
                            icon: Icons.delete_outline,
                            label: 'Weekly Waste',
                            value: totalUnits.toString() + ' units',
                            color: AppThemeEnhanced.errorColor,
                          ),
                        ),
                        SizedBox(
                          width: childWidth,
                          child: _buildMetricCard(
                            icon: Icons.restaurant_menu_outlined,
                            label: 'Affected Dishes',
                            value: (patterns?.length ?? 0).toString(),
                            color: AppThemeEnhanced.warningColor,
                          ),
                        ),
                        SizedBox(
                          width: childWidth,
                          child: _buildMetricCard(
                            icon: Icons.insights_outlined,
                            label: 'Reason Signals',
                            value: reasonCount.toString(),
                            color: AppThemeEnhanced.successColor,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppThemeEnhanced.xxl),

                // Waste Patterns Header
                Text(
                  'Waste Patterns',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppThemeEnhanced.textDark,
                  ),
                ),
                const SizedBox(height: AppThemeEnhanced.md),

                // Content
                if (wasteProvider.isLoading)
                  _buildLoadingState()
                else if (wasteProvider.error != null)
                  EmptyStateWidget(
                    icon: Icons.error_outline,
                    title: 'Error Loading Waste Data',
                    subtitle: wasteProvider.error!,
                    actionLabel: 'Retry',
                    onActionPressed: restaurantId == null
                        ? null
                        : () =>
                            context.read<WasteProvider>().loadWaste(restaurantId),
                  )
                else if (patterns == null || patterns.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.delete_outline,
                    title: 'No Waste Logged Yet',
                    subtitle: 'Track waste to identify operational inefficiencies',
                    actionLabel: 'Log Waste',
                    onActionPressed: restaurantId == null
                        ? null
                        : () => _openWasteDialog(restaurantId),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final crossAxisCount = isMobile ? 1 : 2;
                      final childWidth = (constraints.maxWidth -
                              AppThemeEnhanced.md * (crossAxisCount - 1)) /
                          crossAxisCount;

                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: AppThemeEnhanced.md,
                        mainAxisSpacing: AppThemeEnhanced.md,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: patterns.entries.map((entry) {
                          return _buildWastePatternCard(
                            wasteProvider.dishes,
                            entry.key,
                            entry.value as Map<String, dynamic>? ?? {},
                          );
                        }).toList(),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius:
                  BorderRadius.circular(AppThemeEnhanced.borderRadius),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppThemeEnhanced.md),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppThemeEnhanced.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppThemeEnhanced.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWastePatternCard(
    List<Dish> dishes,
    String dishId,
    Map<String, dynamic> data,
  ) {
    final dishName = _dishName(dishes, dishId);
    final total = data['total_wasted']?.toString() ?? '0';
    final reasons = data['reasons'] as Map<String, dynamic>? ?? {};
    final topReason = reasons.isNotEmpty
        ? reasons.entries.reduce((a, b) =>
            ((a.value as num?)?.toInt() ?? 0) >
                    ((b.value as num?)?.toInt() ?? 0)
                ? a
                : b)
        : null;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dishName,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppThemeEnhanced.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppThemeEnhanced.md),
          Container(
            padding: const EdgeInsets.all(AppThemeEnhanced.md),
            decoration: BoxDecoration(
              color: AppThemeEnhanced.errorColor.withOpacity(0.1),
              borderRadius:
                  BorderRadius.circular(AppThemeEnhanced.borderRadius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Wasted',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppThemeEnhanced.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$total units',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppThemeEnhanced.errorColor,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.delete_outline,
                  color: AppThemeEnhanced.errorColor,
                  size: 24,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppThemeEnhanced.md),
          if (reasons.isNotEmpty) ...[
            Text(
              'Waste Reasons',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppThemeEnhanced.textDark,
              ),
            ),
            const SizedBox(height: AppThemeEnhanced.sm),
            Column(
              children: reasons.entries.map((entry) {
                final reason = entry.key;
                final count = (entry.value as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppThemeEnhanced.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          reason,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppThemeEnhanced.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppThemeEnhanced.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppThemeEnhanced.warningColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            AppThemeEnhanced.borderRadius,
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppThemeEnhanced.warningColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else
            Text(
              'No reasons logged',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppThemeEnhanced.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        ...List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppThemeEnhanced.md),
            child: SkeletonLoader(
              width: double.infinity,
              height: 150,
              borderRadius: AppThemeEnhanced.borderRadius,
            ),
          ),
        ),
      ],
    );
  }
}
