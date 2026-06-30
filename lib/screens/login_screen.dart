import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _showPass   = false;
  bool _loading    = false;
  bool _emailValid = false;
  int  _strength   = 0;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

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
    const c = [Color(0xFFEF4444), Color(0xFFF97316),
                Color(0xFFEAB308), Color(0xFF22C55E)];
    return c[(_strength - 1).clamp(0, 3)];
  }

  String get _strengthLabel {
    const l = ['Weak', 'Fair', 'Good', 'Strong'];
    return l[(_strength - 1).clamp(0, 3)];
  }

  Future<void> _saveUserToFirestore(User user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid).set({
        'name':      user.displayName ?? '',
        'email':     user.email ?? '',
        'photoUrl':  user.photoURL ?? '',
        'lastLogin': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _emailLogin() async {
    if (!_emailValid) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (_passCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (cred.user != null) await _saveUserToFirestore(cred.user!);
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'user-not-found'     => 'No account found. Please register.',
          'wrong-password'     => 'Incorrect password. Please try again.',
          'invalid-email'      => 'Invalid email address.',
          'user-disabled'      => 'This account has been disabled.',
          'invalid-credential' => 'Invalid email or password.',
          _                    => 'Login failed. Please try again.',
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() { _loading = true; _error = null; });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      if (cred.user != null) await _saveUserToFirestore(cred.user!);
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      setState(() => _error = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (!_emailValid) {
      setState(() => _error = 'Please enter your email address first.');
      return;
    }
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent! Check your inbox.'),
            backgroundColor: Color(0xFF2D6A4F),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to send reset email. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A06),
      body: Column(
        children: [
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome back,',
                      style: TextStyle(fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE8F5EE))),
                  const Text('good to see you.',
                      style: TextStyle(fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF52B788))),
                  const SizedBox(height: 5),
                  Text('Sign in to continue your wellbeing journey',
                      style: TextStyle(fontSize: 12,
                          color: Colors.white.withOpacity(0.32))),
                  const SizedBox(height: 24),

                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFEF4444)))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],

                  _fieldLabel(Icons.mail_outline, 'Email address'),
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

                  _fieldLabel(Icons.lock_outline, 'Password'),
                  _DarkField(
                    controller: _passCtrl,
                    hint: 'Enter your password',
                    icon: Icons.key_outlined,
                    obscure: !_showPass,
                    onChanged: _checkPass,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _showPass = !_showPass),
                      icon: Icon(
                        _showPass ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white30, size: 18),
                      padding: EdgeInsets.zero,
                    ),
                  ),

                  if (_passCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: List.generate(4, (i) => Expanded(
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
                    ))),
                    const SizedBox(height: 3),
                    Text(_strengthLabel,
                        style: TextStyle(fontSize: 10,
                            color: _strengthColor)),
                  ],
                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _forgotPassword,
                      child: const Text('Forgot password?',
                          style: TextStyle(fontSize: 12,
                              color: Color(0xFF52B788),
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _emailLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        foregroundColor: const Color(0xFFE8F5EE),
                        disabledBackgroundColor:
                            const Color(0xFF2D6A4F).withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Log in',
                              style: TextStyle(fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(child: Divider(
                        color: Colors.white.withOpacity(0.08))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or', style: TextStyle(fontSize: 11,
                          color: Colors.white.withOpacity(0.2))),
                    ),
                    Expanded(child: Divider(
                        color: Colors.white.withOpacity(0.08))),
                  ]),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _googleLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE8F5EE),
                        side: BorderSide(
                            color: Colors.white.withOpacity(0.1), width: 0.5),
                        backgroundColor: Colors.white.withOpacity(0.06),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 20, height: 20,
                              child: CustomPaint(painter: _GooglePainter())),
                          const SizedBox(width: 10),
                          const Text('CONTINUE WITH GOOGLE',
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?",
                          style: TextStyle(fontSize: 12,
                              color: Colors.white.withOpacity(0.25))),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen())),
                        child: const Text('Sign up',
                            style: TextStyle(fontSize: 12,
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
            style: TextStyle(fontSize: 10,
                color: Colors.white.withOpacity(0.38),
                letterSpacing: 0.09)),
      ]),
    );
  }
}

