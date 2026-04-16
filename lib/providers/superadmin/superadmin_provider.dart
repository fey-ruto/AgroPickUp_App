import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class SuperadminProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Real-time stream subscriptions
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;
  StreamSubscription<QuerySnapshot>? _activitySubscription;

  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;
  String? _superadminEmail;

  int _totalFarmers = 0;
  int _totalAggregators = 0;
  int _totalRequests = 0;
  double _totalProduceWeight = 0;
  Map<String, int> _requestsByStatus = {};
  Map<String, double> _produceByType = {};
  Map<String, double> _produceByRegion = {};
  Map<String, int> _requestsByMonth = {};
  Map<String, int> _collectionPointActivity = {};
  Map<String, int> _farmerRequestFrequency = {};

  List<Map<String, dynamic>> _farmers = [];
  List<Map<String, dynamic>> _aggregators = [];
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _activityLog = [];

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;
  String? get superadminEmail => _superadminEmail;
  int get totalFarmers => _totalFarmers;
  int get totalAggregators => _totalAggregators;
  int get totalRequests => _totalRequests;
  double get totalProduceWeight => _totalProduceWeight;
  Map<String, int> get requestsByStatus => _requestsByStatus;
  Map<String, double> get produceByType => _produceByType;
  Map<String, double> get produceByRegion => _produceByRegion;
  Map<String, int> get requestsByMonth => _requestsByMonth;
  Map<String, int> get collectionPointActivity => _collectionPointActivity;
  Map<String, int> get farmerRequestFrequency => _farmerRequestFrequency;
  List<Map<String, dynamic>> get farmers => _farmers;
  List<Map<String, dynamic>> get aggregators => _aggregators;
  List<Map<String, dynamic>> get allRequests => _allRequests;
  List<Map<String, dynamic>> get activityLog => _activityLog;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ─── Authentication ────────────────────────────────────────────────────────

  Future<void> initFromExistingSession() async {
    _setLoading(true);
    _error = null;
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        _isAuthenticated = false;
        _setLoading(false);
        return;
      }
      final email = firebaseUser.email?.trim().toLowerCase() ?? '';
      final saDoc = await _db.collection('superadmins').doc(email).get();
      if (!saDoc.exists) {
        _isAuthenticated = false;
        _setLoading(false);
        return;
      }
      _isAuthenticated = true;
      _superadminEmail = email;
      await _logActivity('Superadmin login', 'Logged in as $_superadminEmail');
      _startStreams();
    } catch (_) {
      _isAuthenticated = false;
    }
    _setLoading(false);
  }

  Future<void> logout() async {
    _stopStreams();
    await _auth.signOut();
    _isAuthenticated = false;
    _superadminEmail = null;
    _farmers = [];
    _aggregators = [];
    _activityLog = [];
    _allRequests = [];
    _requestsByStatus = {};
    notifyListeners();
  }

  // ─── Real-time streams ─────────────────────────────────────────────────────

  void _startStreams() {
    _stopStreams();

    _usersSubscription = _db.collection('users').snapshots().listen((snap) {
      debugPrint('[SuperadminProvider] users snap: ${snap.docs.length} docs');
      final all = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();
      _farmers = all.where((u) => u['role'] == 'farmer').toList();
      _aggregators = all.where((u) => u['role'] == 'admin').toList();
      _totalFarmers = _farmers.length;
      _totalAggregators = _aggregators.length;
      debugPrint('[SuperadminProvider] farmers: $_totalFarmers, aggregators: $_totalAggregators');
      _recomputeAnalytics();
      notifyListeners();
    }, onError: (e) => debugPrint('[SuperadminProvider] users stream error: $e'));

    _requestsSubscription =
        _db.collection('pickupRequests').snapshots().listen((snap) {
      debugPrint('[SuperadminProvider] pickupRequests snap: ${snap.docs.length} docs');
      _allRequests = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();
      _recomputeAnalytics();
      notifyListeners();
    }, onError: (e) => debugPrint('[SuperadminProvider] requests stream error: $e'));

    _activitySubscription = _db
        .collection('superadmin_activity')
        .orderBy('timestamp', descending: true)
        .limit(60)
        .snapshots()
        .listen((snap) {
      _activityLog = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();
      notifyListeners();
    }, onError: (_) {});
  }

  void _stopStreams() {
    _usersSubscription?.cancel();
    _usersSubscription = null;
    _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _activitySubscription?.cancel();
    _activitySubscription = null;
  }

  // Recompute all derived analytics from current _farmers and _allRequests.
  // Called whenever either stream fires — no notifyListeners() here because
  // the stream handler calls it immediately after.
  void _recomputeAnalytics() {
    _totalRequests = _allRequests.length;

    final statusMap = <String, int>{};
    for (final r in _allRequests) {
      final s = r['status'] as String? ?? 'unknown';
      statusMap[s] = (statusMap[s] ?? 0) + 1;
    }
    _requestsByStatus = statusMap;

    _totalProduceWeight = _allRequests.fold(0.0, (double acc, r) {
      final q = r['quantity'];
      return acc + (q is num ? q.toDouble() : 0.0);
    });

    final typeMap = <String, double>{};
    for (final r in _allRequests) {
      final type = (r['produceType'] as String? ?? 'Unknown').trim();
      final qty = (r['quantity'] as num?)?.toDouble() ?? 0.0;
      typeMap[type] = (typeMap[type] ?? 0.0) + qty;
    }
    _produceByType = typeMap;

    final farmerRegions = {
      for (final f in _farmers)
        f['id'] as String: f['region'] as String? ?? 'Unknown'
    };
    final regionMap = <String, double>{};
    for (final r in _allRequests) {
      final region =
          farmerRegions[r['farmerId'] as String? ?? ''] ?? 'Unknown';
      final qty = (r['quantity'] as num?)?.toDouble() ?? 0.0;
      regionMap[region] = (regionMap[region] ?? 0.0) + qty;
    }
    _produceByRegion = regionMap;

    final monthMap = <String, int>{};
    for (final r in _allRequests) {
      final ts = r['createdAt'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        monthMap[key] = (monthMap[key] ?? 0) + 1;
      }
    }
    final sortedKeys = monthMap.keys.toList()..sort();
    if (sortedKeys.length > 8) {
      for (final k in sortedKeys.sublist(0, sortedKeys.length - 8)) {
        monthMap.remove(k);
      }
    }
    _requestsByMonth = monthMap;

    final cpMap = <String, int>{};
    for (final r in _allRequests) {
      final cp = r['collectionPointName'] as String? ?? 'Unknown';
      cpMap[cp] = (cpMap[cp] ?? 0) + 1;
    }
    _collectionPointActivity = cpMap;

    final fqMap = <String, int>{};
    for (final r in _allRequests) {
      final name = r['farmerName'] as String? ?? 'Unknown';
      fqMap[name] = (fqMap[name] ?? 0) + 1;
    }
    _farmerRequestFrequency = fqMap;
  }

  // ─── Manual refresh (streams self-update, but kept for pull-to-refresh UI) ─

  /// Restarts all streams, forcing a fresh connection to Firestore.
  Future<void> loadDashboardData() async {
    _startStreams();
  }

  Future<void> refreshUsers() async => _startStreams();
  Future<void> refreshRequests() async => _startStreams();
  Future<void> refreshActivityLog() async => _startStreams();

  // ─── User management ───────────────────────────────────────────────────────

  Future<void> setUserStatus(
      String userId, String status, String userName) async {
    _setLoading(true);
    try {
      await _db.collection('users').doc(userId).update({'status': status});
      await _logActivity(
        status == 'suspended' ? 'User suspended' : 'User activated',
        '$userName set to $status',
        targetId: userId,
        targetName: userName,
      );
      // Stream will automatically pick up the change — no manual reload needed.
    } catch (_) {
      _error = 'Failed to update user status.';
    }
    _setLoading(false);
  }

  Future<void> updateUser(
      String userId, Map<String, dynamic> data, String userName) async {
    _setLoading(true);
    try {
      await _db.collection('users').doc(userId).update(data);
      await _logActivity('User profile updated', 'Updated $userName',
          targetId: userId, targetName: userName);
    } catch (_) {
      _error = 'Failed to update user.';
    }
    _setLoading(false);
  }

  Future<bool> deleteUser(String userId, String userName) async {
    _setLoading(true);
    try {
      await _db.collection('users').doc(userId).delete();
      await _logActivity('User deleted', 'Deleted $userName',
          targetId: userId, targetName: userName);
      _setLoading(false);
      return true;
    } catch (_) {
      _error = 'Failed to delete user.';
      _setLoading(false);
      return false;
    }
  }

  // ─── Add aggregator ────────────────────────────────────────────────────────

  /// Creates a new aggregator account using a secondary Firebase App instance
  /// so the superadmin's own auth session is not disrupted.
  Future<String?> addAggregator({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String region,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'sa_create_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      await secondaryApp.delete();
      secondaryApp = null;

      await _db.collection('users').doc(uid).set({
        'id': uid,
        'fullName': fullName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'role': 'admin',
        'region': region.trim(),
        'status': 'active',
        'createdAt': Timestamp.now(),
        'fcmToken': null,
        'farmName': null,
      });
      await _logActivity(
        'Aggregator created',
        'Created aggregator $fullName ($email)',
        targetId: uid,
        targetName: fullName,
      );
      _setLoading(false);
      return uid;
    } on FirebaseAuthException catch (e) {
      _error = _authError(e.code);
      await secondaryApp?.delete();
      _setLoading(false);
      return null;
    } catch (_) {
      _error = 'Failed to create aggregator account.';
      await secondaryApp?.delete();
      _setLoading(false);
      return null;
    }
  }

  // ─── Broadcast ─────────────────────────────────────────────────────────────

  Future<void> broadcastNotification({
    required String title,
    required String message,
    required String targetRole,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final List<Map<String, dynamic>> targets;
      if (targetRole == 'all') {
        targets = [..._farmers, ..._aggregators];
      } else if (targetRole == 'farmer') {
        targets = _farmers;
      } else {
        targets = _aggregators;
      }
      const batchSize = 400;
      for (int i = 0; i < targets.length; i += batchSize) {
        final chunk = targets.sublist(
            i,
            i + batchSize > targets.length
                ? targets.length
                : i + batchSize);
        final batch = _db.batch();
        for (final user in chunk) {
          batch.set(_db.collection('notifications').doc(), {
            'userId': user['id'],
            'title': title,
            'message': message,
            'type': 'general',
            'isRead': false,
            'requestId': null,
            'sentAt': Timestamp.now(),
          });
        }
        await batch.commit();
      }
      final label = targetRole == 'all'
          ? 'all users'
          : targetRole == 'farmer'
              ? 'all farmers'
              : 'all aggregators';
      await _logActivity('Broadcast sent',
          '"$title" sent to $label (${targets.length} recipients)');
    } catch (_) {
      _error = 'Failed to send broadcast.';
    }
    _setLoading(false);
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  Future<void> _logActivity(String action, String details,
      {String? targetId, String? targetName}) async {
    try {
      await _db.collection('superadmin_activity').add({
        'action': action,
        'details': details,
        'performedBy': _superadminEmail ?? 'superadmin',
        'targetId': targetId,
        'targetName': targetName,
        'timestamp': Timestamp.now(),
      });
    } catch (_) {}
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _stopStreams();
    super.dispose();
  }
}
