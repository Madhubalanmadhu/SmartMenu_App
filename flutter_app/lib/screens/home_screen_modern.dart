import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme_enhanced.dart';
import '../providers/analytics_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/waste_provider.dart';
import '../widgets/modern_ui_components.dart';
import 'analytics_screen_modern.dart';
import 'menu_screen_modern.dart';
import 'profile_screen.dart';
import 'sales_screen_modern.dart';
import 'waste_screen_modern.dart';

class HomeScreenModern extends StatefulWidget {
  const HomeScreenModern({super.key});

  @override
  State<HomeScreenModern> createState() => _HomeScreenModernState();
}

class _HomeScreenModernState extends State<HomeScreenModern>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  Timer? _intelligenceRefreshTimer;
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: AppThemeEnhanced.mediumDuration,
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final restaurantProvider = context.read<RestaurantProvider>();
      if (restaurantProvider.restaurantId == null) {
        await restaurantProvider.loadRestaurant();
      }

      final restaurantId = restaurantProvider.restaurantId;
      if (restaurantId != null && mounted) {
        _loadAllData(restaurantId);
        _startIntelligenceRefresh(restaurantId);
      }
    });
  }

  void _loadAllData(int restaurantId) {
    context.read<MenuProvider>().loadDishes(restaurantId);
    context.read<SalesProvider>().loadSales(restaurantId);
    context.read<WasteProvider>().loadWaste(restaurantId);
    context.read<AnalyticsProvider>().loadAnalytics(restaurantId);
  }

  void _startIntelligenceRefresh(int restaurantId) {
    _intelligenceRefreshTimer?.cancel();
    _intelligenceRefreshTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) {
        if (!mounted) return;
        context.read<AnalyticsProvider>().loadAnalytics(restaurantId);
      },
    );
  }

  @override
  void dispose() {
    _intelligenceRefreshTimer?.cancel();
    _fabController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    setState(() => _currentIndex = index);

    if (index == 0 || index == 3) {
      final restaurantId = context.read<RestaurantProvider>().restaurantId;
      if (restaurantId != null) {
        context.read<AnalyticsProvider>().loadAnalytics(restaurantId);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ModernToast.show(
          context,
          message: 'Logout failed: ${e.toString()}',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreenModern(onNavigate: _goToTab),
      const MenuScreenModern(),
      const SalesScreenModern(),
      const AnalyticsScreenModern(),
      const WasteScreenModern(),
    ];

    return Scaffold(
      backgroundColor: AppThemeEnhanced.background,
      appBar: _buildAppBar(),
      body: PageTransitionSwitcher(
        transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
          return FadeTransition(opacity: primaryAnimation, child: child);
        },
        child: screens[_currentIndex],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppThemeEnhanced.surface,
      elevation: 0,
      title: Text(
        'SmartMenu',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppThemeEnhanced.textPrimary,
        ),
      ),
      centerTitle: false,
      actions: [
        Consumer<RestaurantProvider>(
          builder: (context, restaurantProvider, _) {
            return Padding(
              padding: EdgeInsets.only(right: AppThemeEnhanced.md),
              child: Center(
                child: Text(
                  restaurantProvider.restaurantName ?? 'Restaurant',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppThemeEnhanced.textMuted,
                  ),
                ),
              ),
            );
          },
        ),
        PopupMenuButton<String>(
          position: PopupMenuPosition.under,
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_rounded,
                      color: AppThemeEnhanced.primary, size: 20),
                  SizedBox(width: AppThemeEnhanced.sm),
                  const Text('Profile'),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded,
                      color: AppThemeEnhanced.error, size: 20),
                  SizedBox(width: AppThemeEnhanced.sm),
                  const Text('Logout'),
                ],
              ),
              onTap: _logout,
            ),
          ],
          icon: Container(
            padding: EdgeInsets.all(AppThemeEnhanced.xs),
            decoration: BoxDecoration(
              color: AppThemeEnhanced.surfaceLight,
              borderRadius: BorderRadius.circular(AppThemeEnhanced.radiusMd),
              border: Border.all(
                color: AppThemeEnhanced.divider,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.more_vert_rounded,
              color: AppThemeEnhanced.textSecondary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeEnhanced.surface,
        border: Border(
          top: BorderSide(
            color: AppThemeEnhanced.divider,
            width: 1,
          ),
        ),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedIndex: _currentIndex,
        onDestinationSelected: _goToTab,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            selectedIcon: Icon(Icons.dashboard_rounded,
                color: AppThemeEnhanced.primary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_rounded),
            selectedIcon: Icon(Icons.restaurant_menu_rounded,
                color: AppThemeEnhanced.primary),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_rounded),
            selectedIcon:
                Icon(Icons.point_of_sale_rounded, color: AppThemeEnhanced.primary),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_rounded),
            selectedIcon:
                Icon(Icons.analytics_rounded, color: AppThemeEnhanced.primary),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.delete_rounded),
            selectedIcon:
                Icon(Icons.delete_rounded, color: AppThemeEnhanced.primary),
            label: 'Waste',
          ),
        ],
      ),
    );
  }
}