class _DarkField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  const _DarkField({required this.controller, required this.hint,
      required this.icon, this.obscure = false,
      this.onChanged, this.suffix});
  @override
  State<_DarkField> createState() => _DarkFieldState();
}

class _DarkFieldState extends State<_DarkField> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: _focused ? const LinearGradient(
            colors: [Color(0xFF52B788), Color(0xFF2D6A4F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight) : null,
        color: _focused ? null : Colors.white.withOpacity(0.07),
      ),
      padding: const EdgeInsets.all(1),
      child: Container(
        decoration: BoxDecoration(
          color: _focused ? const Color(0xFF0D1F14) : const Color(0xFF0A1810),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          child: TextField(
            controller: widget.controller,
            obscureText: widget.obscure,
            onChanged: widget.onChanged,
            style: const TextStyle(fontSize: 13, color: Color(0xFFE8F5EE)),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(fontSize: 13,
                  color: Colors.white.withOpacity(0.2)),
              prefixIcon: Icon(widget.icon, size: 16,
                  color: _focused ? const Color(0xFF52B788)
                      : Colors.white.withOpacity(0.2)),
              suffixIcon: widget.suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 13, horizontal: 0),
            ),
          ),
        ),
      ),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(w * 0.99, h * 0.51)
      ..cubicTo(w * 0.99, h * 0.47, w * 0.985, h * 0.43, w * 0.975, h * 0.39)
      ..lineTo(w * 0.5, h * 0.39)
      ..lineTo(w * 0.5, h * 0.62)
      ..lineTo(w * 0.78, h * 0.62)
      ..cubicTo(w * 0.765, h * 0.70, w * 0.72, h * 0.765, w * 0.65, h * 0.81)
      ..lineTo(w * 0.65, h * 0.965)
      ..lineTo(w * 0.855, h * 0.965)
      ..cubicTo(w * 0.955, h * 0.875, w * 0.99, h * 0.705, w * 0.99, h * 0.51)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    final greenPaint = Paint()..color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(w * 0.5, h * 1.0)
      ..cubicTo(w * 0.635, h * 1.0, w * 0.75, h * 0.955, w * 0.835, h * 0.875)
      ..lineTo(w * 0.65, h * 0.81)
      ..cubicTo(w * 0.595, h * 0.845, w * 0.525, h * 0.865, w * 0.5, h * 0.865)
      ..cubicTo(w * 0.345, h * 0.865, w * 0.215, h * 0.76, w * 0.165, h * 0.62)
      ..lineTo(w * -0.035, h * 0.62)
      ..lineTo(w * -0.035, h * 0.78)
      ..cubicTo(w * 0.065, h * 0.93, w * 0.27, h * 1.0, w * 0.5, h * 1.0)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(w * 0.165, h * 0.62)
      ..cubicTo(w * 0.15, h * 0.575, w * 0.142, h * 0.527, w * 0.142, h * 0.5)
      ..cubicTo(w * 0.142, h * 0.473, w * 0.15, h * 0.425, w * 0.165, h * 0.38)
      ..lineTo(w * 0.165, h * 0.22)
      ..lineTo(w * -0.035, h * 0.22)
      ..cubicTo(w * -0.085, h * 0.32, w * -0.115, h * 0.405, w * -0.115, h * 0.5)
      ..cubicTo(w * -0.115, h * 0.595, w * -0.085, h * 0.68, w * -0.035, h * 0.78)
      ..lineTo(w * 0.165, h * 0.62)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(w * 0.5, h * 0.135)
      ..cubicTo(w * 0.578, h * 0.135, w * 0.648, h * 0.163, w * 0.703, h * 0.215)
      ..lineTo(w * 0.84, h * 0.078)
      ..cubicTo(w * 0.75, h * -0.005, w * 0.635, h * -0.05, w * 0.5, h * -0.05)
      ..cubicTo(w * 0.27, h * -0.05, w * 0.065, h * 0.07, w * -0.035, h * 0.22)
      ..lineTo(w * 0.165, h * 0.38)
      ..cubicTo(w * 0.215, h * 0.24, w * 0.345, h * 0.135, w * 0.5, h * 0.135)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }
  @override
  bool shouldRepaint(_) => false;
}