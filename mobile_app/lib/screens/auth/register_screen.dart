import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../worker/worker_dashboard.dart';
import '../supervisor/supervisor_dashboard.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _workerIdController = TextEditingController(text: 'W-105');

  UserRole _selectedRole = UserRole.worker;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _workerIdController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await AuthService.instance.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: _selectedRole,
        workerId: _selectedRole == UserRole.worker
            ? _workerIdController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (user.role == UserRole.worker) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WorkerDashboard()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SupervisorDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('AppException: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSub = AppTheme.textSub(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(title: const Text("Enroll Account")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withAlpha(isDark ? 30 : 18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.dangerRed.withAlpha(90),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppTheme.dangerRed,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.dangerRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Full Name
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: textSub,
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter your full name'
                      : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    prefixIcon: Icon(
                      Icons.mail_outline_rounded,
                      size: 18,
                      color: textSub,
                    ),
                  ),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid corporate email'
                      : null,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: textSub,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: textSub,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => v == null || v.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 20),

                // Role Selector
                Text(
                  "SELECT SYSTEM ROLE",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: textSub,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedRole = UserRole.worker),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedRole == UserRole.worker
                                ? AppTheme.primary.withAlpha(isDark ? 40 : 25)
                                : (isDark
                                      ? const Color(0xFF131B2E)
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedRole == UserRole.worker
                                  ? AppTheme.primary
                                  : AppTheme.border(context),
                              width: _selectedRole == UserRole.worker ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.engineering_rounded,
                                size: 18,
                                color: _selectedRole == UserRole.worker
                                    ? AppTheme.primary
                                    : textSub,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Field Worker",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: _selectedRole == UserRole.worker
                                      ? textPrimary
                                      : textSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedRole = UserRole.supervisor),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedRole == UserRole.supervisor
                                ? AppTheme.secondary.withAlpha(isDark ? 40 : 25)
                                : (isDark
                                      ? const Color(0xFF131B2E)
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedRole == UserRole.supervisor
                                  ? AppTheme.secondary
                                  : AppTheme.border(context),
                              width: _selectedRole == UserRole.supervisor
                                  ? 1.5
                                  : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 18,
                                color: _selectedRole == UserRole.supervisor
                                    ? AppTheme.secondary
                                    : textSub,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Supervisor",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: _selectedRole == UserRole.supervisor
                                      ? textPrimary
                                      : textSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Worker ID input (shown if role is Worker)
                if (_selectedRole == UserRole.worker) ...[
                  TextFormField(
                    controller: _workerIdController,
                    style: TextStyle(color: textPrimary, fontSize: 13.5),
                    decoration: InputDecoration(
                      labelText: "Assigned Worker ID",
                      hintText: "W-105",
                      prefixIcon: Icon(
                        Icons.badge_outlined,
                        size: 18,
                        color: textSub,
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter worker identifier'
                        : null,
                  ),
                  const SizedBox(height: 20),
                ],

                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedRole == UserRole.worker
                        ? AppTheme.primary
                        : AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("CREATE ACCOUNT & ENTER"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