/// Modern Dashboard Screen with enhanced UI and animations
class DashboardScreenModern extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const DashboardScreenModern({
    Key? key,
    required this.onNavigate,
  }) : super(key: key);

  @override
  State<DashboardScreenModern> createState() => _DashboardScreenModernState();
}

class _DashboardScreenModernState extends State<DashboardScreenModern>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: AppThemeEnhanced.mediumDuration,
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurantProvider = context.watch<RestaurantProvider>();
    final analyticsProvider = context.watch<AnalyticsProvider>();
    final salesProvider = context.watch<SalesProvider>();
    final menuProvider = context.watch<MenuProvider>();
    final wasteProvider = context.watch<WasteProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        final restaurantId = restaurantProvider.restaurantId;
        if (restaurantId != null) {
          await analyticsProvider.loadAnalytics(restaurantId);
        }
      },
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(AppThemeEnhanced.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              _buildHeader(restaurantProvider),
              SizedBox(height: AppThemeEnhanced.lg),

              // Key Metrics Cards
              _buildMetricsSection(
                analyticsProvider,
                salesProvider,
                menuProvider,
                wasteProvider,
              ),
              SizedBox(height: AppThemeEnhanced.lg),

              // Forecast Section
              _buildForecastSection(analyticsProvider, context),
              SizedBox(height: AppThemeEnhanced.lg),

              // Quick Actions
              _buildQuickActions(),
              SizedBox(height: AppThemeEnhanced.lg),

              // Recommendations
              _buildRecommendationsSection(analyticsProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(RestaurantProvider restaurantProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operations Dashboard',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppThemeEnhanced.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: AppThemeEnhanced.sm),
        Text(
          'Plan prep from sales, profit, and demand forecasts',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppThemeEnhanced.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsSection(
    AnalyticsProvider analyticsProvider,
    SalesProvider salesProvider,
    MenuProvider menuProvider,
    WasteProvider wasteProvider,
  ) {
    final dashboardData = analyticsProvider.smartDashboardData;
    final expectedSales =
        ((dashboardData?['expected_sales'] as num?)?.toDouble() ?? 0);
    final expectedCustomers =
        (dashboardData?['expected_customers'] as num?)?.toInt() ?? 0;
    final forecasts = (dashboardData?['dish_forecasts'] as List? ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppThemeEnhanced.textPrimary,
          ),
        ),
        SizedBox(height: AppThemeEnhanced.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 600;
            return Wrap(
              spacing: AppThemeEnhanced.md,
              runSpacing: AppThemeEnhanced.md,
              children: [
                SizedBox(
                  width: isSmall
                      ? double.infinity
                      : (constraints.maxWidth - AppThemeEnhanced.md) / 2,
                  child: _buildMetricCard(
                    title: 'Expected Sales',
                    value: _formatMoney(expectedSales),
                    icon: Icons.trending_up_rounded,
                    color: AppThemeEnhanced.success,
                    isLoading: analyticsProvider.isLoading,
                  ),
                ),
                SizedBox(
                  width: isSmall
                      ? double.infinity
                      : (constraints.maxWidth - AppThemeEnhanced.md) / 2,
                  child: _buildMetricCard(
                    title: 'Expected Customers',
                    value: expectedCustomers.toString(),
                    icon: Icons.people_rounded,
                    color: AppThemeEnhanced.accent,
                    isLoading: analyticsProvider.isLoading,
                  ),
                ),
                SizedBox(
                  width: isSmall
                      ? double.infinity
                      : (constraints.maxWidth - AppThemeEnhanced.md) / 2,
                  child: _buildMetricCard(
                    title: 'Menu Items',
                    value: menuProvider.dishes.length.toString(),
                    icon: Icons.restaurant_menu_rounded,
                    color: AppThemeEnhanced.primary,
                    isLoading: menuProvider.isLoading,
                  ),
                ),
                SizedBox(
                  width: isSmall
                      ? double.infinity
                      : (constraints.maxWidth - AppThemeEnhanced.md) / 2,
                  child: _buildMetricCard(
                    title: 'Waste Units',
                    value: _calculateWasteUnits(wasteProvider).toString(),
                    icon: Icons.delete_rounded,
                    color: AppThemeEnhanced.warning,
                    isLoading: wasteProvider.isLoading,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isLoading,
  }) {
    return ModernCard(
      padding: EdgeInsets.all(AppThemeEnhanced.md),
      backgroundColor: AppThemeEnhanced.surfaceLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppThemeEnhanced.sm),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppThemeEnhanced.radiusMd),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: AppThemeEnhanced.md),
          if (isLoading)
            SkeletonLoader(
              width: 60,
              height: 24,
              borderRadius: AppThemeEnhanced.radiusSm,
            )
          else
            Text(
              value,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppThemeEnhanced.textPrimary,
              ),
            ),
          SizedBox(height: AppThemeEnhanced.xs),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppThemeEnhanced.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastSection(
    AnalyticsProvider analyticsProvider,
    BuildContext context,
  ) {
    final dashboardData = analyticsProvider.smartDashboardData;
    final forecasts = (dashboardData?['dish_forecasts'] as List? ?? [])
        .whereType<Map>()
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Prep Priorities',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppThemeEnhanced.textPrimary,
          ),
        ),
        SizedBox(height: AppThemeEnhanced.md),
        if (analyticsProvider.isLoading)
          Column(
            children: List.generate(
              3,
              (index) => Padding(
                padding: EdgeInsets.only(bottom: AppThemeEnhanced.md),
                child: SkeletonLoader(
                  width: double.infinity,
                  height: 80,
                  borderRadius: AppThemeEnhanced.radiusLg,
                ),
              ),
            ),
          )
        else if (forecasts.isEmpty)
          EmptyStateWidget(
            icon: Icons.restaurant_menu_rounded,
            title: 'No Data Yet',
            subtitle: 'Add sales data to see prep recommendations',
            actionLabel: 'Add Sales',
            onActionPressed: () => widget.onNavigate(2),
          )
        else
          Column(
            children: List.generate(
              forecasts.length,
              (index) {
                final forecast = forecasts[index];
                final name = forecast['name'] ?? 'Unknown';
                final prepQty = forecast['preparation_quantity'] ?? 0;
                final expectedQty = forecast['expected_quantity'] ?? 0;
                final margin = forecast['margin'] ?? 0;

                return Padding(
                  padding: EdgeInsets.only(bottom: AppThemeEnhanced.md),
                  child: ModernCard(
                    padding: EdgeInsets.all(AppThemeEnhanced.md),
                    child: Row(
                      children: [
                        // Rank Badge
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppThemeEnhanced.primary,
                                AppThemeEnhanced.primaryLight,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppThemeEnhanced.radiusCircle,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: AppThemeEnhanced.md),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppThemeEnhanced.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: AppThemeEnhanced.xs),
                              Row(
                                children: [
                                  Icon(Icons.local_fire_department_rounded,
                                      size: 14, color: AppThemeEnhanced.warning),
                                  SizedBox(width: AppThemeEnhanced.xs),
                                  Text(
                                    'Prep: $prepQty | Expected: $expectedQty',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: AppThemeEnhanced.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Margin Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemeEnhanced.sm,
                            vertical: AppThemeEnhanced.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeEnhanced.success.withOpacity(0.2),
                            borderRadius:
                                BorderRadius.circular(AppThemeEnhanced.radiusSm),
                          ),
                          child: Text(
                            '${(margin * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppThemeEnhanced.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppThemeEnhanced.textPrimary,
          ),
        ),
        SizedBox(height: AppThemeEnhanced.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 600;
            final actions = [
              (
                title: 'Add Dish',
                subtitle: 'Manage menu',
                icon: Icons.add_rounded,
                index: 1,
              ),
              (
                title: 'Enter Sales',
                subtitle: 'Log today',
                icon: Icons.point_of_sale_rounded,
                index: 2,
              ),
              (
                title: 'View Insights',
                subtitle: 'AI suggestions',
                icon: Icons.lightbulb_rounded,
                index: 3,
              ),
            ];

            return Wrap(
              spacing: AppThemeEnhanced.md,
              runSpacing: AppThemeEnhanced.md,
              children: List.generate(
                actions.length,
                (index) {
                  final action = actions[index];
                  return SizedBox(
                    width: isSmall
                        ? double.infinity
                        : (constraints.maxWidth - AppThemeEnhanced.md * 2) / 3,
                    child: ModernButton(
                      label: action.title,
                      onPressed: () => widget.onNavigate(action.index),
                      icon: action.icon,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecommendationsSection(AnalyticsProvider analyticsProvider) {
    final dashboardData = analyticsProvider.smartDashboardData;
    final recommendations = (dashboardData?['recommendations'] as List? ?? [])
        .take(2)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Recommendations',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppThemeEnhanced.textPrimary,
          ),
        ),
        SizedBox(height: AppThemeEnhanced.md),
        if (recommendations.isEmpty)
          ModernCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(AppThemeEnhanced.lg),
                child: Text(
                  '✨ Add sales data to get AI-powered insights',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppThemeEnhanced.textMuted,
                  ),
                ),
              ),
            ),
          )
        else
          Column(
            children: List.generate(
              recommendations.length,
              (index) {
                final rec = recommendations[index] is Map
                    ? recommendations[index] as Map
                    : {};
                final message = rec['message'] ?? 'Recommendation available';

                return Padding(
                  padding: EdgeInsets.only(bottom: AppThemeEnhanced.md),
                  child: ModernCard(
                    showGradient: true,
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: AppThemeEnhanced.primary,
                          size: 24,
                        ),
                        SizedBox(width: AppThemeEnhanced.md),
                        Expanded(
                          child: Text(
                            message,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppThemeEnhanced.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  int _calculateWasteUnits(WasteProvider wasteProvider) {
    final patterns = wasteProvider.wastePatterns?['patterns'];
    if (patterns is! Map) return 0;

    return patterns.values.fold<int>(0, (sum, entry) {
      final data = entry is Map ? entry : {};
      return sum + ((data['total_wasted'] as num?)?.toInt() ?? 0);
    });
  }

  String _formatMoney(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }
}

/// Page transition switcher for smooth transitions
class PageTransitionSwitcher extends StatelessWidget {
  final Widget child;
  final AnimatedSwitcherTransitionBuilder transitionBuilder;

  const PageTransitionSwitcher({
    Key? key,
    required this.child,
    required this.transitionBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppThemeEnhanced.mediumDuration,
      transitionBuilder: transitionBuilder,
      child: child,
    );
  }
}
