import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final Function(bool) onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isArabic = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final success = await AuthService.signInWithGoogle();
      if (success && mounted) {
        widget.onLoginSuccess(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isArabic ? 'تم إلغاء تسجيل الدخول' : 'Sign in cancelled'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = _isArabic ? 'حدث خطأ في تسجيل الدخول' : 'Sign in error occurred';
        
        // Check for specific error types
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('developer_error') || 
            errorStr.contains('10:') ||
            errorStr.contains('configuration')) {
          errorMessage = _isArabic 
            ? 'خطأ في الإعدادات: تأكد من إضافة SHA-1 في Firebase Console'
            : 'Configuration error: Please add SHA-1 in Firebase Console';
        } else if (errorStr.contains('network')) {
          errorMessage = _isArabic 
            ? 'خطأ في الاتصال بالإنترنت'
            : 'Network error';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
        print('Google Sign-In Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInAsGuest() async {
    setState(() => _isLoading = true);
    try {
      final success = await AuthService.signInAsGuest();
      if (success && mounted) {
        widget.onLoginSuccess(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isArabic ? 'حدث خطأ' : 'An error occurred'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    _isArabic = locale.languageCode == 'ar';
    final theme = Theme.of(context);
    const sepiaBackground = Color(0xFFF4E7D3);

    return Scaffold(
      backgroundColor: sepiaBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon/Logo
                Icon(
                  Icons.menu_book_rounded,
                  size: 100,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  _isArabic ? 'مكتبة دوستويفسكي' : 'Dostoyevsky Library',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Subtitle
                Text(
                  _isArabic 
                    ? 'سجل الدخول للتعليق ومشاركة أفكارك'
                    : 'Sign in to comment and share your thoughts',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Google Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Image.network(
                            'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                            height: 24,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.account_circle),
                          ),
                    label: Text(
                      _isArabic ? 'تسجيل الدخول بحساب Google' : 'Sign in with Google',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.colorScheme.outline)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _isArabic ? 'أو' : 'OR',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: theme.colorScheme.outline)),
                  ],
                ),
                const SizedBox(height: 16),

                // Guest Login Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInAsGuest,
                    icon: const Icon(Icons.person_outline),
                    label: Text(
                      _isArabic ? 'متابعة كزائر' : 'Continue as Guest',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Info Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _isArabic
                        ? 'يمكنك الاستمرار كزائر لعرض التعليقات، لكنك ستحتاج لتسجيل الدخول للتعليق'
                        : 'You can continue as guest to view comments, but you need to sign in to comment',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

