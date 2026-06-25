import 'package:flutter/material.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _showPass = false;
  int _strength = 0;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  void _checkPass(String v) {
    int s = 0;
    if (v.length >= 8) s++;
    if (v.contains(RegExp(r'[A-Z]'))) s++;
    if (v.contains(RegExp(r'[0-9]'))) s++;
    if (v.contains(RegExp(r'[^A-Za-z0-9]'))) s++;
    setState(() => _strength = s);
  }

  Color get _strengthColor {
    const colors = [
      Color(0xFFEF4444), Color(0xFFF97316),
      Color(0xFFEAB308), Color(0xFF22C55E)
    ];
    return colors[(_strength - 1).clamp(0, 3)];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A06),
      body: Column(
        children: [
          // Photo top
          SizedBox(
            height: 210,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/login_bg.jpg',
                  fit: BoxFit.cover,
                  color: const Color(0xFF0A1A0D).withOpacity(0.5),
                  colorBlendMode: BlendMode.multiply,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF0D2016)),
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
                      stops: const [0.2, 1.0],
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
                  const Text('Create account,',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE8F5EE))),
                  const Text('join MindSpace.',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF52B788))),
                  const SizedBox(height: 5),
                  Text('Start your wellbeing journey today',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.32))),
                  const SizedBox(height: 24),

                  // Full Name
                  _fieldLabel(Icons.person_outline, 'Full name'),
                  _darkField(
                    controller: _nameCtrl,
                    hint: 'Your full name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),

                  // Email
                  _fieldLabel(Icons.mail_outline, 'Email address'),
                  _darkField(
                    controller: _emailCtrl,
                    hint: 'you@email.com',
                    icon: Icons.alternate_email,
                  ),
                  const SizedBox(height: 12),

                  // Password
                  _fieldLabel(Icons.lock_outline, 'Password'),
                  _darkField(
                    controller: _passCtrl,
                    hint: 'Create a password',
                    icon: Icons.key_outlined,
                    obscure: !_showPass,
                    onChanged: _checkPass,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _showPass = !_showPass),
                      icon: Icon(
                        _showPass
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white30,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),

                  // Strength bars
                  if (_passCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(
                        4,
                        (i) => Expanded(
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
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Create account button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        foregroundColor: const Color(0xFFE8F5EE),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                        elevation: 0,
                      ),
                      child: const Text('Create Account',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Divider
                  Row(children: [
                    Expanded(
                        child: Divider(
                            color: Colors.white.withOpacity(0.08))),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.2))),
                    ),
                    Expanded(
                        child: Divider(
                            color: Colors.white.withOpacity(0.08))),
                  ]),
                  const SizedBox(height: 12),

                  // Google
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.g_mobiledata,
                          color: Colors.white70, size: 22),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE8F5EE),
                        side: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 0.5),
                        backgroundColor:
                            Colors.white.withOpacity(0.06),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account?',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.25))),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        ),
                        child: const Text('Sign in',
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

  Widget _fieldLabel(IconData icon, String label) {
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

  Widget _darkField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
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
        style: const TextStyle(
            fontSize: 13, color: Color(0xFFE8F5EE)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.2)),
          prefixIcon: Icon(icon,
              size: 16, color: Colors.white.withOpacity(0.2)),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              vertical: 13, horizontal: 0),
        ),
      ),
    );
  }
}