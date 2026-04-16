import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/input_validation.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _error;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isFarmer => _currentUser?.role == UserRole.farmer;

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
      debugPrint(
          'loadCurrentUser FirebaseException: code=${e.code}, message=${e.message}');
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

    final emailError = InputValidation.email(email);
    if (emailError != null) {
      _error = emailError;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (password.isEmpty) {
      _error = 'Please enter your password.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _currentUser = await _firestoreService.getUser(credential.user!.uid);
      if (_currentUser == null) {
        await _auth.signOut();
        _error = 'Account profile not found. Please contact support.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
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

    final cleanFullName = InputValidation.normalizeText(fullName);
    final cleanPhone = phoneNumber.trim();
    final cleanEmail = email.trim();
    final cleanFarmName =
        farmName == null ? null : InputValidation.normalizeText(farmName);
    final cleanRegion =
        region == null ? null : InputValidation.normalizeText(region);

    final validationErrors = <String?>[
      InputValidation.requiredText(
        cleanFullName,
        fieldName: 'your full name',
        maxLength: 80,
      ),
      InputValidation.tenDigitPhone(cleanPhone),
      InputValidation.email(cleanEmail),
      InputValidation.password(password),
    ];

    if (role == UserRole.farmer) {
      validationErrors.addAll([
        InputValidation.requiredText(
          cleanFarmName,
          fieldName: 'your farm name',
          maxLength: 80,
        ),
        InputValidation.requiredText(
          cleanRegion,
          fieldName: 'your region',
          maxLength: 50,
        ),
      ]);
    }

    final firstError = validationErrors.firstWhere(
      (message) => message != null,
      orElse: () => null,
    );
    if (firstError != null) {
      _error = firstError;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = AppUser(
        id: credential.user!.uid,
        fullName: cleanFullName,
        phoneNumber: cleanPhone,
        role: role,
        farmName: role == UserRole.farmer ? cleanFarmName : null,
        region: role == UserRole.farmer ? cleanRegion : null,
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
        return 'Password must meet the app requirements.';
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
