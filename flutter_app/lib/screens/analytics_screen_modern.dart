import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme_enhanced.dart';
import '../models/dish.dart';
import '../providers/analytics_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/restaurant_provider.dart';
import '../widgets/modern_ui_components.dart';

class AnalyticsScreenModern extends StatefulWidget {
  const AnalyticsScreenModern({super.key});

  @override
  State<AnalyticsScreenModern> createState() => _AnalyticsScreenModernState();
}

class _AnalyticsScreenModernState extends State<AnalyticsScreenModern>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  int _selectedTabIndex = 0;

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
        context.read<AnalyticsProvider>().loadAnalytics(restaurantId);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  String _getDishName(int dishId) {
    final dishes = context.read<MenuProvider>().dishes;
    for (final dish in dishes) {
      if (dish.id == dishId) {
        return dish.name;
      }
    }
    return 'Dish #$dishId';
  }

  Future<void> _openAiChat(
    int restaurantId,
    AnalyticsProvider analyticsProvider,
  ) async {
    final dishes = context.read<MenuProvider>().dishes;
    Dish? selectedDish = dishes.isEmpty ? null : dishes.first;
    final inputController = TextEditingController();
    final messages = <Map<String, dynamic>>[
      {
        'fromUser': false,
        'text':
            'Ask me what to prepare, how weather affects demand, festival impact, waste risk, or which dish to push today.',
      },
    ];

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppThemeEnhanced.borderRadiusLarge),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> sendMessage() async {
              final text = inputController.text.trim();
              if (text.isEmpty) return;
              setSheetState(() {
                messages.add({
                  'fromUser': true,
                  'text': text,
                });
                inputController.clear();
              });
              try {
                final response = await analyticsProvider.chat(
                  restaurantId,
                  text,
                  dishId: selectedDish?.id,
                );
                final reply = response['reply']?.toString() ?? '';
                setSheetState(() {
                  messages.add({
                    'fromUser': false,
                    'text': reply,
                  });
                });
              } catch (e) {
                if (context.mounted) {
                  ModernToast.show(
                    context,
                    message: 'Error: ${e.toString()}',
                    type: ToastType.error,
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppThemeEnhanced.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Food Advisor',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppThemeEnhanced.textDark,
                          ),
                        ),
                        const SizedBox(height: AppThemeEnhanced.sm),
                        Text(
                          'Get smart recommendations for your menu',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppThemeEnhanced.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    color: AppThemeEnhanced.dividerColor,
                    height: 1,
                  ),
                  if (dishes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppThemeEnhanced.lg),
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedDish?.id,
                        decoration: InputDecoration(
                          labelText: 'Food Item Context',
                          prefixIcon: const Icon(Icons.restaurant_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppThemeEnhanced.borderRadius,
                            ),
                          ),
                        ),
                        items: dishes.map((dish) {
                          return DropdownMenuItem(
                            value: dish.id,
                            child: Text(dish.name),
                          );
                        }).toList(),
                        onChanged: (dishId) {
                          final match = dishes.firstWhere(
                            (dish) => dish.id == dishId,
                            orElse: () => selectedDish ?? dishes.first,
                          );
                          setSheetState(() => selectedDish = match);
                        },
                      ),
                    ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppThemeEnhanced.lg,
                        ),
                        child: Column(
                          children: messages.map((message) {
                            final fromUser = message['fromUser'] as bool;
                            final text = message['text'] as String;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppThemeEnhanced.md),
                              child: Align(
                                alignment: fromUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppThemeEnhanced.md,
                                    vertical: AppThemeEnhanced.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: fromUser
                                        ? AppThemeEnhanced.primaryColor
                                        : AppThemeEnhanced.backgroundColor,
                                    borderRadius: BorderRadius.circular(
                                      AppThemeEnhanced.borderRadius,
                                    ),
                                    border: fromUser
                                        ? null
                                        : Border.all(
                                            color: AppThemeEnhanced.dividerColor,
                                          ),
                                  ),
                                  child: Text(
                                    text,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: fromUser
                                          ? Colors.white
                                          : AppThemeEnhanced.textDark,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppThemeEnhanced.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: inputController,
                            minLines: 1,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Ask the AI advisor...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppThemeEnhanced.borderRadius,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppThemeEnhanced.md,
                                vertical: AppThemeEnhanced.sm,
                              ),
                            ),
                            onSubmitted: (_) => sendMessage(),
                          ),
                        ),
                        const SizedBox(width: AppThemeEnhanced.md),
                        Container(
                          decoration: BoxDecoration(
                            color: AppThemeEnhanced.primaryColor,
                            borderRadius: BorderRadius.circular(
                              AppThemeEnhanced.borderRadius,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send),
                            color: Colors.white,
                            onPressed: sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    inputController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurantId = context.watch<RestaurantProvider>().restaurantId;

    return Consumer<AnalyticsProvider>(
      builder: (context, analyticsProvider, _) {
        return Scaffold(
          backgroundColor: AppThemeEnhanced.backgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(AppThemeEnhanced.lg),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0, end: 1)
                        .animate(_fadeController),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Insights',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: AppThemeEnhanced.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Real-time performance metrics',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppThemeEnhanced.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if (restaurantId != null)
                              IconButton.filled(
                                icon: const Icon(Icons.auto_awesome),
                                onPressed: () =>
                                    _openAiChat(restaurantId, analyticsProvider),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      AppThemeEnhanced.accentColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: analyticsProvider.isLoading
                      ? Center(
                          child: ModernLoadingIndicator(
                            label: 'Loading analytics...',
                          ),
                        )
                      : analyticsProvider.error != null
                          ? Center(
                              child: EmptyStateWidget(
                                icon: Icons.error_outline,
                                title: 'Error Loading Analytics',
                                subtitle: analyticsProvider.error!,
                                ctaLabel: 'Retry',
                                onCta: restaurantId == null
                                    ? null
                                    : () => context
                                        .read<AnalyticsProvider>()
                                        .loadAnalytics(restaurantId),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppThemeEnhanced.lg,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (analyticsProvider.smartDashboardData !=
                                        null)
                                      _buildSmartDashboard(
                                        context,
                                        analyticsProvider.smartDashboardData!,
                                      ),
                                    if (analyticsProvider.smartDashboardData !=
                                        null)
                                      const SizedBox(height: AppThemeEnhanced.lg),
                                    if (analyticsProvider.profitData != null)
                                      _buildProfitSection(
                                        context,
                                        analyticsProvider.profitData!,
                                      ),
                                    if (analyticsProvider.profitData != null)
                                      const SizedBox(height: AppThemeEnhanced.lg),
                                    if (analyticsProvider.demandData != null)
                                      _buildDemandSection(
                                        context,
                                        analyticsProvider.demandData!,
                                      ),
                                    if (analyticsProvider.demandData != null)
                                      const SizedBox(height: AppThemeEnhanced.lg),
                                    if (analyticsProvider.classificationData !=
                                        null)
                                      _buildClassificationSection(
                                        context,
                                        analyticsProvider.classificationData!,
                                      ),
                                    const SizedBox(height: AppThemeEnhanced.lg),
                                  ],
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmartDashboard(
    BuildContext context,
    Map<String, dynamic> dashboardData,
  ) {
    final forecasts =
        (dashboardData['dish_forecasts'] as List? ?? []).cast<Map>();
    final topForecasts = forecasts.take(5).toList();

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.smart_toy_outlined,
                color: AppThemeEnhanced.primaryColor,
                size: 20,
              ),
              const SizedBox(width: AppThemeEnhanced.md),
              Text(
                'Smart Forecast',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppThemeEnhanced.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeEnhanced.lg),
          if (topForecasts.isEmpty)
            Text(
              'No forecast data available',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppThemeEnhanced.textSecondary,
              ),
            )
          else
            Column(
              children: topForecasts.map((item) {
                final name = item['name']?.toString() ?? 'Unknown';
                final demand =
                    (item['expected_quantity'] as num?)?.toInt() ?? 0;
                final prep =
                    (item['preparation_quantity'] as num?)?.toInt() ?? 0;
                final wasteRisk = item['waste_risk']?.toString() ?? 'low';
                final confidence =
                    (item['confidence'] as num?)?.toDouble() ?? 0.0;

                Color riskColor = AppThemeEnhanced.successColor;
                if (wasteRisk == 'medium') {
                  riskColor = AppThemeEnhanced.warningColor;
                } else if (wasteRisk == 'high') {
                  riskColor = AppThemeEnhanced.errorColor;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppThemeEnhanced.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppThemeEnhanced.md),
                    decoration: BoxDecoration(
                      color: AppThemeEnhanced.backgroundColor,
                      borderRadius: BorderRadius.circular(
                        AppThemeEnhanced.borderRadius,
                      ),
                      border: Border.all(
                        color: AppThemeEnhanced.dividerColor,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppThemeEnhanced.textDark,
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
                                color: riskColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  AppThemeEnhanced.borderRadius,
                                ),
                              ),
                              child: Text(
                                wasteRisk,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: riskColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppThemeEnhanced.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Demand: $demand units',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppThemeEnhanced.textSecondary,
                              ),
                            ),
                            Text(
                              'Prep: $prep',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppThemeEnhanced.accentColor,
                              ),
                            ),
                            Text(
                              '${(confidence * 100).toStringAsFixed(0)}%',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppThemeEnhanced.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildProfitSection(
    BuildContext context,
    Map<String, dynamic> profitData,
  ) {
    final analysis = (profitData['analysis'] as List? ?? [])
        .whereType<Map>()
        .toList();
    
    final totalProfit = analysis.fold<double>(0, (sum, row) {
      return sum +
          ((row['total_profit'] as num?)?.toDouble() ??
              (row['profit'] as num?)?.toDouble() ??
              0);
    });

    final topByProfit = analysis
      ..sort((a, b) {
        final profitA = (a['total_profit'] as num?)?.toDouble() ??
            (a['profit'] as num?)?.toDouble() ??
            0;
        final profitB = (b['total_profit'] as num?)?.toDouble() ??
            (b['profit'] as num?)?.toDouble() ??
            0;
        return profitB.compareTo(profitA);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    color: AppThemeEnhanced.successColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppThemeEnhanced.md),
                  Text(
                    'Profit Analysis',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppThemeEnhanced.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppThemeEnhanced.lg),
              Container(
                padding: const EdgeInsets.all(AppThemeEnhanced.md),
                decoration: BoxDecoration(
                  color: AppThemeEnhanced.successColor.withOpacity(0.1),
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
                          'Total Profit',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppThemeEnhanced.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totalProfit.toStringAsFixed(0)}',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppThemeEnhanced.successColor,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.local_atm_outlined,
                      color: AppThemeEnhanced.successColor,
                      size: 24,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppThemeEnhanced.lg),
              Text(
                'Top Performers',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppThemeEnhanced.textDark,
                ),
              ),
              const SizedBox(height: AppThemeEnhanced.md),
              ...topByProfit.take(3).map((item) {
                final name = item['name']?.toString() ?? 'Unknown';
                final profit = (item['total_profit'] as num?)?.toDouble() ??
                    (item['profit'] as num?)?.toDouble() ??
                    0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppThemeEnhanced.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppThemeEnhanced.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '₹${profit.toStringAsFixed(0)}',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppThemeEnhanced.successColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemandSection(
    BuildContext context,
    Map<String, dynamic> demandData,
  ) {
    final predictions = demandData['predictions'] as Map? ?? {};
    final predictionEntries = predictions.entries.toList();

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_outlined,
                color: AppThemeEnhanced.accentColor,
                size: 20,
              ),
              const SizedBox(width: AppThemeEnhanced.md),
              Text(
                'Demand Prediction',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppThemeEnhanced.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeEnhanced.lg),
          if (predictionEntries.isEmpty)
            Text(
              'No demand predictions available',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppThemeEnhanced.textSecondary,
              ),
            )
          else
            Column(
              children: predictionEntries.take(5).map((entry) {
                final dishData = entry.value is Map ? entry.value as Map : {};
                final name = dishData['name']?.toString() ?? 'Unknown';
                final nextDay =
                    (dishData['next_day'] as num?)?.toInt() ?? 0;
                final nextWeek =
                    (dishData['next_week'] as num?)?.toInt() ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppThemeEnhanced.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppThemeEnhanced.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Tomorrow: $nextDay',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppThemeEnhanced.primaryColor,
                            ),
                          ),
                          Text(
                            'Week: $nextWeek',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppThemeEnhanced.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildClassificationSection(
    BuildContext context,
    Map<String, dynamic> classificationData,
  ) {
    final classifications = classificationData['classifications'] as Map? ?? {};
    final classificationEntries = classifications.entries.toList();

    final stars = <String>[];
    final plowhorses = <String>[];
    final puzzles = <String>[];
    final dogs = <String>[];

    for (final entry in classificationEntries) {
      final dishData = entry.value is Map ? entry.value as Map : {};
      final name = dishData['name']?.toString() ?? 'Unknown';
      final demandLevel = dishData['demand_level']?.toString() ?? 'new';

      if (demandLevel == 'high') {
        stars.add(name);
      } else if (demandLevel == 'medium') {
        plowhorses.add(name);
      } else if (demandLevel == 'watch') {
        puzzles.add(name);
      } else {
        dogs.add(name);
      }
    }

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assessment_outlined,
                color: AppThemeEnhanced.warningColor,
                size: 20,
              ),
              const SizedBox(width: AppThemeEnhanced.md),
              Text(
                'Dish Classification',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppThemeEnhanced.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeEnhanced.lg),
          ...[
            ('⭐ Stars (High Demand)', stars, AppThemeEnhanced.primaryColor),
            ('🐴 Plowhorses (Medium)', plowhorses, AppThemeEnhanced.accentColor),
            ('❓ Puzzles (Watch)', puzzles, AppThemeEnhanced.warningColor),
            ('🐕 Dogs (Low Demand)', dogs, AppThemeEnhanced.errorColor),
          ].map((category) {
            final label = category.$1;
            final items = category.$2 as List<String>;
            final color = category.$3 as Color;

            if (items.isEmpty) return SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: AppThemeEnhanced.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: AppThemeEnhanced.sm,
                    runSpacing: AppThemeEnhanced.sm,
                    children: items.take(4).map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppThemeEnhanced.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            AppThemeEnhanced.borderRadius,
                          ),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Text(
                          item,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (items.length > 4)
                    Text(
                      '+ ${items.length - 4} more',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppThemeEnhanced.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
