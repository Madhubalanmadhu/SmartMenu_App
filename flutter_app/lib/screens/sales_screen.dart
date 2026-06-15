import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/analytics_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/waste_provider.dart';
import '../widgets/common_widgets.dart';
import 'sales_detail_dashboard.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final restaurantId = context.read<RestaurantProvider>().restaurantId;
      if (restaurantId != null) {
        context.read<SalesProvider>().loadSales(restaurantId);
      }
    });
  }

  Future<void> _openSalesDialog(int restaurantId) async {
    final dateController = TextEditingController();
    final quantityController = TextEditingController();
    final wasteQuantityController = TextEditingController();
    final reasonController = TextEditingController();
    int? selectedDishId;
    bool includeWaste = false;

    final salesProvider = context.read<SalesProvider>();
    final dishes = salesProvider.dishes;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Record Sale'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: dateController,
                        decoration: const InputDecoration(
                          labelText: 'Date (YYYY-MM-DD)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedDishId,
                        dropdownColor: AppTheme.surfaceHigh,
                        decoration: const InputDecoration(labelText: 'Dish'),
                        items: dishes.map((dish) {
                          return DropdownMenuItem(
                            value: dish.id,
                            child: Text(dish.name),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setDialogState(() => selectedDishId = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity Sold',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Include waste for this dish'),
                        value: includeWaste,
                        onChanged: (value) =>
                            setDialogState(() => includeWaste = value ?? false),
                      ),
                      if (includeWaste) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: wasteQuantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity Wasted',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: reasonController,
                          decoration: const InputDecoration(
                            labelText: 'Waste Reason',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final date = dateController.text.trim();
                    final quantity =
                        int.tryParse(quantityController.text.trim()) ?? 0;

                    if (date.isEmpty ||
                        selectedDishId == null ||
                        quantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all required fields'),
                        ),
                      );
                      return;
                    }

                    final selectedDish = dishes.firstWhere(
                      (d) => d.id == selectedDishId,
                    );
                    final totalRevenue = selectedDish.sellingPrice * quantity;

                    final salesItems = [
                      {
                        'dish_id': selectedDishId,
                        'quantity_sold': quantity,
                        'revenue': totalRevenue,
                      },
                    ];

                    List<Map<String, dynamic>>? wasteItems;
                    if (includeWaste) {
                      final wasteQty =
                          int.tryParse(wasteQuantityController.text.trim()) ??
                          0;
                      final reason = reasonController.text.trim();
                      if (wasteQty > 0 && reason.isNotEmpty) {
                        wasteItems = [
                          {
                            'dish_id': selectedDishId,
                            'quantity_wasted': wasteQty,
                            'reason': reason,
                          },
                        ];
                      }
                    }

                    final salesProvider = context.read<SalesProvider>();
                    final analyticsProvider = context.read<AnalyticsProvider>();
                    final wasteProvider = context.read<WasteProvider>();
                    final navigator = Navigator.of(context);

                    await salesProvider.createSale(
                      restaurantId,
                      date,
                      totalRevenue,
                      salesItems,
                      wasteItems: wasteItems,
                    );
                    await analyticsProvider.trainModels(restaurantId);
                    await wasteProvider.loadWaste(restaurantId);
                    navigator.pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    dateController.dispose();
    quantityController.dispose();
    wasteQuantityController.dispose();
    reasonController.dispose();
  }

  Future<void> _uploadCsv(int restaurantId) async {
    final salesProvider = context.read<SalesProvider>();
    final analyticsProvider = context.read<AnalyticsProvider>();
    final menuProvider = context.read<MenuProvider>();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );

    if (result == null) return;
    final file = result.files.single;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(uploadError)));
      salesProvider.clearError();
      return;
    }

    await menuProvider.loadDishes(restaurantId);
    await analyticsProvider.trainModels(restaurantId);
  }

  Future<void> _showUploadHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sales File Help'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You can upload CSV or Excel files.'),
              SizedBox(height: 10),
              Text('Recommended columns: Date, Dish Name, Quantity, Revenue.'),
              SizedBox(height: 10),
              Text(
                'Accepted date headings include date, sale_date, order_date.',
              ),
              SizedBox(height: 10),
              Text('Accepted item headings include dish_name, item, product.'),
              SizedBox(height: 10),
              Text('Accepted quantity headings include quantity, qty, units.'),
              SizedBox(height: 10),
              Text('Dish ID is optional when Dish Name is provided.'),
              SizedBox(height: 10),
              Text(
                'New dish names are added to the menu automatically during upload.',
              ),
              SizedBox(height: 10),
              Text(
                'After upload, add ingredient costs in Menu for exact profit margins.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSalesDetails(Map<String, dynamic> sale) {
    final date = sale['sale_date']?.toString() ?? 'Unknown';
    final totalRevenue = (sale['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final items = sale['sales_items'] as List<dynamic>? ?? [];
    final restaurantName =
        context.read<RestaurantProvider>().restaurantName ?? 'Restaurant';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SalesDetailDashboard(
          restaurantName: restaurantName,
          saleDate: date,
          totalRevenue: totalRevenue,
          items: items,
        ),
      ),
    );
    return Future.value();
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

    return SmartPage(
      title: 'Sales Performance',
      subtitle: 'Upload POS data or record sales manually.',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              MetricCard(
                label: 'Total revenue',
                value: formatMoney(revenue),
                icon: Icons.payments_outlined,
                trend: 'Logged',
              ),
              MetricCard(
                label: 'Items sold',
                value: quantity.toString(),
                icon: Icons.shopping_cart_outlined,
              ),
              MetricCard(
                label: 'Sales entries',
                value: salesProvider.salesHistory.length.toString(),
                icon: Icons.table_chart_outlined,
              ),
            ];
            if (constraints.maxWidth < 760) {
              return Column(
                children: cards
                    .expand((card) => [card, const SizedBox(height: 12)])
                    .toList(),
              );
            }
            return Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i != cards.length - 1) const SizedBox(width: 12),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final actions = [
              ActionTile(
                title: 'Enter Sales',
                subtitle: 'Record daily dish quantities',
                icon: Icons.add_chart_outlined,
                onTap: restaurantId == null
                    ? null
                    : () => _openSalesDialog(restaurantId),
              ),
              ActionTile(
                title: 'Upload Sales File',
                subtitle: 'CSV or Excel, flexible columns',
                icon: Icons.upload_file,
                onTap: restaurantId == null
                    ? null
                    : () => _uploadCsv(restaurantId),
              ),
            ];
            if (constraints.maxWidth < 700) {
              return Column(
                children: actions
                    .expand((action) => [action, const SizedBox(height: 12)])
                    .toList(),
              );
            }
            return Row(
              children: [
                Expanded(child: actions[0]),
                const SizedBox(width: 12),
                Expanded(child: actions[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Sales',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            TextButton.icon(
              onPressed: _showUploadHelp,
              icon: const Icon(Icons.help_outline),
              label: const Text('File help'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (salesProvider.isLoading)
          const LoadingWidget(message: 'Loading sales history...')
        else if (salesProvider.error != null)
          AppErrorWidget(
            message: salesProvider.error!,
            onRetry: restaurantId == null
                ? null
                : () => context.read<SalesProvider>().loadSales(restaurantId),
          )
        else if (salesProvider.salesHistory.isEmpty)
          const EmptyStateCard(
            icon: Icons.point_of_sale,
            title: 'No sales history yet',
            message:
                'Upload a CSV or record sales to unlock performance analytics.',
          )
        else
          _buildRecentSalesList(context, salesProvider),
        if (salesProvider.message != null) ...[
          const SizedBox(height: 12),
          StatusChip(
            label: salesProvider.message!,
            color: AppTheme.successColor,
          ),
        ],
      ],
    );
  }

  Widget _buildRecentSalesList(
    BuildContext context,
    SalesProvider salesProvider,
  ) {
    final sales = salesProvider.salesHistory.map((sale) {
      return sale is Map<String, dynamic>
          ? sale
          : Map<String, dynamic>.from(sale as Map);
    }).toList();

    sales.sort((a, b) {
      final uploadedDates = salesProvider.recentlyUploadedDates;
      final aUploaded = uploadedDates.contains(a['sale_date']?.toString());
      final bUploaded = uploadedDates.contains(b['sale_date']?.toString());
      if (aUploaded != bUploaded) {
        return aUploaded ? -1 : 1;
      }
      final aDate = _parseSaleDate(a['sale_date']?.toString());
      final bDate = _parseSaleDate(b['sale_date']?.toString());
      final dateCompare = (bDate ?? DateTime(1900)).compareTo(
        aDate ?? DateTime(1900),
      );
      if (dateCompare != 0) return dateCompare;
      final aId = (a['id'] as num?)?.toInt() ?? 0;
      final bId = (b['id'] as num?)?.toInt() ?? 0;
      return bId.compareTo(aId);
    });

    final children = <Widget>[];
    String? currentGroup;
    for (var index = 0; index < sales.length; index++) {
      final sale = sales[index];
      final isUploaded = salesProvider.recentlyUploadedDates.contains(
        sale['sale_date']?.toString(),
      );
      final parsedDate = _parseSaleDate(sale['sale_date']?.toString());
      final group = isUploaded
          ? 'Just uploaded'
          : _relativeDateLabel(parsedDate);
      if (group != currentGroup) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: currentGroup == null ? 0 : 6,
              bottom: 10,
            ),
            child: Row(
              children: [
                Text(group, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(height: 1, color: AppTheme.outlineStrong),
                ),
              ],
            ),
          ),
        );
        currentGroup = group;
      }
      children.add(
        _RecentSaleCard(
          serialNumber: index + 1,
          sale: sale,
          isNewest: index == 0,
          isUploaded: isUploaded,
          dateLabel: _displaySaleDate(
            parsedDate,
            sale['sale_date']?.toString(),
          ),
          itemSummary: _saleItemSummary(sale, salesProvider),
          revenue: _saleRevenue(sale),
          quantity: _saleQuantity(sale),
          onTap: () => _showSalesDetails(sale),
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    return Column(children: children);
  }

  double _saleRevenue(dynamic sale) {
    final map = sale is Map ? sale : const {};
    return (map['total_revenue'] as num?)?.toDouble() ?? 0;
  }

  int _saleQuantity(dynamic sale) {
    final map = sale is Map ? sale : const {};
    final items = map['sales_items'] as List<dynamic>? ?? [];
    return items.fold<int>(0, (sum, item) {
      final row = item is Map ? item : const {};
      return sum + ((row['quantity_sold'] as num?)?.toInt() ?? 0);
    });
  }

  String _saleItemSummary(
    Map<String, dynamic> sale,
    SalesProvider salesProvider,
  ) {
    final items = sale['sales_items'] as List<dynamic>? ?? [];
    if (items.isEmpty) return 'No item details';

    final dishNames = <String>[];
    for (final item in items.take(2)) {
      final row = item is Map ? item : const {};
      final dishId = (row['dish_id'] as num?)?.toInt();
      final dish = salesProvider.dishes.where((dish) => dish.id == dishId);
      final uploadedName = row['dish_name']?.toString();
      final name = uploadedName?.isNotEmpty == true
          ? uploadedName!
          : dish.isEmpty
          ? 'Dish #$dishId'
          : dish.first.name;
      final quantity = (row['quantity_sold'] as num?)?.toInt() ?? 0;
      dishNames.add('$name x$quantity');
    }

    if (items.length > 2) {
      dishNames.add('+${items.length - 2} more');
    }
    return dishNames.join(' | ');
  }

  DateTime? _parseSaleDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String _relativeDateLabel(DateTime? date) {
    if (date == null) return 'Unknown date';
    final today = DateUtils.dateOnly(DateTime.now());
    final saleDay = DateUtils.dateOnly(date);
    final difference = today.difference(saleDay).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference > 1 && difference < 7) return '$difference days ago';
    if (difference < 0) return 'Upcoming';
    return _displaySaleDate(date, null);
  }

  String _displaySaleDate(DateTime? date, String? fallback) {
    if (date == null) return fallback ?? 'Unknown';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _RecentSaleCard extends StatelessWidget {
  final int serialNumber;
  final Map<String, dynamic> sale;
  final bool isNewest;
  final bool isUploaded;
  final String dateLabel;
  final String itemSummary;
  final double revenue;
  final int quantity;
  final VoidCallback onTap;

  const _RecentSaleCard({
    required this.serialNumber,
    required this.sale,
    required this.isNewest,
    required this.isUploaded,
    required this.dateLabel,
    required this.itemSummary,
    required this.revenue,
    required this.quantity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SmartCard(
      onTap: onTap,
      color: isNewest || isUploaded ? AppTheme.surfaceHigh : null,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '#$serialNumber',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppTheme.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (isNewest)
                      const StatusChip(
                        label: 'Latest entry',
                        color: AppTheme.successColor,
                      ),
                    if (isUploaded) const StatusChip(label: 'Uploaded'),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  itemSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusChip(label: '$quantity items'),
                    if (sale['id'] != null)
                      StatusChip(
                        label: 'Sale ${sale['id']}',
                        color: AppTheme.textMuted,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(revenue),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppTheme.primary),
              ),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ],
      ),
    );
  }
}
