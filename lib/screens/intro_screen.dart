import 'package:flutter/material.dart';
import '../widgets/animated_bg.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedForestBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF142B1A).withOpacity(0.7),
                    border: Border.all(
                      color: const Color(0xFF52B788).withOpacity(0.22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF52B788).withOpacity(0.1),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.sentiment_satisfied_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'The best app\nfor your',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8F5EE),
                    height: 1.12,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  'wellbeing.',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF52B788),
                    height: 1.12,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Track your mood, understand your patterns,\nand grow — every single day.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withOpacity(0.38),
                    height: 1.72,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _Badge(icon: Icons.mood, label: 'Mood tracking'),
                    _Badge(icon: Icons.book_outlined, label: 'Journaling'),
                    _Badge(icon: Icons.insights, label: 'Insights'),
                    _Badge(icon: Icons.shield_outlined, label: 'Private'),
                  ],
                ),
                const Spacer(),
                Divider(color: Colors.white.withOpacity(0.06)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.12),
                        width: 0.5,
                      ),
                      backgroundColor: Colors.white.withOpacity(0.06),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Create an account',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'By continuing you agree to our Terms & Privacy Policy',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.18),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF52B788).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF52B788).withOpacity(0.18),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF52B788)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}