import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/home_screen.dart';
import 'screens/language_selection_screen.dart';
import 'utils/ad_helper.dart';
import 'utils/fcm_service.dart';
import 'firebase_messaging_background_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();
  debugPrint('✅ Firebase initialized');

  // Register background message handler
  // This must be registered before runApp()
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  debugPrint('✅ FCM Background handler registered');

  // Initialize AdMob
  await AdHelper.initialize();

  // Initialize FCM Service
  await FCMService.initialize();

  runApp(const DostoyevskyReaderApp());
}

class DostoyevskyReaderApp extends StatefulWidget {
  const DostoyevskyReaderApp({super.key});

  @override
  State<DostoyevskyReaderApp> createState() => _DostoyevskyReaderAppState();
}

class _DostoyevskyReaderAppState extends State<DostoyevskyReaderApp>
    with WidgetsBindingObserver {
  static const prefsLangKey = 'language_code';
  static const prefsDarkModeKey = 'dark_mode';
  bool _isDarkMode = false;
  bool _hasShownAppOpenAd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDarkMode();
    _checkInitialMessage();
    // Load App Open Ad after initialization
    _loadAppOpenAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('📱 App lifecycle state changed: $state');

    // Show App Open Ad when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed - checking App Open Ad...');
      if (!_hasShownAppOpenAd && AdHelper.isAppOpenAdReady()) {
        _hasShownAppOpenAd = true;
        AdHelper.showAppOpenAd();
        // Reset flag after a delay to allow showing ad again later
        Future.delayed(const Duration(minutes: 5), () {
          _hasShownAppOpenAd = false;
        });
      } else if (!AdHelper.isAppOpenAdReady()) {
        // Load ad if not ready
        _loadAppOpenAd();
      }
    }
  }

  int _appOpenAdRetryCount = 0;
  static const int _maxAppOpenAdRetries = 5;

  void _loadAppOpenAd() {
    if (_appOpenAdRetryCount >= _maxAppOpenAdRetries) {
      debugPrint(
        '⚠️ App Open Ad: Max retries reached ($_maxAppOpenAdRetries). Stopping retries.',
      );
      return;
    }

    debugPrint(
      '📱 [AD LOADING] Loading App Open Ad... (Attempt ${_appOpenAdRetryCount + 1}/$_maxAppOpenAdRetries)',
    );
    AdHelper.loadAppOpenAd(
      onAdLoaded: () {
        debugPrint('✅✅✅ [AD LOADING] App Open Ad loaded successfully! ✅✅✅');
        _appOpenAdRetryCount = 0; // Reset retry count on success
        // Show ad immediately after first load
        if (!_hasShownAppOpenAd) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && AdHelper.isAppOpenAdReady()) {
              _hasShownAppOpenAd = true;
              AdHelper.showAppOpenAd();
            }
          });
        }
      },
      onAdFailedToLoad: (error) {
        _appOpenAdRetryCount++;
        debugPrint(
          '❌ [AD LOADING] App Open Ad failed to load (Attempt $_appOpenAdRetryCount/$_maxAppOpenAdRetries)',
        );
        debugPrint('❌ [AD LOADING] Error: ${error.message}');
        debugPrint('❌ [AD LOADING] Error code: ${error.code}');

        // Check if it's a network error
        final isNetworkError =
            error.code == 0 ||
            error.message.toLowerCase().contains('network') ||
            error.message.toLowerCase().contains('timeout') ||
            error.message.toLowerCase().contains('connection') ||
            error.message.toLowerCase().contains('internet');

        if (isNetworkError) {
          debugPrint(
            '⚠️ [AD LOADING] Network error detected - using longer retry delay',
          );
        }

        // Exponential backoff: 5s, 10s, 15s, 20s, 30s
        final delaySeconds = _appOpenAdRetryCount <= 1
            ? 5
            : _appOpenAdRetryCount <= 2
            ? 10
            : _appOpenAdRetryCount <= 3
            ? 15
            : _appOpenAdRetryCount <= 4
            ? 20
            : 30;

        debugPrint('🔄 [AD LOADING] Retrying in $delaySeconds seconds...');
        Future.delayed(Duration(seconds: delaySeconds), () {
          if (mounted && _appOpenAdRetryCount < _maxAppOpenAdRetries) {
            _loadAppOpenAd();
          } else if (_appOpenAdRetryCount >= _maxAppOpenAdRetries) {
            debugPrint(
              '⚠️ [AD LOADING] Max retries reached. App Open Ad will not load.',
            );
          }
        });
      },
    );
  }

  /// Check if app was opened from a notification (when app was terminated)
  Future<void> _checkInitialMessage() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    final RemoteMessage? initialMessage = await messaging.getInitialMessage();

    if (initialMessage != null && mounted) {
      debugPrint('📨 App opened from notification (terminated state):');
      debugPrint('   Title: ${initialMessage.notification?.title}');
      debugPrint('   Body: ${initialMessage.notification?.body}');
      debugPrint('   Data: ${initialMessage.data}');

      // You can handle navigation here based on message.data
      // Example: Navigate to a specific screen
      // Navigator.of(context).pushNamed('/some-route');
    }
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool(prefsDarkModeKey) ?? false;
    });
  }

  Future<String?> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefsLangKey);
  }

  Future<void> _saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsLangKey, code);
  }

  void toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsDarkModeKey, value);
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    const sepiaBackground = Color(0xFFF4E7D3);
    const darkBackground = Color(0xFF121212);

    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7A4E2E),
      brightness: Brightness.light,
      surface: sepiaBackground,
    );

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7A4E2E),
      brightness: Brightness.dark,
      surface: darkBackground,
    );

    return FutureBuilder<String?>(
      future: _loadLanguage(),
      builder: (context, snapshot) {
        final lang = snapshot.data; // null => first launch
        final languageCode = (lang == 'ar' || lang == 'en' || lang == 'ru')
            ? lang
            : null;
        final isArabic = languageCode == 'ar';

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Dostoyevsky Reader (Offline)',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            scaffoldBackgroundColor: sepiaBackground,
            appBarTheme: AppBarTheme(
              centerTitle: true,
              backgroundColor: sepiaBackground,
              foregroundColor: lightColorScheme.onSurface,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor: darkBackground,
            appBarTheme: AppBarTheme(
              centerTitle: true,
              backgroundColor: darkBackground,
              foregroundColor: darkColorScheme.onSurface,
              elevation: 0,
            ),
          ),
          themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
          locale: languageCode == null ? null : Locale(languageCode),
          supportedLocales: const [Locale('ar'), Locale('en'), Locale('ru')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;
            return Directionality(
              textDirection: direction,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: Builder(
            builder: (context) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (languageCode == null) {
                return LanguageSelectionScreen(
                  onSelected: (code) async {
                    await _saveLanguage(code);
                    if (!context.mounted) return;
                    // Rebuild MaterialApp by forcing a new app instance route.
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const DostoyevskyReaderApp(),
                      ),
                    );
                  },
                );
              }

              return HomeScreen(
                languageCode: languageCode,
                onDarkModeChanged: toggleDarkMode,
                isDarkMode: _isDarkMode,
              );
            },
          ),
        );
      },
    );
  }
}
