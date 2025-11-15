// ===========================================
// lib/services/auth_service.dart (FIXED VERSION)
// ===========================================

import 'dart:async';
import 'package:capstone_app/services/secure_session_service.dart';
import 'package:capstone_app/services/session_services.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for authentication and user management.
class AuthService {
  /// Checks if an email already exists in the database
  static Future<void> setPersistence() async {
    try {
      if (kIsWeb) {
        // For web, set persistence to LOCAL (survives browser restarts)
        await _auth.setPersistence(Persistence.LOCAL);
      }
      // For mobile, persistence is automatic, but we can ensure it's working
      debugPrint('Auth persistence configured');
    } catch (e) {
      debugPrint('Error setting persistence: $e');
    }
  }

  /// Check if user is authenticated and session is valid
  static Future<bool> isUserAuthenticated() async {
    try {
      // Wait for Firebase Auth to restore session (can take up to 2 seconds on mobile)
      // Listen to authStateChanges stream to ensure auth state is ready
      User? user;
      bool authReady = false;
      
      // Wait up to 3 seconds for auth state to restore
      final completer = Completer<bool>();
      final subscription = _auth.authStateChanges().listen((User? authUser) {
        user = authUser;
        if (!authReady) {
          authReady = true;
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        }
      });

      // Wait for first auth state event or timeout after 3 seconds
      try {
        await completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Auth state initialization timeout - checking current user');
            authReady = true;
            user = _auth.currentUser;
            return true; // Return value for timeout handler
          },
        );
      } catch (e) {
        debugPrint('Error waiting for auth state: $e');
      } finally {
        await subscription.cancel();
      }

      // Give it a bit more time for auth to fully restore
      if (user == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        user = _auth.currentUser;
      }

      if (user == null) {
        debugPrint('No user found after waiting for auth state');
        return false;
      }

      // Try to reload user, but don't fail if it errors (network issues)
      try {
        await user!.reload();
        // Get the refreshed user
        user = _auth.currentUser;
      } catch (e) {
        debugPrint('Error reloading user (non-critical): $e');
        // Continue with original user if reload fails
        if (_auth.currentUser == null) {
          return false;
        }
        user = _auth.currentUser;
      }

