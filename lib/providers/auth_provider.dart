import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isSuperadmin = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isFarmer => _currentUser?.role == UserRole.farmer;
  bool get isSuperadmin => _isSuperadmin;

  Future<void> loadCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        _currentUser = null;
        notifyListeners();
        return;
      }
      _currentUser = await _firestoreService.getUser(firebaseUser.uid);
      notifyListeners();
    } on FirebaseException catch (e) {
      debugPrint('loadCurrentUser FirebaseException: code=${e.code}, message=${e.message}');
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      debugPrint('loadCurrentUser unexpected error: $e');
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Check superadmins first — they have no users collection profile.
      // Wrapped in its own try-catch: if Firestore rules deny reading the
      // superadmins collection (e.g. rules not yet deployed), treat the user
      // as a normal farmer/aggregator rather than killing the whole login.
      try {
        final saDoc = await _db
            .collection('superadmins')
            .doc(email.trim().toLowerCase())
            .get();
        if (saDoc.exists) {
          _isSuperadmin = true;
          _isLoading = false;
          notifyListeners();
          return true;
        }
      } catch (_) {
        // Superadmins collection not readable — not a superadmin, continue.
      }

      // Not a superadmin — look up the normal user profile.
      // Fetch the raw doc so we can check the status field in one read.
      final userDoc = await _db
          .collection('users')
          .doc(credential.user!.uid)
          .get();
      if (!userDoc.exists) {
        await _auth.signOut();
        _error = 'Account profile not found. Please contact support.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      if (userDoc.data()?['status'] == 'suspended') {
        await _auth.signOut();
        _error = 'Your account has been suspended. Please contact support.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _currentUser = AppUser.fromFirestore(userDoc);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } on FirebaseException {
      _error = 'Unable to load account details. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
    required UserRole role,
    String? farmName,
    String? region,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = AppUser(
        id: credential.user!.uid,
        fullName: fullName,
        phoneNumber: phoneNumber,
        role: role,
        farmName: farmName,
        region: region,
        createdAt: DateTime.now(),
      );
      await _firestoreService.createUser(user);
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } on FirebaseException {
      _error = 'Failed to create your account profile. Please try again.';

      // Keep Firebase Auth and Firestore consistent if profile creation fails.
      if (credential?.user != null) {
        await credential!.user!.delete();
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'An unexpected error occurred. Please try again.';

      if (credential?.user != null) {
        await credential!.user!.delete();
      }

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    _isSuperadmin = false;
    notifyListeners();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
      case 'admin-restricted-operation':
        return 'Email/password signup is disabled in Firebase Authentication for this project.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return 'Authentication error: $code';
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
