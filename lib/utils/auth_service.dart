import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Using Web Client ID from google-services.json as serverClientId
  // This works when Android OAuth client is not configured yet
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    // Use Web Client ID as serverClientId for backend authentication
    serverClientId: '792678778149-65pm7p29qdqu0se3160dq83mp5k2kbf9.apps.googleusercontent.com',
  );

  static const String _prefKeyUserType = 'user_type'; // 'google' or 'guest'
  static const String _prefKeyUserId = 'user_id';
  static const String _prefKeyUserName = 'user_name';
  static const String _prefKeyUserEmail = 'user_email';
  static const String _prefKeyUserPhotoUrl = 'user_photo_url';

  static Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyUserType, 'google');
        await prefs.setString(_prefKeyUserId, account.id);
        await prefs.setString(_prefKeyUserName, account.displayName ?? 'User');
        await prefs.setString(_prefKeyUserEmail, account.email);
        await prefs.setString(_prefKeyUserPhotoUrl, account.photoUrl ?? '');
        return true;
      }
      return false;
    } catch (e) {
      print('Error signing in with Google: $e');
      // Print detailed error for debugging
      if (e.toString().contains('SIGN_IN_REQUIRED') || 
          e.toString().contains('DEVELOPER_ERROR') ||
          e.toString().contains('10:')) {
        print('⚠️ Google Sign-In configuration error. Please check:');
        print('   1. SHA-1 certificate is added in Firebase Console');
        print('   2. google-services.json contains Android OAuth client (client_type: 1)');
        print('   3. Package name matches: com.spinel.tolstoy');
      }
      rethrow; // Re-throw to allow better error handling in UI
    }
  }

  static Future<bool> signInAsGuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString(_prefKeyUserType, 'guest');
      await prefs.setString(_prefKeyUserId, 'guest_$timestamp');
      await prefs.setString(_prefKeyUserName, 'Guest User');
      await prefs.setString(_prefKeyUserEmail, '');
      await prefs.setString(_prefKeyUserPhotoUrl, '');
      return true;
    } catch (e) {
      print('Error signing in as guest: $e');
      return false;
    }
  }

  static Future<void> signOut() async {
    try {
      if (await isGoogleUser()) {
        await _googleSignIn.signOut();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyUserType);
      await prefs.remove(_prefKeyUserId);
      await prefs.remove(_prefKeyUserName);
      await prefs.remove(_prefKeyUserEmail);
      await prefs.remove(_prefKeyUserPhotoUrl);
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  static Future<bool> isSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUserType) != null;
  }

  static Future<bool> isGoogleUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUserType) == 'google';
  }

  static Future<bool> isGuestUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUserType) == 'guest';
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUserId);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUserName);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUserEmail);
  }

  static Future<String?> getUserPhotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUserPhotoUrl);
  }
}