      if (user != null) {
        debugPrint('User authenticated: ${user!.email ?? user!.uid}');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking authentication: $e');
      // Last resort: check currentUser directly
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        debugPrint('Fallback: User authenticated via currentUser: ${currentUser.email ?? currentUser.uid}');
        return true;
      }
      return false;
    }
  }

  /// Enhanced sign in that ensures persistence
  static Future<UserCredential?> signInWithEmailPasswordWithPersistence({
    required String email,
    required String password,
  }) async {
    try {
      // Set persistence before signing in
      await setPersistence();

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ensure user document exists in Firestore
      if (userCredential.user != null) {
        // Ensure user document exists in Firestore
        await _ensureUserDocumentExists(userCredential.user!);
        final userDoc =
            await FirebaseFirestore.instance
                .collection('Users')
                .doc(userCredential.user!.uid)
                .get();
        final role = userDoc.data()?['role'] ?? '';

        await SecureSessionService.storeSession(
          userCredential.user!.uid,
          userCredential.user!.email ?? '',
          role,
        );

        await _storeLoginState(userCredential.user!);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authUnexpectedError(e.toString());
    }
  }

  /// Enhanced Google Sign-In with persistence
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Set persistence before signing in
      await setPersistence();

      UserCredential userCredential;

      if (kIsWeb) {
        // Web-specific implementation using popup
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile implementation
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      // Handle post-authentication setup
      if (userCredential.user != null) {
        await _handlePostAuthentication(userCredential);

        // Fetch role from Firestore
        String role = '';
        try {
          final doc =
              await FirebaseFirestore.instance
                  .collection('Users')
                  .doc(userCredential.user!.uid)
                  .get();
          final data = doc.data();
          role = data?['role'] ?? '';
          if (role.trim().isEmpty) {
            role = 'Tourist'; // fallback
          }
        } catch (e) {
          debugPrint('Error fetching user role for session: $e');
        }

        // Store login state in SharedPreferences as backup
        await SecureSessionService.storeSession(
          userCredential.user!.uid,
          userCredential.user!.email ?? '',
          role,
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authGoogleSignInFailed(e.toString());
    }
  }

  /// Store login state in SharedPreferences
  static Future<void> _storeLoginState(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_id', user.uid);
      await prefs.setString('user_email', user.email ?? '');
      debugPrint('Login state stored for ${user.email}');
    } catch (e) {
      debugPrint('Error storing login state: $e');
    }
  }

  /// Clear login state from SharedPreferences
  static Future<void> _clearLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      debugPrint('Login state cleared');
    } catch (e) {
      debugPrint('Error clearing login state: $e');
    }
  }

  /// Check stored login state
  static Future<bool> hasStoredLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_logged_in') ?? false;
    } catch (e) {
      debugPrint('Error checking stored login state: $e');
      return false;
    }
  }

  /// Enhanced sign out that clears all persistence
  static Future<void> signOutWithPersistence() async {
    try {
      await _clearLoginState();
      await SecureSessionService.clearSession();
      if (kIsWeb) {
        await _auth.signOut();
      } else {
        await Future.wait([_auth.signOut(), GoogleSignIn().signOut()]);
      }
      await _clearStoredEmail();

      debugPrint('User signed out with persistence');
    } catch (e) {
      throw AppConstants.authFailedToSignOut(e.toString());
    }
  }

  /// Initialize auth state on app start
  static Future<void> initializeAuthState() async {
    try {
      // Set persistence first
      await setPersistence();

      // Wait for Firebase Auth to restore session (important for mobile)
      // Listen to authStateChanges to ensure auth is fully initialized
      User? currentUser;
      final completer = Completer<void>();
      bool authInitialized = false;
      
      final subscription = _auth.authStateChanges().listen((User? user) {
        if (!authInitialized) {
          authInitialized = true;
          currentUser = user;
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      });

      // Wait for first auth state event or timeout after 2 seconds
      try {
        await completer.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('Auth state initialization timeout - using currentUser');
            currentUser = _auth.currentUser;
          },
        );
      } catch (e) {
        debugPrint('Error waiting for auth state initialization: $e');
        currentUser = _auth.currentUser;
      } finally {
        await subscription.cancel();
      }

      // Give Firebase Auth a bit more time to fully restore
      if (currentUser == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        currentUser = _auth.currentUser;
      }

      // Check if user should be authenticated
      final hasStoredState = await hasStoredLoginState();

      if (currentUser != null) {
        // User is authenticated, ensure document exists
        try {
          await _ensureUserDocumentExists(currentUser!);
          debugPrint('Auth state initialized for ${currentUser!.email ?? currentUser!.uid}');
        } catch (e) {
          debugPrint('Error ensuring user document exists: $e');
          // Don't fail initialization if document check fails
        }
      } else if (hasStoredState) {
        // Had stored state but no Firebase user after waiting - might be clearing
        // Wait a bit more before clearing (in case auth is still restoring)
        await Future.delayed(const Duration(milliseconds: 500));
        final doubleCheckUser = _auth.currentUser;
        if (doubleCheckUser == null) {
          await _clearLoginState();
          debugPrint('Cleared orphaned login state');
        } else {
          debugPrint('User found on second check: ${doubleCheckUser.email ?? doubleCheckUser.uid}');
        }
      } else {
        debugPrint('No stored login state and no current user');
      }
    } catch (e) {
      debugPrint('Error initializing auth state: $e');
      // Don't rethrow - let the app continue even if initialization has issues
    }
  }

  static Future<bool> emailExists(String email) async {
    try {
      // Check if email exists in Firestore 'Users' collection
      final query =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('email', isEqualTo: email.toLowerCase().trim())
              .limit(1)
              .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if email exists: $e');
      return false;
    }
  }

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _emailKey = 'pending_email';

  /// Returns the current Firebase user, or null if not signed in.
  static User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes.
  static Stream<User?> get authStateChanges => _auth.authStateChanges();


  /// Sign up with email and password.
  /// This method creates a new user account and stores the user data in Firestore.
  /// Returns the UserCredential if successful, or null if an error occurs.
  static Future<UserCredential?> signUpWithEmailPassword({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = credential.user;
      if (user == null) return null;

      // Add user to Firestore
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'email': user.email ?? '',
            'role': role,
            'form_completed': false,
            'app_email_verified': user.emailVerified,
            'createdAt': FieldValue.serverTimestamp(),
          });

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected sign-up error: $e');
      rethrow;
    }
  }

  /// Sign in with email and password.
  /// This method authenticates the user and ensures their document exists in Firestore.
  /// Returns the UserCredential if successful, or null if an error occurs.
  static Future<UserCredential?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ensure user document exists in Firestore
      if (userCredential.user != null) {
        await _ensureUserDocumentExists(userCredential.user!);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authUnexpectedError(e.toString());
    }
  }

  /// Google Sign-In method with proper web and mobile support.
  static Future<UserCredential?> signInWithGoogleBasic() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Web-specific implementation using popup
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile implementation
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      // Handle post-authentication setup
      if (userCredential.user != null) {
        await _handlePostAuthentication(userCredential);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authGoogleSignInFailed(e.toString());
    }
  }

  /// Handle post-authentication tasks (ensure document exists, handle verification)
  static Future<void> _handlePostAuthentication(
    UserCredential userCredential,
  ) async {
    final user = userCredential.user!;
    final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

    try {
      // First, ensure the user document exists
      await _ensureUserDocumentExists(user, isNewUser: isNewUser);

      // Then handle email verification
      await user.reload();
      final updatedUser = _auth.currentUser;

      if (updatedUser != null) {
        final needsVerification = isNewUser || !updatedUser.emailVerified;

        if (needsVerification) {
          // Send verification email
          await updatedUser.sendEmailVerification(
            ActionCodeSettings(
              url: AppConstants.authActionUrl,
              handleCodeInApp: true,
              androidInstallApp: true,
              androidMinimumVersion: '12',
            ),
          );
          debugPrint('Verification email sent to: ${updatedUser.email}');
        }

        // Update the app_email_verified field safely
        await setAppEmailVerified(user.uid, value: updatedUser.emailVerified);
        if (updatedUser.emailVerified) {
          final doc =
              await FirebaseFirestore.instance
                  .collection('Users')
                  .doc(user.uid)
                  .get();
          final role = doc.data()?['role'] ?? '';
          await SessionService.storeSession(user.uid, user.email ?? '', role);
        }
      }
    } catch (e) {
      debugPrint('Error in post-authentication setup: $e');
      // Don't throw here - authentication succeeded, just log the error
    }
  }

  /// Ensure user document exists in Firestore before any operations
  static Future<void> _ensureUserDocumentExists(
    User user, {
    bool isNewUser = false,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        // Document doesn't exist, create it
        debugPrint('Creating missing user document for ${user.uid}');
        await storeUserData(
          user.uid,
          user.email ?? '',
          '', // No role, force selection
          username: user.displayName ?? '',
          appEmailVerified: user.emailVerified,
        );
      } else if (isNewUser) {
        // Don't overwrite if the document already contains important fields
        final data = doc.data();
        final existingRole = data?['role'];
        final formCompleted = data?['form_completed'];

        if (existingRole == null || existingRole.toString().isEmpty || formCompleted == null) {
          debugPrint('Updating missing fields for existing document (new user)');
          await storeUserData(
            user.uid,
            user.email ?? '',
            existingRole?.toString() ?? '', // Preserve role if it exists
            username: user.displayName ?? '',
            appEmailVerified: user.emailVerified,
          );
        } else {
          debugPrint('User doc already has role and form_completed. Skipping update.');
        }
      }
    } catch (e) {
      debugPrint('Error ensuring user document exists: $e');
      rethrow; // Re-throw since this is critical
    }
  }

  /// Public wrapper for _ensureUserDocumentExists for use in other services
  static Future<void> ensureUserDocumentExists(
    User user, {
    bool isNewUser = false,
  }) async {
    return _ensureUserDocumentExists(user, isNewUser: isNewUser);
  }

  /// Store user data in Firestore.
  static Future<void> storeUserData(
    String uid,
    String email,
    String role, {
    String? username,
    String? password,
    bool appEmailVerified = false,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'user_id': uid,
        'role': role,
        'username': username ?? '',
        'email': email,
        // 'password': password ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'app_email_verified': appEmailVerified,
      }, SetOptions(merge: true));
      debugPrint('User data stored/updated for $uid');
    } catch (e) {
      debugPrint('Error storing user data: $e');
      rethrow; // Re-throw for proper error handling
    }
  }

  /// Update app_email_verified field in Firestore - ENHANCED VERSION
  static Future<void> setAppEmailVerified(
    String uid, {
    bool value = true,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('Users').doc(uid);
      final user = _auth.currentUser;
      // Use a transaction to safely check and update
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          // Document doesn't exist - create it with all required fields
          debugPrint(
            'Creating user document during email verification update for $uid',
          );
          transaction.set(docRef, {
            'user_id': uid,
            'role': 'Tourist',
            'username': user?.displayName ?? '',
            'email': user?.email ?? '',
            'password': '',
            'created_at': FieldValue.serverTimestamp(),
            'app_email_verified': value,
            // Add any other required fields here as needed
          });
        } else {
          // Document exists - update the field
          transaction.update(docRef, {'app_email_verified': value});
        }
      });
      debugPrint('app_email_verified updated to $value for $uid');
    } catch (e) {
      debugPrint('Error updating app_email_verified: $e');
      // Don't throw here - this is often called in background and shouldn't break the flow
    }
  }

  /// Alternative method for web using redirect (if popup doesn't work).
  static Future<UserCredential?> signInWithGoogleRedirect() async {
    if (!kIsWeb) {
      throw AppConstants.authRedirectWebOnly;
    }

    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      await _auth.signInWithRedirect(googleProvider);
      final userCredential = await _auth.getRedirectResult();

      if (userCredential.user != null) {
        await _handlePostAuthentication(userCredential);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authGoogleSignInRedirectFailed(e.toString());
    }
  }

  /// Anonymous Sign In (Guest Account).
  static Future<UserCredential?> signInAnonymously({
    String role = AppConstants.authGuestRole,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();

      // Store guest user data in Firestore
      if (userCredential.user != null) {
        await storeUserData(
          userCredential.user!.uid,
          '',
          role,
          appEmailVerified: true,
        );
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authUnexpectedError(e.toString());
    }
  }

  /// Send password reset email.
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToSendPasswordReset(e.toString());
    }
  }

  /// Sign out the current user.
  static Future<void> signOut() async {
    try {
      await _auth.signOut(); // Sign out always (both web and mobile)
      await GoogleSignIn().signOut(); // Only applies if logged in with Google

      // Clear local session and storage
      await SessionService.clearSession();
      await _clearStoredEmail();

      debugPrint('User signed out and session cleared');
    } catch (e) {
      throw AppConstants.authFailedToSignOut(e.toString());
    }
  }

  /// Delete the current user account.
  static Future<void> deleteUser() async {
    try {
      final uid = currentUser?.uid;
      await currentUser?.delete();
      if (uid != null) {
        await deleteUserData(uid);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToDeleteAccount(e.toString());
    }
  }

  /// Reload user data from Firebase.
  static Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
    } catch (e) {
      debugPrint('Error reloading user: $e');
    }
  }

  /// Returns true if the current user's email is verified.
  static bool get isEmailVerified => currentUser?.emailVerified ?? false;

  /// Send email verification to the current user.
  static Future<void> sendEmailVerification({String? url}) async {
    try {
      if (url != null) {
        await currentUser?.sendEmailVerification(ActionCodeSettings(url: url));
      } else {
        await currentUser?.sendEmailVerification();
      }
      debugPrint('Verification email sent to: {currentUser?.email}');
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToSendVerification(e.toString());
    }
  }

  /// Link email/password credential to existing account.
  static Future<UserCredential?> linkWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      return await currentUser?.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToLinkCredential(e.toString());
    }
  }

  /// Link email link credential to existing account.
  static Future<UserCredential?> linkWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    try {
      final credential = EmailAuthProvider.credentialWithLink(
        email: email,
        emailLink: emailLink,
      );
      return await currentUser?.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToLinkEmailLink(e.toString());
    }
  }

  /// Re-authenticate with email/password.
  static Future<UserCredential?> reauthenticateWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      return await currentUser?.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToReauthenticate(e.toString());
    }
  }

  /// Re-authenticate with email link.
  static Future<UserCredential?> reauthenticateWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    try {
      final credential = EmailAuthProvider.credentialWithLink(
        email: email,
        emailLink: emailLink,
      );
      return await currentUser?.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToReauthenticateWithEmailLink(e.toString());
    }
  }

  /// Handle Firebase Auth Exceptions and return user-friendly messages.
  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return AppConstants.authWeakPassword;
      case 'email-already-in-use':
        return AppConstants.authEmailAlreadyInUse;
      case 'invalid-email':
        return AppConstants.authInvalidEmail;
      case 'user-disabled':
        return AppConstants.authUserDisabled;
      case 'user-not-found':
        return AppConstants.authUserNotFound;
      case 'wrong-password':
        return AppConstants.authWrongPassword;
      case 'invalid-credential':
        return AppConstants.authInvalidCredential;
      case 'account-exists-with-different-credential':
        return AppConstants.authAccountExistsWithDifferentCredential;
      case 'credential-already-in-use':
        return AppConstants.authCredentialAlreadyInUse;
      case 'operation-not-allowed':
        return AppConstants.authOperationNotAllowed;
      case 'too-many-requests':
        return AppConstants.authTooManyRequests;
      case 'network-request-failed':
        return AppConstants.authNetworkRequestFailed;
      case 'requires-recent-login':
        return AppConstants.authRequiresRecentLogin;
      case 'popup-closed-by-user':
        return AppConstants.authPopupClosedByUser;
      case 'popup-blocked':
        return AppConstants.authPopupBlocked;
      default:
        return e.message ?? AppConstants.authDefaultError;
    }
  }

  // Helper methods for email storage

  static Future<void> _clearStoredEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_emailKey);
    } catch (e) {
      debugPrint('Error clearing stored email: $e');
    }
  }

  static Future<String?> getStoredEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_emailKey);
    } catch (e) {
      debugPrint('Error getting stored email: $e');
      return null;
    }
  }

  /// Get user data from Firestore.
  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  /// Update user data in Firestore.
  static Future<void> updateUserData(
    String uid, {
    String? email,
    String? role,
    String? username,
    // String? password,
    String? municipality,
    String? status,
    String? profilePhoto,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'user_id': uid,
        'role': role,
        'username': username ?? '',
        'email': email,
        // 'password': password ?? '',
        'municipality': municipality ?? '',
        'status': status ?? '',
        'profile_photo': profilePhoto ?? '',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user data: $e');
    }
  }

  /// Delete user data from Firestore.
  static Future<void> deleteUserData(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).delete();
    } catch (e) {
      debugPrint('Error deleting user data: $e');
    }
  }

  /// Log unhandled errors.
  static void logError(dynamic error, StackTrace stackTrace) {
    if (kDebugMode) {
      print('Unhandled error: $error');
      print('Stack trace: $stackTrace');
    }
  }

  
}

