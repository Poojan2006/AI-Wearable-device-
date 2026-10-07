import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import '../database/local_database.dart';
import '../core/errors/app_exceptions.dart';
import '../core/constants/app_constants.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();

  AuthService._internal() {
    _initAuthListener();
  }

  fb_auth.FirebaseAuth? _firebaseAuth;
  FirebaseDatabase? _firebaseDb;
  bool _isFirebaseAvailable = false;

  AppUser? _currentUser;
  final _userController = StreamController<AppUser?>.broadcast();

  Stream<AppUser?> get userStream => _userController.stream;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  Future<void> initializeFirebase() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _firebaseAuth = fb_auth.FirebaseAuth.instance;
        _firebaseDb = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: AppConstants.rtdbUrl,
        );
        _isFirebaseAvailable = true;
        debugPrint("[AuthService] Firebase Auth & Regional RTDB initialized (${AppConstants.rtdbUrl})");
      }
    } catch (e) {
      debugPrint("[AuthService] Firebase init error: $e");
      _isFirebaseAvailable = false;
    }
  }

  void _initAuthListener() async {
    // 1. Try to load cached user session for instant offline readiness
    try {
      final cached = await LocalDatabase.instance.getCachedUser();
      if (cached != null) {
        _currentUser = cached;
        _userController.add(cached);
      }
    } catch (_) {}

    // 2. If Firebase is active, listen to auth state changes
    if (_firebaseAuth != null) {
      _firebaseAuth!.authStateChanges().listen((fbUser) async {
        if (fbUser == null) {
          if (_currentUser != null && !_currentUser!.uid.startsWith('offline_')) {
            _currentUser = null;
            _userController.add(null);
          }
        } else {
          try {
            final profile = await _fetchUserProfile(fbUser.uid, fbUser.email ?? '');
            _currentUser = profile;
            await LocalDatabase.instance.saveUser(profile);
            _userController.add(profile);
          } catch (_) {
            // Keep existing cached profile if offline
          }
        }
      });
    }
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // Check offline cached user first if Firebase is unavailable
    if (!_isFirebaseAvailable || _firebaseAuth == null) {
      final cached = await LocalDatabase.instance.getCachedUser();
      if (cached != null && cached.email.toLowerCase() == cleanEmail) {
        _currentUser = cached;
        _userController.add(cached);
        return cached;
      }

      // If mock/demo credentials used in offline lab test
      final role = cleanEmail.contains('sup') ? UserRole.supervisor : UserRole.worker;
      final mockUser = AppUser(
        uid: 'offline_${cleanEmail.replaceAll('@', '_').replaceAll('.', '_')}',
        email: cleanEmail,
        name: cleanEmail.contains('sup') ? 'Chief Supervisor' : 'Field Worker',
        role: role,
        workerId: role == UserRole.worker ? 'W-104' : '',
        cachedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _currentUser = mockUser;
      await LocalDatabase.instance.saveUser(mockUser);
      _userController.add(mockUser);
      return mockUser;
    }

    try {
      final creds = await _firebaseAuth!.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final user = creds.user;
      if (user == null) {
        throw AuthException('Login failed: User record is empty.');
      }

      final profile = await _fetchUserProfile(user.uid, user.email ?? cleanEmail);
      _currentUser = profile;
      await LocalDatabase.instance.saveUser(profile);
      _userController.add(profile);
      return profile;
    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        // Auto-provision demo account to Firebase Auth & RTDB
        if (cleanEmail == 'worker@safeguard.com' || cleanEmail == 'supervisor@safeguard.com') {
          try {
            final role = cleanEmail.contains('sup') ? UserRole.supervisor : UserRole.worker;
            final created = await register(
              name: role == UserRole.supervisor ? 'Site Supervisor' : 'Field Worker',
              email: cleanEmail,
              password: password,
              role: role,
              workerId: role == UserRole.worker ? 'W-104' : null,
            );
            return created;
          } catch (_) {
            // fall through
          }
        }
      }

      // Check if network error occurred and we have cached session
      if (e.code == 'network-request-failed') {
        final cached = await LocalDatabase.instance.getCachedUser();
        if (cached != null && cached.email.toLowerCase() == cleanEmail) {
          _currentUser = cached;
          _userController.add(cached);
          return cached;
        }
        throw AuthException('Network unavailable and no cached offline session found for this user.');
      }
      throw AuthException(e.message ?? 'Authentication failed', code: e.code);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? workerId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (!_isFirebaseAvailable || _firebaseAuth == null) {
      final localUser = AppUser(
        uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
        email: cleanEmail,
        name: name.trim(),
        role: role,
        workerId: role == UserRole.worker ? (workerId?.trim() ?? 'W-101') : '',
        cachedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _currentUser = localUser;
      await LocalDatabase.instance.saveUser(localUser);
      _userController.add(localUser);
      return localUser;
    }

    try {
      final creds = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final user = creds.user;
      if (user == null) {
        throw AuthException('Registration failed: User record is empty.');
      }

      final assignedWorkerId = role == UserRole.worker
          ? (workerId != null && workerId.trim().isNotEmpty
              ? workerId.trim()
              : 'W-${user.uid.substring(0, 5).toUpperCase()}')
          : '';

      final newUser = AppUser(
        uid: user.uid,
        email: cleanEmail,
        name: name.trim(),
        role: role,
        workerId: assignedWorkerId,
        cachedAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Write user profile to Realtime Database
      if (_firebaseDb != null) {
        await _firebaseDb!.ref('${AppConstants.rtdbUsers}/${user.uid}').set({
          'name': newUser.name,
          'email': newUser.email,
          'role': newUser.role.toRoleString(),
          'workerId': newUser.workerId,
          'createdAt': ServerValue.timestamp,
        });

        if (role == UserRole.worker) {
          await _firebaseDb!.ref('${AppConstants.rtdbWorkers}/${newUser.workerId}').set({
            'name': newUser.name,
            'workerId': newUser.workerId,
            'status': 'SAFE',
            'deviceId': 'ESP32_SAFE_01',
            'lastSeen': ServerValue.timestamp,
            'lastUpdated': ServerValue.timestamp,
          });
        }
      }

      _currentUser = newUser;
      await LocalDatabase.instance.saveUser(newUser);
      _userController.add(newUser);
      return newUser;
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Registration failed', code: e.code);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<AppUser> _fetchUserProfile(String uid, String email) async {
    if (_firebaseDb == null) {
      return AppUser(
        uid: uid,
        email: email,
        name: 'Worker',
        role: UserRole.worker,
        workerId: 'W-${uid.substring(0, 4)}',
        cachedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }

    try {
      final snapshot =
          await _firebaseDb!.ref('${AppConstants.rtdbUsers}/$uid').get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return AppUser.fromJson(data, uid: uid);
      }
    } catch (_) {}

    return AppUser(
      uid: uid,
      email: email,
      name: 'User',
      role: UserRole.worker,
      workerId: 'W-${uid.substring(0, 4)}',
      cachedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth?.signOut();
    } catch (_) {}

    await LocalDatabase.instance.clearUserSession();
    _currentUser = null;
    _userController.add(null);
  }
}
