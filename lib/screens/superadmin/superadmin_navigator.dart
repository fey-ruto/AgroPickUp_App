import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/superadmin/superadmin_provider.dart';
import '../../utils/app_theme.dart';
import 'superadmin_shell.dart';

/// Entry point for the superadmin module.
///
/// Superadmins arrive here after logging in through the normal [LoginScreen].
/// Firebase Auth is already active, so this widget asks [SuperadminProvider]
/// to verify the session against the `superadmins` Firestore collection and
/// load dashboard data. If verification fails (e.g. direct navigation by a
/// non-superadmin), the user is bounced back to the main login screen.
class SuperadminNavigator extends StatelessWidget {
  const SuperadminNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SuperadminProvider(),
      child: const _SuperadminEntry(),
    );
  }
}

class _SuperadminEntry extends StatefulWidget {
  const _SuperadminEntry();

  @override
  State<_SuperadminEntry> createState() => _SuperadminEntryState();
}

class _SuperadminEntryState extends State<_SuperadminEntry> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final provider = context.read<SuperadminProvider>();
    await provider.initFromExistingSession();
    if (!mounted) return;
    if (!provider.isAuthenticated) {
      // Not a superadmin or not logged in — return to main login.
      Navigator.of(context, rootNavigator: true)
          .pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SuperadminProvider>();
    if (!provider.isAuthenticated) {
      return Scaffold(
        backgroundColor: AppColors.primary,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    return const SuperadminShell();
  }
}
