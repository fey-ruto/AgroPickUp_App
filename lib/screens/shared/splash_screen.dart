import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await context.read<AuthProvider>().loadCurrentUser();
        if (!mounted) return;
        final user = context.read<AuthProvider>().currentUser;
        if (user != null) {
          // Start listening to notifications and load existing ones from database
          context.read<NotificationProvider>().listenToNotifications(user.id);
          // Also do an immediate refresh to ensure old notifications load quickly
          await context
              .read<NotificationProvider>()
              .refreshNotifications(user.id);
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            user.role == UserRole.admin
                ? AppRoutes.adminDashboard
                : AppRoutes.farmerDashboard,
          );
          return;
        }
      }
      context.read<NotificationProvider>().clearState();
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } on FirebaseException catch (e) {
      debugPrint(
          'Splash _navigate FirebaseException: code=${e.code}, message=${e.message}');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } catch (e) {
      debugPrint('Splash _navigate unexpected error: $e');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.eco_rounded,
                        size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'AgroPickup GH',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connecting Farmers to Markets',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: LinearProgressIndicator(
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'v1.0.0',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onLongPress: () {
                try {
                  final projectId = Firebase.app().options.projectId;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Firebase Project: $projectId'),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Colors.black87,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Firebase Error: $e'),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(
                '🔧 Firebase: agropick-gh',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
