import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../services/solid_service.dart';

/// LoginScreen - Authenticate with your Solid Pod
///
/// This screen allows you to log in using your Solid WebID.
/// Your WebID is like your email address in the Solid ecosystem.
///
/// Example WebID: https://pods.d01.solidcommunity.au/ahlam/profile/card#me
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _webIdController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _webIdController = TextEditingController();

    // Pre-fill with the user's WebID for testing
    _webIdController.text = 'https://pods.d01.solidcommunity.au/ahlam/profile/card#me';
  }

  @override
  void dispose() {
    _webIdController.dispose();
    super.dispose();
  }

  /// Handle login button press
  Future<void> _handleLogin() async {
    final webId = _webIdController.text.trim();

    if (webId.isEmpty) {
      setState(() => _errorMessage = 'Please enter your WebID');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final solidService = context.read<SolidService>();
      final success = await solidService.login(webId);

      if (mounted) {
        if (success) {
          // Navigate to home screen
          context.go('/');
        } else {
          setState(() => _errorMessage = solidService.errorMessage ?? 'Login failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Logo & Title
                  _buildHeader(),

                  const SizedBox(height: 48),

                  // Login Form
                  _buildLoginForm(),

                  const SizedBox(height: 24),

                  // Error Message
                  if (_errorMessage != null)
                    _buildErrorMessage(),

                  const SizedBox(height: 32),

                  // Login Button
                  _buildLoginButton(),

                  const SizedBox(height: 24),

                  // Info Section
                  _buildInfoSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the header with logo and title
  Widget _buildHeader() {
    return Column(
      children: [
        // Logo placeholder (emoji for now)
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF22D3EE),
                Color(0xFFA78BFA),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text(
              '🏥',
              style: TextStyle(fontSize: 40),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          'MediSync Lab',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: 36,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        // Subtitle
        Text(
          'Your AI Health Coach. Your Data. Your Control.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFFA0AEC0),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Build the login form
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // WebID Label
        Text(
          'Your Solid WebID',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFFCBD5E1),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // WebID Input
        TextField(
          controller: _webIdController,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'https://pods.d01.solidcommunity.au/username/profile/card#me',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          style: const TextStyle(fontSize: 14),
        ),

        const SizedBox(height: 12),

        // Note about the redirect flow
        Row(
          children: [
            const Icon(Icons.open_in_new, size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'You\'ll be taken to your Solid provider to sign in securely — '
                'MediSync never sees your password.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build error message display
  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF87171).withValues(alpha: 0.1),
        border: Border.all(
          color: const Color(0xFFF87171),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFF87171),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: const TextStyle(
                color: Color(0xFFF87171),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the login button
  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: const Color(0xFF22D3EE),
        foregroundColor: const Color(0xFF0F172A),
        disabledBackgroundColor: const Color(0xFF64748B),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFF0F172A),
                ),
              ),
            )
          : const Text(
              'Continue with Solid Provider',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  /// Build information section
  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What is Solid?',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF22D3EE),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Solid is a protocol that lets you own your data. Instead of storing your health information on our servers, it stays in YOUR Pod — your personal online datastore. You control who can access it and for how long.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFA0AEC0),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your WebID is your unique identifier in the Solid ecosystem. It\'s like your email address, but it represents you across all Solid applications.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFA0AEC0),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
