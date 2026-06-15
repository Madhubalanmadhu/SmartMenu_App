import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme_enhanced.dart';
import '../models/dish.dart';
import '../providers/analytics_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/restaurant_provider.dart';
import '../widgets/modern_ui_components.dart';

class MenuScreenModern extends StatefulWidget {
  const MenuScreenModern({super.key});

  @override
  State<MenuScreenModern> createState() => _MenuScreenModernState();
}

class _MenuScreenModernState extends State<MenuScreenModern>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  int? _selectedCategoryId;

  static const List<String> _dishNameSuggestionSeed = [
    'Chicken Biryani',
    'Mutton Biryani',
    'Veg Biryani',
    'Hyderabadi Biryani',
    'Paneer Butter Masala',
    'Butter Chicken',
    'Chicken Curry',
    'Fish Curry',
    'Masala Dosa',
    'Plain Dosa',
    'Idli Sambar',
    'Vada',
    'Chapati',
    'Butter Naan',
    'Parotta',
    'Fried Rice',
    'Chicken Fried Rice',
    'Veg Noodles',
    'Chicken Noodles',
    'Gobi Manchurian',
    'Chicken 65',
    'Tandoori Chicken',
    'Samosa',
    'Mango Lassi',
    'Fresh Lime Soda',
    'Tea',
    'Coffee',
    'Gulab Jamun',
    'Ice Cream',
  ];

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
        context.read<MenuProvider>().loadDishes(restaurantId);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  List<String> _dishNameSuggestions(
    List<Dish> existingDishes,
    String input,
  ) {
    if (input.isEmpty) return _dishNameSuggestionSeed;
    return _dishNameSuggestionSeed
        .where((name) => name.toLowerCase().contains(input.toLowerCase()))
        .toList();
  }

  Future<void> _openDishDialog(int restaurantId, {Dish? dish}) async {
    final nameController = TextEditingController(text: dish?.name ?? '');
    final costController = TextEditingController(
      text: dish == null ? '' : dish.ingredientCost.toStringAsFixed(2),
    );
    final priceController = TextEditingController(
      text: dish == null ? '' : dish.sellingPrice.toStringAsFixed(2),
    );
    final servingsController = TextEditingController(
      text: (dish?.servingsPerBatch ?? 1).toString(),
    );

    int? selectedCategoryId = dish?.categoryId;
    final menuProvider = context.read<MenuProvider>();
    final analyticsProvider = context.read<AnalyticsProvider>();
    bool isSaving = false;

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
                        dish == null ? 'Add New Dish' : 'Edit Dish',
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
                        label: 'Category',
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedCategoryId,
                          decoration: InputDecoration(
                            hintText: 'Select category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppThemeEnhanced.borderRadius,
                              ),
                            ),
                            prefixIcon: const Icon(Icons.category_outlined),
                          ),
                          items: menuProvider.categories.map((category) {
                            return DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedCategoryId = value);
                          },
                        ),
                      ),
                      _buildDialogTextField(
                        label: 'Dish Name',
                        child: TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Chicken Biryani',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppThemeEnhanced.borderRadius,
                              ),
                            ),
                            prefixIcon: const Icon(Icons.restaurant_outlined),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      _buildDialogTextField(
                        label: 'Ingredient Cost (₹)',
                        child: TextField(
                          controller: costController,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppThemeEnhanced.borderRadius,
                              ),
                            ),
                            prefixIcon: const Icon(Icons.local_offer_outlined),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      _buildDialogTextField(
                        label: 'Selling Price (₹)',
                        child: TextField(
                          controller: priceController,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppThemeEnhanced.borderRadius,
                              ),
                            ),
                            prefixIcon:
                                const Icon(Icons.local_atm_outlined),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      _buildDialogTextField(
                        label: 'Items per Batch',
                        child: TextField(
                          controller: servingsController,
                          decoration: InputDecoration(
                            hintText: '1',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppThemeEnhanced.borderRadius,
                              ),
                            ),
                            prefixIcon: const Icon(Icons.batch_prediction_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(height: AppThemeEnhanced.lg),
                      Row(
                        children: [
                          Expanded(
                            child: ModernButton(
                              label: 'Cancel',
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              isPrimary: false,
                            ),
                          ),
                          const SizedBox(width: AppThemeEnhanced.md),
                          Expanded(
                            child: ModernButton(
                              label: isSaving ? 'Saving...' : 'Save Dish',
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final name =
                                          nameController.text.trim();
                                      final cost = double.tryParse(
                                            costController.text.trim(),
                                          ) ??
                                          0;
                                      final price = double.tryParse(
                                            priceController.text.trim(),
                                          ) ??
                                          0;
                                      final servings = int.tryParse(
                                            servingsController.text.trim(),
                                          ) ??
                                          0;

                                      if (selectedCategoryId == null ||
                                          name.isEmpty ||
                                          cost < 0 ||
                                          servings <= 0 ||
                                          price <= 0) {
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

                                      setDialogState(
                                          () => isSaving = true);

                                      if (dish == null) {
                                        await menuProvider.addDish(
                                          restaurantId,
                                          selectedCategoryId!,
                                          name,
                                          cost,
                                          price,
                                          servings,
                                        );
                                      } else {
                                        await menuProvider.updateDish(
                                          dish.id,
                                          restaurantId,
                                          selectedCategoryId!,
                                          name,
                                          cost,
                                          price,
                                          servings,
                                        );
                                      }

                                      if (menuProvider.error != null) {
                                        if (dialogContext.mounted) {
                                          setDialogState(
                                              () => isSaving = false);
                                          ModernToast.show(
                                            dialogContext,
                                            message: menuProvider.error!,
                                            type: ToastType.error,
                                          );
                                        }
                                        return;
                                      }

                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                      if (mounted) {
                                        await analyticsProvider
                                            .loadAnalytics(restaurantId);
                                      }
                                    },
                              isLoading: isSaving,
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

  Future<void> _confirmDeleteDish(Dish dish) async {
    final restaurantId = context.read<RestaurantProvider>().restaurantId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppThemeEnhanced.borderRadiusLarge),
          ),
          title: Text(
            'Delete Dish?',
            style: GoogleFonts.hankenGrotesk(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${dish.name}" from the menu? This action cannot be undone.',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: AppThemeEnhanced.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeEnhanced.errorColor,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      await context.read<MenuProvider>().deleteDish(dish.id);
      if (restaurantId != null && mounted) {
        await context.read<AnalyticsProvider>().loadAnalytics(restaurantId);
        if (mounted) {
          ModernToast.show(
            context,
            message: 'Dish deleted successfully',
            type: ToastType.success,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantId = context.watch<RestaurantProvider>().restaurantId;

    return Consumer<MenuProvider>(
      builder: (context, menuProvider, _) {
        final selectedCategoryExists = menuProvider.categories.any(
          (c) => c.id == _selectedCategoryId,
        );
        final activeCategoryId =
            selectedCategoryExists ? _selectedCategoryId : null;
        final filteredDishes = activeCategoryId == null
            ? menuProvider.dishes
            : menuProvider.dishes
                .where((dish) => dish.categoryId == activeCategoryId)
                .toList();

        final missingCostCount = menuProvider.dishes
            .where((dish) => dish.ingredientCost <= 0)
            .length;

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Menu Management',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: AppThemeEnhanced.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manage dishes, prices & batch preparation',
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
                                  onPressed: () =>
                                      _openDishDialog(restaurantId),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        AppThemeEnhanced.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppThemeEnhanced.lg),
                        ],
                      ),
                    ),

                    // Cost warning banner
                    if (missingCostCount > 0) ...[
                      ModernCard(
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: AppThemeEnhanced.warningColor,
                              size: 20,
                            ),
                            const SizedBox(width: AppThemeEnhanced.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$missingCostCount dish(es) missing cost',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Add ingredient costs for accurate profit tracking',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppThemeEnhanced.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppThemeEnhanced.lg),
                    ],

                    // Category filter
                    if (menuProvider.categories.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCategoryChip(
                              label: 'All',
                              selected: activeCategoryId == null,
                              onTap: () =>
                                  setState(() => _selectedCategoryId = null),
                            ),
                            const SizedBox(width: AppThemeEnhanced.sm),
                            ...menuProvider.categories.map((category) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  right: AppThemeEnhanced.sm,
                                ),
                                child: _buildCategoryChip(
                                  label: category.name,
                                  selected: activeCategoryId == category.id,
                                  onTap: () => setState(
                                    () => _selectedCategoryId = category.id,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    if (menuProvider.categories.isNotEmpty)
                      const SizedBox(height: AppThemeEnhanced.lg),

                    // Content
                    if (menuProvider.isLoading)
                      _buildLoadingState()
                    else if (menuProvider.error != null)
                      EmptyStateWidget(
                        icon: Icons.error_outline,
                        title: 'Error Loading Menu',
                        subtitle: menuProvider.error!,
                        actionLabel: 'Retry',
                        onActionPressed: restaurantId == null
                            ? null
                            : () => context
                                .read<MenuProvider>()
                                .loadDishes(restaurantId),
                      )
                    else if (filteredDishes.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.restaurant_menu,
                        title: 'No Dishes Yet',
                        subtitle: activeCategoryId == null
                            ? 'Add your first dish to get started'
                            : 'No dishes in this category',
                        actionLabel: 'Add Dish',
                        onActionPressed: restaurantId == null
                            ? null
                            : () => _openDishDialog(restaurantId),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 600;
                          final crossAxisCount = isMobile ? 1 : 2;
                          final childWidth = (constraints.maxWidth -
                                  AppThemeEnhanced.md *
                                      (crossAxisCount - 1)) /
                              crossAxisCount;

                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: AppThemeEnhanced.md,
                            mainAxisSpacing: AppThemeEnhanced.md,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: filteredDishes.map((dish) {
                              return _buildDishCard(
                                context,
                                dish,
                                restaurantId,
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
      },
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppThemeEnhanced.md,
          vertical: AppThemeEnhanced.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppThemeEnhanced.primaryColor
              : AppThemeEnhanced.backgroundColor,
          border: Border.all(
            color: selected
                ? AppThemeEnhanced.primaryColor
                : AppThemeEnhanced.dividerColor,
            width: 2,
          ),
          borderRadius:
              BorderRadius.circular(AppThemeEnhanced.borderRadiusLarge),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : AppThemeEnhanced.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDishCard(
    BuildContext context,
    Dish dish,
    int? restaurantId,
  ) {
    final costMissing = dish.ingredientCost <= 0;
    final margin = dish.sellingPrice - dish.ingredientCost;
    final marginPercent = dish.sellingPrice > 0
        ? ((margin / dish.sellingPrice) * 100).toStringAsFixed(0)
        : '0';

    return ModernCard(
      onTap: restaurantId == null
          ? null
          : () => _openDishDialog(restaurantId, dish: dish),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.name,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppThemeEnhanced.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Provider.of<MenuProvider>(context, listen: false)
                          .categories
                          .firstWhere((c) => c.id == dish.categoryId,
                              orElse: () => Category(
                                    id: 0,
                                    restaurantId: 0,
                                    name: 'Unknown',
                                    type: '',
                                  ))
                          .name,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppThemeEnhanced.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Edit'),
                    onTap: () => Future.delayed(
                      Duration.zero,
                      () => restaurantId == null
                          ? null
                          : _openDishDialog(restaurantId, dish: dish),
                    ),
                  ),
                  PopupMenuItem(
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () => Future.delayed(
                      Duration.zero,
                      () => _confirmDeleteDish(dish),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppThemeEnhanced.md),

          // Batch info
          Row(
            children: [
              Icon(
                Icons.batch_prediction_outlined,
                size: 16,
                color: AppThemeEnhanced.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${dish.servingsPerBatch} items/batch',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppThemeEnhanced.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeEnhanced.sm),

          // Cost and price
          Container(
            padding: const EdgeInsets.all(AppThemeEnhanced.sm),
            decoration: BoxDecoration(
              color: AppThemeEnhanced.backgroundColor,
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
                      'Cost',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppThemeEnhanced.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${dish.ingredientCost.toStringAsFixed(0)}',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: costMissing
                            ? AppThemeEnhanced.errorColor
                            : AppThemeEnhanced.textDark,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppThemeEnhanced.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${dish.sellingPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppThemeEnhanced.successColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Margin',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppThemeEnhanced.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$marginPercent%',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppThemeEnhanced.accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status badge
          if (costMissing) ...[
            const SizedBox(height: AppThemeEnhanced.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppThemeEnhanced.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppThemeEnhanced.errorColor.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(AppThemeEnhanced.borderRadius),
              ),
              child: Text(
                'Missing cost',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppThemeEnhanced.errorColor,
                ),
              ),
            ),
          ],
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
