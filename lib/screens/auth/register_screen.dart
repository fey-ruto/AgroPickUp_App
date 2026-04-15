import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/input_validation.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _farmNameController = TextEditingController();
  final _regionController = TextEditingController();
  UserRole _selectedRole = UserRole.farmer;
  bool _passwordVisible = false;
  bool _agreed = false;

  final List<String> _regions = [
    'Greater Accra',
    'Ashanti',
    'Western',
    'Eastern',
    'Central',
    'Northern',
    'Upper East',
    'Upper West',
    'Volta',
    'Brong-Ahafo',
    'Savannah',
    'North East',
    'Ahafo'
  ];
  String? _selectedRegion;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _farmNameController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _openTermsAndPolicies() async {
    final accepted =
        await Navigator.pushNamed(context, AppRoutes.termsPolicies);
    if (!mounted) return;
    if (accepted == true) {
      setState(() => _agreed = true);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please agree to the terms and conditions')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      fullName: _fullNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
      farmName: _selectedRole == UserRole.farmer
          ? _farmNameController.text.trim()
          : null,
      region: _selectedRegion,
    );
    if (!mounted) return;
    if (success) {
      final user = auth.currentUser!;
      context.read<NotificationProvider>().listenToNotifications(user.id);
      Navigator.pushReplacementNamed(
        context,
        user.role == UserRole.admin
            ? AppRoutes.adminDashboard
            : AppRoutes.farmerDashboard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return LoadingOverlay(
            isLoading: auth.isLoading,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (auth.error != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(auth.error!,
                            style: const TextStyle(color: AppColors.error)),
                      ),
                    const SectionLabel(text: 'Account Type'),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleButton(
                            label: 'Farmer',
                            icon: Icons.agriculture,
                            selected: _selectedRole == UserRole.farmer,
                            onTap: () =>
                                setState(() => _selectedRole = UserRole.farmer),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoleButton(
                            label: 'Aggregator',
                            icon: Icons.local_shipping_outlined,
                            selected: _selectedRole == UserRole.admin,
                            onTap: () =>
                                setState(() => _selectedRole = UserRole.admin),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const SectionLabel(text: 'Personal Information'),
                    TextFormField(
                      controller: _fullNameController,
                      textInputAction: TextInputAction.next,
                      maxLength: 80,
                      inputFormatters: [LengthLimitingTextInputFormatter(80)],
                      decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => InputValidation.requiredText(
                        v,
                        fieldName: 'your full name',
                        maxLength: 80,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined)),
                      validator: InputValidation.tenDigitPhone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined)),
                      validator: InputValidation.email,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_passwordVisible
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _passwordVisible = !_passwordVisible),
                        ),
                      ),
                      validator: InputValidation.password,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline)),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != _passwordController.text)
                          return 'Passwords do not match';
                        return null;
                      },
                    ),
                    if (_selectedRole == UserRole.farmer) ...[
                      const SizedBox(height: 24),
                      const SectionLabel(text: 'Farm Information'),
                      TextFormField(
                        controller: _farmNameController,
                        textInputAction: TextInputAction.next,
                        maxLength: 80,
                        inputFormatters: [LengthLimitingTextInputFormatter(80)],
                        decoration: const InputDecoration(
                            labelText: 'Farm Name',
                            prefixIcon: Icon(Icons.home_outlined)),
                        validator: (v) => _selectedRole != UserRole.farmer
                            ? null
                            : InputValidation.requiredText(
                                v,
                                fieldName: 'your farm name',
                                maxLength: 80,
                              ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRegion,
                        decoration: const InputDecoration(
                            labelText: 'Region',
                            prefixIcon: Icon(Icons.map_outlined)),
                        items: _regions
                            .map((r) =>
                                DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedRegion = v),
                        validator: (v) {
                          if (_selectedRole != UserRole.farmer) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Please select your region';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreed,
                          activeColor: AppColors.primary,
                          onChanged: (v) async {
                            if (v == true) {
                              await _openTermsAndPolicies();
                            } else {
                              setState(() => _agreed = false);
                            }
                          },
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _openTermsAndPolicies,
                            child: const Text(
                              'I agree to the Terms and Policies',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: auth.isLoading ? null : _register,
                      child: const Text('Sign Up'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? '),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Log In',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleButton(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
