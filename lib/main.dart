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

class _DostoyevskyReaderAppState extends State<DostoyevskyReaderApp> {
  static const prefsLangKey = 'language_code';
  static const prefsDarkModeKey = 'dark_mode';
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadDarkMode();
    _checkInitialMessage();
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
        final languageCode = (lang == 'ar' || lang == 'en' || lang == 'ru') ? lang : null;
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
