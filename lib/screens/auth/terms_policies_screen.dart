import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

class TermsPoliciesScreen extends StatefulWidget {
  const TermsPoliciesScreen({super.key});

  @override
  State<TermsPoliciesScreen> createState() => _TermsPoliciesScreenState();
}

class _TermsPoliciesScreenState extends State<TermsPoliciesScreen> {
  bool _agreed = false;

  static const String _termsText =
      'AgroPickup connects farmers and aggregators for produce transactions. Aggregators are responsible for purchasing produce from farmers and selling to markets. '
      'Aggregators do not transport goods on behalf of farmers unless both parties separately agree to such an arrangement.\n\n'
      'AgroPickup is only a digital matching platform. We are not a carrier, buyer, or seller in transactions between users. All negotiations, payments, and delivery terms are made directly between the farmer and aggregator.\n\n'
      'You must verify account details, payment terms, and pickup arrangements before completing any transaction. Report suspicious behavior immediately through the app support channels.\n\n'
      'AgroPickup is not liable for fraud, losses, damages, disputes, or other activities that happen outside this application or outside features controlled by this application. By continuing, you acknowledge and accept this responsibility.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Policies'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Please read and accept these terms before creating your account.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 16),
                    Text(
                      _termsText,
                      style: TextStyle(height: 1.5, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _agreed,
                        activeColor: AppColors.primary,
                        onChanged: (value) =>
                            setState(() => _agreed = value ?? false),
                      ),
                      const Expanded(
                        child: Text(
                            'I have read and agree to the Terms and Policies.'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed:
                        _agreed ? () => Navigator.pop(context, true) : null,
                    child: const Text('I Agree and Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
