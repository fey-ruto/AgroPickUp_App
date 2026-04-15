import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/request_provider.dart';
import 'providers/collection_point_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/shared/splash_screen.dart';
import 'screens/shared/shared_screens.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/terms_policies_screen.dart';
import 'screens/farmer/farmer_dashboard.dart';
import 'screens/farmer/request_pickup_screen.dart';
import 'screens/farmer/request_screens.dart';
import 'screens/farmer/map_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_request_detail.dart';
import 'screens/admin/collection_point_management.dart';
import 'utils/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const AgroPickupApp());
}

class AgroPickupApp extends StatelessWidget {
  const AgroPickupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => CollectionPointProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'AgroPickup GH',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (_) => const SplashScreen(),
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.register: (_) => const RegisterScreen(),
          AppRoutes.termsPolicies: (_) => const TermsPoliciesScreen(),
          AppRoutes.farmerDashboard: (_) => const FarmerDashboard(),
          AppRoutes.requestPickup: (_) => const RequestPickupScreen(),
          AppRoutes.requestStatus: (_) => const RequestStatusScreen(),
          AppRoutes.requestDetail: (_) => const RequestDetailScreen(),
          AppRoutes.mapScreen: (_) => const MapScreen(),
          AppRoutes.collectionPointDetail: (_) =>
              const CollectionPointDetailScreen(),
          AppRoutes.reportIssue: (_) => const ReportIssueScreen(),
          AppRoutes.notifications: (_) => const NotificationsScreen(),
          AppRoutes.adminDashboard: (_) => const AdminDashboard(),
          AppRoutes.adminRequestDetail: (_) => const AdminRequestDetailScreen(),
          AppRoutes.collectionPointManagement: (_) =>
              const CollectionPointManagementScreen(),
        },
      ),
    );
  }
}
