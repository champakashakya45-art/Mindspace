import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindSpace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF050A06)),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _logoController;
  late AnimationController _taglineController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  final List<String> _mindLetters  = ['M','i','n','d'];
  final List<String> _spaceLetters = ['S','p','a','c','e'];

  final List<AnimationController> _letterControllers = [];
  final List<Animation<double>>   _letterOffsets     = [];
  final List<Animation<double>>   _letterOpacities   = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    _logoScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.2, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 0.96)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10),
      TweenSequenceItem(
        tween: Tween(begin: 0.96, end: 1.03)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10),
      TweenSequenceItem(
        tween: Tween(begin: 1.03, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 50),
    ]).animate(_logoController);

    _logoOpacity = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 85),
    ]).animate(_logoController);

    final allLetters = [..._mindLetters, ..._spaceLetters];
    const letterDurMs = 400;
    const totalLetterMs = 3000;
    final stepMs = (totalLetterMs - letterDurMs) ~/ (allLetters.length - 1);

    for (int i = 0; i < allLetters.length; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: letterDurMs),
      );
      _letterControllers.add(ctrl);
      _letterOffsets.add(
        Tween<double>(begin: -32, end: 0).animate(
          CurvedAnimation(parent: ctrl, curve: Curves.elasticOut),
        ),
      );
      _letterOpacities.add(
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: ctrl,
            curve: const Interval(0, 0.4, curve: Curves.easeIn),
          ),
        ),
      );

      Future.delayed(Duration(milliseconds: 3000 + i * stepMs), () {
        if (mounted) ctrl.forward();
      });
    }

    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    Future.delayed(const Duration(milliseconds: 6400), () {
      if (mounted) _taglineController.forward();
    });

    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _taglineController.dispose();
    for (final c in _letterControllers) c.dispose();
    super.dispose();
  }

  Widget _buildLetter(int index, String letter, Color color) {
    return AnimatedBuilder(
      animation: _letterControllers[index],
      builder: (_, __) => Opacity(
        opacity: _letterOpacities[index].value,
        child: Transform.translate(
          offset: Offset(0, _letterOffsets[index].value),
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w500,
              color: color,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // Background orbs
          Positioned(
            top: -100, right: -80,
            child: _buildOrb(320, const Color(0xFF0F2E1A)),
          ),
          Positioned(
            bottom: -60, left: -60,
            child: _buildOrb(240, const Color(0xFF081A0D)),
          ),
          Positioned(
            top: size.height * 0.35, left: size.width * 0.05,
            child: Opacity(
              opacity: 0.6,
              child: _buildOrb(160, const Color(0xFF1A4A2E)),
            ),
          ),
          Positioned(
            bottom: size.height * 0.18, right: size.width * 0.05,
            child: Opacity(
              opacity: 0.3,
              child: _buildOrb(90, const Color(0xFF2D6A4F)),
            ),
          ),

          // Pulsing rings
          Center(child: _buildRing(420, 0.06)),
          Center(child: _buildRing(310, 0.09)),
          Center(child: _buildRing(200, 0.13)),

          // Center content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo icon
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (_, child) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: child,
                    ),
                  ),
                  child: Container(
                    width: 92, height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFF142B1A),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFF52B788).withOpacity(0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.sentiment_satisfied_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // "Mind" letters
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    _mindLetters.length,
                    (i) => _buildLetter(
                      i,
                      _mindLetters[i],
                      const Color(0xFFE8F5EE),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // "Space" letters
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    _spaceLetters.length,
                    (i) => _buildLetter(
                      i + _mindLetters.length,
                      _spaceLetters[i],
                      const Color(0xFF52B788),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Tagline
                FadeTransition(
                  opacity: _taglineController,
                  child: const Text(
                    'WELLNESS · CLARITY · GROWTH',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 3,
                      color: Color(0x7252B788),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildRing(double size, double opacity) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF52B788).withOpacity(opacity),
          width: 0.5,
        ),
      ),
    );
  }
}