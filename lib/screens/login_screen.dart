import 'package:flutter/material.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  bool _emailValid = false;
  int _strength = 0;

  void _checkEmail(String v) {
    setState(() {
      _emailValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
    });
  }

  void _checkPass(String v) {
    int s = 0;
    if (v.length >= 8) s++;
    if (v.contains(RegExp(r'[A-Z]'))) s++;
    if (v.contains(RegExp(r'[0-9]'))) s++;
    if (v.contains(RegExp(r'[^A-Za-z0-9]'))) s++;
    setState(() => _strength = s);
  }

  Color get _strengthColor {
    const colors = [Color(0xFFEF4444), Color(0xFFF97316),
                    Color(0xFFEAB308), Color(0xFF22C55E)];
    return colors[(_strength - 1).clamp(0, 3)];
  }

  String get _strengthLabel {
    const labels = ['Weak', 'Fair', 'Good', 'Strong'];
    return labels[(_strength - 1).clamp(0, 3)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A06),
      body: Column(
        children: [
          // Photo top
          SizedBox(
            height: 250,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/login_bg.jpg',
                  fit: BoxFit.cover,
                  color: const Color(0xFF0A1A0D).withOpacity(0.45),
                  colorBlendMode: BlendMode.multiply,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF0D2016),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF050A06).withOpacity(0.98),
                      ],
                      stops: const [0.25, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white70, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back,',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE8F5EE),
                      height: 1.2,
                    ),
                  ),
                  const Text(
                    'good to see you.',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF52B788),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Sign in to continue your wellbeing journey',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.32),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email field
                  _FieldLabel(icon: Icons.mail_outline, label: 'Email address'),
                  _DarkField(
                    controller: _emailCtrl,
                    hint: 'you@email.com',
                    icon: Icons.alternate_email,
                    onChanged: _checkEmail,
                    suffix: _emailValid
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFF22C55E), size: 18)
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Password field
                  _FieldLabel(icon: Icons.lock_outline, label: 'Password'),
                  _DarkField(
                    controller: _passCtrl,
                    hint: 'Enter your password',
                    icon: Icons.key_outlined,
                    obscure: !_showPass,
                    onChanged: _checkPass,
                    suffix: IconButton(
                      onPressed: () => setState(() => _showPass = !_showPass),
                      icon: Icon(
                        _showPass ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white30,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  if (_passCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(4, (i) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 3),
                          height: 2,
                          decoration: BoxDecoration(
                            color: i < _strength
                                ? _strengthColor
                                : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      )),
                    ),
                    const SizedBox(height: 3),
                    Text(_strengthLabel,
                        style: TextStyle(
                            fontSize: 10, color: _strengthColor)),
                  ],
                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Forgot password?',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF52B788),
                            fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 20),

                  // Login btn
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        foregroundColor: const Color(0xFFE8F5EE),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                        elevation: 0,
                      ),
                      child: const Text('Log in',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Divider
                  Row(children: [
                    Expanded(child: Divider(
                        color: Colors.white.withOpacity(0.08))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.2))),
                    ),
                    Expanded(child: Divider(
                        color: Colors.white.withOpacity(0.08))),
                  ]),
                  const SizedBox(height: 12),

                  // Google
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: Image.network(
                        'https://www.google.com/favicon.ico',
                        width: 18, height: 18,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.g_mobiledata,
                                color: Colors.white70),
                      ),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE8F5EE),
                        side: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 0.5),
                        backgroundColor: Colors.white.withOpacity(0.06),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sign up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.25))),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen())),
                        child: const Text('Sign up',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF52B788),
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FieldLabel({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Icon(icon, size: 10, color: const Color(0xFF52B788)),
        const SizedBox(width: 4),
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.38),
                letterSpacing: 0.09)),
      ]),
    );
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  const _DarkField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1A10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 0.5,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: Color(0xFFE8F5EE)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 13, color: Colors.white.withOpacity(0.2)),
          prefixIcon: Icon(icon, size: 16,
              color: Colors.white.withOpacity(0.2)),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              vertical: 13, horizontal: 0),
        ),
      ),
    );
  }
}