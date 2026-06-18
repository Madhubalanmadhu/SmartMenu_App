import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'services/api_service.dart';
import 'providers/restaurant_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/waste_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/restaurant_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  Object? firebaseInitializationError;
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey.isEmpty || options.apiKey.contains('YOUR_') || options.apiKey == 'null') {
      throw Exception('Firebase API Key is empty or not configured. Please set your repository secrets.');
    }
    await Firebase.initializeApp(
      options: options,
    );
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
  } catch (e) {
    firebaseInitializationError = e;
    debugPrint('Firebase initialization error: $e');
  }

  if (firebaseInitializationError != null) {
    runApp(FirebaseConfigErrorApp(error: firebaseInitializationError));
    return;
  }

  runApp(const MyApp());
}

class FirebaseConfigErrorApp extends StatelessWidget {
  final Object error;

  const FirebaseConfigErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 42),
                      const SizedBox(height: 16),
                      Text(
                        'Firebase is not configured for this run',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Start the app with .\\run_web.ps1 so the Firebase values in .env are passed as dart-defines. If you already did that, re-check the Web API key in Firebase Console.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<ApiService, RestaurantProvider>(
          create: (context) => RestaurantProvider(context.read<ApiService>()),
          update: (context, apiService, previous) =>
              previous ?? RestaurantProvider(apiService),
        ),
        ChangeNotifierProxyProvider<ApiService, AnalyticsProvider>(
          create: (context) => AnalyticsProvider(context.read<ApiService>()),
          update: (context, apiService, previous) =>
              previous ?? AnalyticsProvider(apiService),
        ),
        ChangeNotifierProxyProvider<ApiService, MenuProvider>(
          create: (context) => MenuProvider(context.read<ApiService>()),
          update: (context, apiService, previous) =>
              previous ?? MenuProvider(apiService),
        ),
        ChangeNotifierProxyProvider<ApiService, SalesProvider>(
          create: (context) => SalesProvider(context.read<ApiService>()),
          update: (context, apiService, previous) =>
              previous ?? SalesProvider(apiService),
        ),
        ChangeNotifierProxyProvider<ApiService, WasteProvider>(
          create: (context) => WasteProvider(context.read<ApiService>()),
          update: (context, apiService, previous) =>
              previous ?? WasteProvider(apiService),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'SmartMenu',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthGate(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/home': (_) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return _AuthenticatedHome(user: user);
      },
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  final User user;

  const _AuthenticatedHome({required this.user});

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  late Future<void> _bootstrapFuture;
  String? _token;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrapSession();
  }

  @override
  void didUpdateWidget(covariant _AuthenticatedHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _bootstrapFuture = _bootstrapSession();
    }
  }

  Future<void> _bootstrapSession() async {
    final token = await widget.user.getIdToken();
    if (token == null) {
      throw Exception('Unable to restore authentication token');
    }

    if (!mounted) return;
    final apiService = context.read<ApiService>();
    final restaurantProvider = context.read<RestaurantProvider>();
    apiService.setToken(token);
    _token = token;
    await apiService.registerUser(
      widget.user.email ?? '${widget.user.uid}@firebase.local',
      widget.user.displayName?.trim().isNotEmpty == true
          ? widget.user.displayName!.trim()
          : widget.user.email ?? 'SmartMenu User',
      widget.user.uid,
    );
    await restaurantProvider.loadRestaurant();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const LoginScreen();
        }

        final restaurantProvider = context.read<RestaurantProvider>();
        if (restaurantProvider.restaurantId == null) {
          return RestaurantSetupScreen(userToken: _token!);
        }

        return const HomeScreen();
      },
    );
  }
}
