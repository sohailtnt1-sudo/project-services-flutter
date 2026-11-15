// Login + signup (Supabase Auth, email/password).
// Same flow as the website: role is stored in profiles; email confirmation
// is ON, so a fresh sign-up may need the inbox confirmation link first.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repository.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  String _role = 'customer';
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  String? _notice;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _notice = null;
      _busy = true;
    });
    try {
      final email = _email.text.trim();
      final password = _password.text;
      if (_isLogin) {
        await db.auth.signInWithPassword(email: email, password: password);
        // Profile row is created by the DB trigger / ensureProfile on login.
        await ensureProfile(
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          role: _role,
        );
      } else {
        final res = await db.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': _name.text.trim(), 'phone': _phone.text.trim(), 'role': _role},
        );
        final user = res.user;
        if (user == null) throw Exception('Sign-up did not return an account.');
        if (res.session == null) {
          setState(() {
            _notice =
                'Account created. Please check your email and click the confirmation link, then log in.';
          });
          return;
        }
        await ensureProfile(
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          role: _role,
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sand,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              _logo(),
              const SizedBox(height: 8),
              const Text(
                'AsaanKaam',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.teal),
              ),
              const SizedBox(height: 4),
              const Text(
                'Trusted local professionals, booked in minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 28),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Log in')),
                  ButtonSegment(value: false, label: Text('Sign up')),
                ],
                selected: {_isLogin},
                onSelectionChanged: (s) => setState(() {
                  _isLogin = s.first;
                  _error = null;
                  _notice = null;
                }),
              ),
              const SizedBox(height: 20),
              if (!_isLogin) ...[
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone (03xx-xxxxxxx)'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 16),
                const Text('I am signing up as', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _roleCard('customer', 'Customer', 'I want to book services')),
                    const SizedBox(width: 12),
                    Expanded(child: _roleCard('provider', 'Provider', 'I want to offer services')),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF5C6C2)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.red)),
                ),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.teal),
                  ),
                  child: Text(_notice!),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy
                    ? 'Please wait…'
                    : _isLogin
                        ? 'Log in'
                        : 'Create account'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cash on delivery. No payment needed to book.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/logo-asaankaam-3d-worker-tricolor-blue-orange.webp',
          width: 72,
          height: 72,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _roleCard(String value, String label, String hint) {
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.tealLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
