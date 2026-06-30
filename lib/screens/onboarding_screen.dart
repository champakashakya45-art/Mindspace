import 'package:flutter/material.dart';
import 'intro_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  int _cur = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Track your',
      'highlight': 'daily mood',
      'sub': 'Log how you feel each day with a simple mood scale and journal entry.',
      'img': 'assets/images/mood.jpg',
    },
    {
      'title': 'Notice your',
      'highlight': 'patterns',
      'sub': 'See mood trends, streaks and insights that help you understand yourself better.',
      'img': 'assets/images/patterns.jpg',
    },
    {
      'title': 'Your space,',
      'highlight': 'your journey',
      'sub': 'Everything is private and secure. Only you can see your mood and journal data.',
      'img': 'assets/images/journey.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_cur < 2) {
      setState(() => _cur++);
      _animCtrl.reset();
      _animCtrl.forward();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const IntroScreen()),
      );
    }
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const IntroScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_cur];
    return Scaffold(
      backgroundColor: const Color(0xFF050A06),
      body: Column(
        children: [
          // Photo
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.48,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Image.asset(
                    slide['img']!,
                    key: ValueKey(slide['img']),
                    fit: BoxFit.cover,
                    color: const Color(0xFF0A1A0D).withOpacity(0.45),
                    colorBlendMode: BlendMode.multiply,
                  ),
                ),
                // Bottom fade
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF050A06).withOpacity(0.98),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
                // Top bar
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          '${_cur + 1} / 3',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (_cur < 2)
                        GestureDetector(
                          onTap: _skip,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 0.5,
                              ),
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slide['title']!,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE8F5EE),
                              height: 1.22,
                            ),
                          ),
                          Text(
                            slide['highlight']!,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF52B788),
                              height: 1.22,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            slide['sub']!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.38),
                              height: 1.75,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Progress bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(1),
                          child: LinearProgressIndicator(
                            value: (_cur + 1) / 3,
                            backgroundColor:
                                Colors.white.withOpacity(0.1),
                            valueColor:
                                const AlwaysStoppedAnimation(Color(0xFF52B788)),
                            minHeight: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_cur + 1} / 3',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.25),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Next button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        foregroundColor: const Color(0xFFD8F3DC),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _cur == 2 ? 'Get started' : 'Next',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _cur ? 22 : 7,
                        height: 3,
                        decoration: BoxDecoration(
                          color: i == _cur
                              ? const Color(0xFF52B788)
                              : const Color(0xFF52B788).withOpacity(0.22),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
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