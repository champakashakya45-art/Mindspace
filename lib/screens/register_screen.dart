import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _showPass   = false;
  bool _loading    = false;
  int  _strength   = 0;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
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
        'name':      user.displayName ?? _nameCtrl.text.trim(),
        'email':     user.email ?? '',
        'photoUrl':  user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
        .hasMatch(_emailCtrl.text.trim())) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await cred.user?.updateDisplayName(_nameCtrl.text.trim());
      if (cred.user != null) await _saveUserToFirestore(cred.user!);
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'email-already-in-use' =>
              'This email is already registered. Please log in.',
          'weak-password' =>
              'Password is too weak. Use at least 6 characters.',
          'invalid-email' => 'Invalid email address.',
          _ => 'Registration failed. Please try again.',
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleRegister() async {
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
      final cred = await FirebaseAuth.instance
          .signInWithCredential(credential);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050E08),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071A0D), Color(0xFF050E08), Color(0xFF030805)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF52B788).withOpacity(0.08),
                        border: Border.all(
                          color: const Color(0xFF52B788).withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white60, size: 16),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            color: const Color(0xFF142B1A).withOpacity(0.9),
                            border: Border.all(
                              color: const Color(0xFF52B788).withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Center(child: CustomPaint(
                              size: const Size(26, 26),
                              painter: _LogoPainter())),
                        ),
                        const SizedBox(width: 10),
                        const Text('MindSpace',
                            style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE8F5EE))),
                      ]),
                      const SizedBox(height: 28),

                      const Text('Create account,',
                          style: TextStyle(fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE8F5EE),
                              height: 1.15, letterSpacing: -0.5)),
                      const Text('join MindSpace.',
                          style: TextStyle(fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF52B788),
                              height: 1.15, letterSpacing: -0.5)),
                      const SizedBox(height: 5),
                      Text('Start your wellbeing journey today',
                          style: TextStyle(fontSize: 12.5,
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
                                style: const TextStyle(fontSize: 12,
                                    color: Color(0xFFEF4444)))),
                          ]),
                        ),
                        const SizedBox(height: 12),
                      ],

                      _fieldLabel(Icons.person_outline, 'Full name'),
                      _DarkField(controller: _nameCtrl,
                          hint: 'Your full name',
                          icon: Icons.person_outline),
                      const SizedBox(height: 12),

                      _fieldLabel(Icons.mail_outline, 'Email address'),
                      _DarkField(controller: _emailCtrl,
                          hint: 'you@email.com',
                          icon: Icons.alternate_email),
                      const SizedBox(height: 12),

                      _fieldLabel(Icons.lock_outline, 'Password'),
                      _DarkField(
                        controller: _passCtrl,
                        hint: 'Create a password',
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
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
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
                              : const Text('CREATE ACCOUNT',
                                  style: TextStyle(fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8)),
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
                          onPressed: _loading ? null : _googleRegister,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE8F5EE),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                                width: 0.5),
                            backgroundColor: Colors.white.withOpacity(0.05),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20,
                                  child: CustomPaint(
                                      painter: _GooglePainter())),
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
                          Text('Already have an account?',
                              style: TextStyle(fontSize: 12,
                                  color: Colors.white.withOpacity(0.25))),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen())),
                            child: const Text('Sign in',
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
        ),
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

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.43;
    final r  = size.height * 0.214;
    final white = Paint()..color = Colors.white
      ..style = PaintingStyle.stroke..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final green = Paint()..color = const Color(0xFF52B788)
      ..style = PaintingStyle.stroke..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, white);
    final wave = Path()
      ..moveTo(cx - r * 0.75, cy)
      ..quadraticBezierTo(cx - r * 0.35, cy - r * 0.6, cx, cy)
      ..quadraticBezierTo(cx + r * 0.35, cy + r * 0.6, cx + r * 0.75, cy);
    canvas.drawPath(wave, green);
    final dot = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - r * 0.42, cy - r * 0.35), 2.2, dot);
    canvas.drawCircle(Offset(cx + r * 0.42, cy - r * 0.35), 2.2, dot);
    final body = Paint()..color = Colors.white
      ..strokeWidth = 2.0..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy+r), Offset(cx, cy+r*1.65), body);
    canvas.drawLine(Offset(cx-r*0.6, cy+r*1.4), Offset(cx, cy+r*1.65), body);
    canvas.drawLine(Offset(cx+r*0.6, cy+r*1.4), Offset(cx, cy+r*1.65), body);
  }
  @override
  bool shouldRepaint(_) => false;
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