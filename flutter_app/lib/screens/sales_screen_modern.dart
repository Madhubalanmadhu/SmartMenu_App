import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme_enhanced.dart';
import '../providers/analytics_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/sales_provider.dart';
import '../widgets/modern_ui_components.dart';

class SalesScreenModern extends StatefulWidget {
  const SalesScreenModern({super.key});

  @override
  State<SalesScreenModern> createState() => _SalesScreenModernState();
}

class _SalesScreenModernState extends State<SalesScreenModern>
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
        context.read<SalesProvider>().loadSales(restaurantId);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  double _saleRevenue(dynamic sale) {
    if (sale is Map<String, dynamic>) {
      return (sale['total_revenue'] as num?)?.toDouble() ?? 0;
    }
    return 0;
  }

  int _saleQuantity(dynamic sale) {
    if (sale is Map<String, dynamic>) {
      final items = sale['sales_items'] as List<dynamic>? ?? [];
      int total = 0;
      for (var item in items) {
        if (item is Map<String, dynamic>) {
          total += (item['quantity_sold'] as num?)?.toInt() ?? 0;
        }
      }
      return total;
    }
    return 0;
  }

  Future<void> _openSalesDialog(int restaurantId) async {
    final dateController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );
    final quantityController = TextEditingController();
    int? selectedDishId;
    bool includeWaste = false;
    final wasteQuantityController = TextEditingController();
    final reasonController = TextEditingController();

    final salesProvider = context.read<SalesProvider>();
    final dishes = salesProvider.dishes;

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
                        'Record Sale',
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
                        label: 'Sale Date',
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
                          onChanged: (value) {
                            setDialogState(() => selectedDishId = value);
                          },
                        ),
                      ),
                      _buildDialogTextField(
                        label: 'Quantity Sold',
                        child: TextField(
                          controller: quantityController,
                          decoration: InputDecoration(
                            hintText: '0',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppThemeEnhanced.borderRadius,
                              ),
                            ),
                            prefixIcon: const Icon(Icons.shopping_cart_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppThemeEnhanced.md,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppThemeEnhanced.backgroundColor,
                            borderRadius: BorderRadius.circular(
                              AppThemeEnhanced.borderRadius,
                            ),
                            border: Border.all(
                              color: AppThemeEnhanced.dividerColor,
                            ),
                          ),
                          child: CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppThemeEnhanced.md,
                            ),
                            title: Text(
                              'Include Waste Entry',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            value: includeWaste,
                            onChanged: (value) {
                              setDialogState(
                                  () => includeWaste = value ?? false);
                            },
                          ),
                        ),
                      ),
                      if (includeWaste) ...[
                        _buildDialogTextField(
                          label: 'Quantity Wasted',
                          child: TextField(
                            controller: wasteQuantityController,
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
                              hintText: 'e.g. Spoiled, Leftover, Damaged',
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
                      ],
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
                              label: 'Save Sale',
                              onPressed: () async {
                                final date = dateController.text.trim();
                                final quantity = int.tryParse(
                                      quantityController.text.trim(),
                                    ) ??
                                    0;

                                if (date.isEmpty ||
                                    selectedDishId == null ||
                                    quantity <= 0) {
                                  if (dialogContext.mounted) {
                                    ModernToast.show(
                                      dialogContext,
                                      message:
                                          'Please fill all required fields',
                                      type: ToastType.error,
                                    );
                                  }
                                  return;
                                }

                                final selectedDish = dishes.firstWhere(
                                  (d) => d.id == selectedDishId,
                                );
                                final totalRevenue =
                                    selectedDish.sellingPrice * quantity;

                                final salesItems = [
                                  {
                                    'dish_id': selectedDishId,
                                    'quantity_sold': quantity,
                                    'revenue': totalRevenue,
                                  },
                                ];

                                List<Map<String, dynamic>>? wasteItems;
                                if (includeWaste) {
                                  final wasteQty = int.tryParse(
                                        wasteQuantityController.text.trim(),
                                      ) ??
                                      0;
                                  if (wasteQty > 0 && reasonController.text.isNotEmpty) {
                                    wasteItems = [
                                      {
                                        'dish_id': selectedDishId,
                                        'quantity_wasted': wasteQty,
                                        'reason': reasonController.text,
                                      },
                                    ];
                                  }
                                }

                                await context
                                    .read<SalesProvider>()
                                    .createSale(
                                      restaurantId,
                                      date,
                                      totalRevenue,
                                      salesItems,
                                      wasteItems: wasteItems,
                                    );

                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                  ModernToast.show(
                                    context,
                                    message: 'Sale recorded successfully',
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

  Future<void> _uploadCsv(int restaurantId) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );

    if (result == null) return;

    final file = result.files.single;
    if (!mounted) return;

    ModernToast.show(
      context,
      message: 'Uploading sales file...',
      type: ToastType.info,
    );

    final salesProvider = context.read<SalesProvider>();
    final analyticsProvider = context.read<AnalyticsProvider>();
    final menuProvider = context.read<MenuProvider>();

    if (kIsWeb || file.path == null) {
      final bytes = file.bytes;
      final filename = file.name;
      if (bytes != null) {
        await salesProvider.uploadSalesCsvBytes(bytes, filename, restaurantId);
      }
    } else {
      await salesProvider.uploadSalesCsv(file.path!, restaurantId);
    }

    if (!mounted) return;

    final uploadError = salesProvider.error;
    if (uploadError != null) {
      if (mounted) {
        ModernToast.show(
          context,
          message: 'Upload failed: $uploadError',
          type: ToastType.error,
        );
      }
      salesProvider.clearError();
      return;
    }

    await menuProvider.loadDishes(restaurantId);
    await analyticsProvider.loadAnalytics(restaurantId);

    if (mounted) {
      ModernToast.show(
        context,
        message: 'Sales uploaded successfully!',
        type: ToastType.success,
      );
    }
  }

  Future<void> _showUploadHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload Sales File Help',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 18,
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
                  _buildHelpItem(
                    icon: Icons.description_outlined,
                    title: 'Supported Formats',
                    description: 'CSV, Excel (.xlsx), or Excel (.xls) files',
                  ),
                  _buildHelpItem(
                    icon: Icons.grid_3x3_outlined,
                    title: 'Recommended Columns',
                    description:
                        'Date, Dish Name, Quantity, Revenue (flexible column names)',
                  ),
                  _buildHelpItem(
                    icon: Icons.calendar_today,
                    title: 'Date Headings',
                    description:
                        'Accepts: date, sale_date, order_date, transaction_date',
                  ),
                  _buildHelpItem(
                    icon: Icons.restaurant_outlined,
                    title: 'Item Headings',
                    description: 'Accepts: dish_name, item, product, item_name',
                  ),
                  _buildHelpItem(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Quantity Headings',
                    description: 'Accepts: quantity, qty, units, quantity_sold',
                  ),
                  _buildHelpItem(
                    icon: Icons.attach_money,
                    title: 'Revenue Headings',
                    description:
                        'Accepts: revenue, total, amount, total_price',
                  ),
                  _buildHelpItem(
                    icon: Icons.info_outline,
                    title: 'Auto-Creation',
                    description:
                        'New dish names are automatically added to the menu',
                  ),
                  _buildHelpItem(
                    icon: Icons.auto_stories_outlined,
                    title: 'Costs',
                    description:
                        'Add ingredient costs in Menu for accurate profit tracking',
                  ),
                  const SizedBox(height: AppThemeEnhanced.lg),
                  ModernButton(
                    label: 'Got it!',
                    onPressed: () => Navigator.pop(context),
                    gradient: LinearGradient(
                      colors: [
                        AppThemeEnhanced.primaryColor,
                        AppThemeEnhanced.accentColor,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppThemeEnhanced.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppThemeEnhanced.primaryColor,
            size: 20,
          ),
          const SizedBox(width: AppThemeEnhanced.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppThemeEnhanced.textDark,
                  ),
                ),
                Text(
                  description,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurantId = context.watch<RestaurantProvider>().restaurantId;
    final salesProvider = context.watch<SalesProvider>();

    final revenue = salesProvider.salesHistory.fold<double>(0, (sum, sale) {
      return sum + _saleRevenue(sale);
    });
    final quantity = salesProvider.salesHistory.fold<int>(0, (sum, sale) {
      return sum + _saleQuantity(sale);
    });

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
                      Text(
                        'Sales Performance',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppThemeEnhanced.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload POS data or record sales manually',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppThemeEnhanced.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppThemeEnhanced.lg),
                    ],
                  ),
                ),

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
                          width: isMobile ? childWidth : childWidth,
                          child: _buildMetricCard(
                            icon: Icons.payments_outlined,
                            label: 'Total Revenue',
                            value: '₹${revenue.toStringAsFixed(0)}',
                            color: AppThemeEnhanced.successColor,
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? childWidth : childWidth,
                          child: _buildMetricCard(
                            icon: Icons.shopping_cart_outlined,
                            label: 'Items Sold',
                            value: quantity.toString(),
                            color: AppThemeEnhanced.accentColor,
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? childWidth : childWidth,
                          child: _buildMetricCard(
                            icon: Icons.table_chart_outlined,
                            label: 'Sales Entries',
                            value: salesProvider.salesHistory.length.toString(),
                            color: AppThemeEnhanced.primaryColor,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppThemeEnhanced.xxl),

                // Action buttons
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    return Wrap(
                      spacing: AppThemeEnhanced.md,
                      runSpacing: AppThemeEnhanced.md,
                      children: [
                        SizedBox(
                          width: isMobile
                              ? constraints.maxWidth
                              : (constraints.maxWidth - AppThemeEnhanced.md) /
                                  2,
                          child: ModernCard(
                            onTap: restaurantId == null
                                ? null
                                : () => _openSalesDialog(restaurantId),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.add_chart_outlined,
                                  color: AppThemeEnhanced.primaryColor,
                                  size: 28,
                                ),
                                const SizedBox(height: AppThemeEnhanced.md),
                                Text(
                                  'Enter Sales',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppThemeEnhanced.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Record daily dish quantities',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppThemeEnhanced.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: isMobile
                              ? constraints.maxWidth
                              : (constraints.maxWidth - AppThemeEnhanced.md) /
                                  2,
                          child: ModernCard(
                            onTap: restaurantId == null
                                ? null
                                : () => _uploadCsv(restaurantId),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.upload_file,
                                  color: AppThemeEnhanced.accentColor,
                                  size: 28,
                                ),
                                const SizedBox(height: AppThemeEnhanced.md),
                                Text(
                                  'Upload Sales File',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppThemeEnhanced.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'CSV or Excel, flexible columns',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppThemeEnhanced.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppThemeEnhanced.xxl),

                // Recent sales header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Sales',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppThemeEnhanced.textDark,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showUploadHelp,
                      icon: const Icon(Icons.help_outline),
                      label: Text(
                        'File Help',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppThemeEnhanced.md),

                // Content
                if (salesProvider.isLoading)
                  _buildLoadingState()
                else if (salesProvider.error != null)
                  EmptyStateWidget(
                    icon: Icons.error_outline,
                    title: 'Error Loading Sales',
                    subtitle: salesProvider.error!,
                    actionLabel: 'Retry',
                    onActionPressed: restaurantId == null
                        ? null
                        : () =>
                            context.read<SalesProvider>().loadSales(restaurantId),
                  )
                else if (salesProvider.salesHistory.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.point_of_sale,
                    title: 'No Sales Yet',
                    subtitle:
                        'Upload a CSV or record a sale to unlock analytics',
                    actionLabel: 'Record Sale',
                    onActionPressed: restaurantId == null
                        ? null
                        : () => _openSalesDialog(restaurantId),
                  )
                else
                  _buildSalesListModern(salesProvider),
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

  Widget _buildSalesListModern(SalesProvider salesProvider) {
    final sales = salesProvider.salesHistory
        .map((sale) => sale is Map<String, dynamic>
            ? sale
            : Map<String, dynamic>.from(sale as Map))
        .toList();

    sales.sort((a, b) {
      final aDate = a['sale_date']?.toString() ?? '';
      final bDate = b['sale_date']?.toString() ?? '';
      return bDate.compareTo(aDate);
    });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        final date = sale['sale_date']?.toString() ?? 'Unknown';
        final revenue = (sale['total_revenue'] as num?)?.toDouble() ?? 0;
        final items = sale['sales_items'] as List<dynamic>? ?? [];
        int totalQty = 0;
        for (var item in items) {
          if (item is Map<String, dynamic>) {
            totalQty += (item['quantity_sold'] as num?)?.toInt() ?? 0;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppThemeEnhanced.md),
          child: ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          date,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppThemeEnhanced.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${items.length} dish(es)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppThemeEnhanced.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${revenue.toStringAsFixed(0)}',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppThemeEnhanced.successColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalQty items',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppThemeEnhanced.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: AppThemeEnhanced.md),
                  Divider(
                    color: AppThemeEnhanced.dividerColor,
                    height: 1,
                  ),
                  const SizedBox(height: AppThemeEnhanced.md),
                  Wrap(
                    spacing: AppThemeEnhanced.sm,
                    runSpacing: AppThemeEnhanced.sm,
                    children: items.take(5).map((item) {
                      final qty = (item['quantity_sold'] as num?)?.toInt() ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppThemeEnhanced.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppThemeEnhanced.backgroundColor,
                          borderRadius: BorderRadius.circular(
                            AppThemeEnhanced.borderRadius,
                          ),
                        ),
                        child: Text(
                          '$qty x',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppThemeEnhanced.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (items.length > 5)
                    Text(
                      '+ ${items.length - 5} more',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppThemeEnhanced.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        ...List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppThemeEnhanced.md),
            child: SkeletonLoader(
              width: double.infinity,
              height: 100,
              borderRadius: AppThemeEnhanced.borderRadius,
            ),
          ),
        ),
      ],
    );
  }
}
