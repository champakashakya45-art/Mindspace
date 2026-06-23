import 'package:flutter/material.dart';
import 'dart:math' as math;

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

  late AnimationController _bgCtrl;
  late AnimationController _masterCtrl;
  final List<AnimationController> _letterCtrl = [];
  final List<Animation<double>> _letterY = [];
  final List<Animation<double>> _letterO = [];
  late AnimationController _tagCtrl;

  final _mind  = ['M','i','n','d'];
  final _space = ['S','p','a','c','e'];

  // Logo state - driven by requestAnimationFrame-style ticker
  double _lScale = 0.2;
  double _lRot   = -8.0;
  double _lOp    = 0.0;
  double _gSize  = 60.0;
  double _gOp    = 0.0;

  // Orb offsets driven by bg ticker
  double _bgV = 0.0;

  final _keys = [
    [0.00, 0.2,  -8.0, 0.0],
    [0.15, 1.12,  2.0, 1.0],
    [0.25, 0.96, -1.0, 1.0],
    [0.35, 1.03,  0.0, 1.0],
    [0.50, 1.00,  0.0, 1.0],
    [1.00, 1.00,  0.0, 1.0],
  ];

  double _ease(double t) =>
      t < 0.5 ? 2*t*t : 1 - math.pow(-2*t+2, 2)/2;
  double _lerp(double a, double b, double t) => a + (b-a)*t;

  @override
  void initState() {
    super.initState();

    // Background float - 7s loop
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..addListener(() {
      setState(() => _bgV = _bgCtrl.value);
    })..repeat(reverse: true);

    // Logo master - 8000ms
    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..addListener(_onLogoTick)..forward();

    // Letters: start at 3000ms, total spread 3000ms, 9 letters
    final all = [..._mind, ..._space];
    const dur   = 400;
    const total = 3000;
    final step  = (total - dur) ~/ (all.length - 1);

    for (int i = 0; i < all.length; i++) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: dur));
      _letterCtrl.add(c);
      _letterY.add(Tween<double>(begin: -36, end: 0).animate(
          CurvedAnimation(parent: c, curve: Curves.elasticOut)));
      _letterO.add(Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: c,
              curve: const Interval(0, 0.4, curve: Curves.easeIn))));
      Future.delayed(Duration(milliseconds: 3000 + i * step), () {
        if (mounted) c.forward();
      });
    }

    // Tagline at 6300ms
    _tagCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    Future.delayed(const Duration(milliseconds: 6300), () {
      if (mounted) _tagCtrl.forward();
    });
  }

  void _onLogoTick() {
    final raw = _masterCtrl.value;
    int i = 0;
    while (i < _keys.length - 2 && _keys[i+1][0] <= raw) i++;
    final k0 = _keys[i];
    final k1 = _keys[i+1];
    final seg = ((raw - k0[0]) / (k1[0] - k0[0])).clamp(0.0, 1.0);
    final e   = _ease(seg);

    double gs, go;
    if (raw < 0.2) {
      final p = raw / 0.2;
      gs = 60 + p * 140;
      go = p * 0.3;
    } else {
      gs = 180;
      go = 0.15;
    }

    setState(() {
      _lScale = _lerp(k0[1], k1[1], e);
      _lRot   = _lerp(k0[2], k1[2], e);
      _lOp    = _lerp(k0[3], k1[3], e);
      _gSize  = gs;
      _gOp    = go;
    });
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _bgCtrl.dispose();
    _tagCtrl.dispose();
    for (final c in _letterCtrl) c.dispose();
    super.dispose();
  }

  Widget _letter(int i, String ch, Color col) => AnimatedBuilder(
    animation: _letterCtrl[i],
    builder: (_, __) => Opacity(
      opacity: _letterO[i].value,
      child: Transform.translate(
        offset: Offset(0, _letterY[i].value),
        child: Text(ch,
            style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w500,
                color: col,
                height: 1.1)),
      ),
    ),
  );

  Widget _orb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _ring(double size, double op, double scale) =>
      Transform.scale(scale: scale,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF52B788).withOpacity(op),
              width: 0.5,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final v  = _bgV;

    return Scaffold(
      backgroundColor: const Color(0xFF050A06),
      body: Stack(children: [

        // ── Orb 1 - top right (f1: translate -22,22 + scale 1.05) ──
        Positioned(
          top:   -100 + v * 22,
          right:  -80 + v * 15,
          child: _orb(320, const Color(0xFF0F2E1A)),
        ),

        // ── Orb 2 - bottom left (f2: translate 22,-22 + scale 1.06) ──
        Positioned(
          bottom: -60 - v * 20,
          left:   -60 + v * 15,
          child: _orb(240, const Color(0xFF081A0D)),
        ),

        // ── Orb 3 - mid left (f3: translate 12,-16 + scale 1.1) ──
        Positioned(
          top:  sz.height * 0.35 - v * 16,
          left: sz.width  * 0.05 + v * 12,
          child: Opacity(opacity: 0.6,
              child: _orb(160, const Color(0xFF1A4A2E))),
        ),

        // ── Orb 4 - bottom right (f3 reverse) ──
        Positioned(
          bottom: sz.height * 0.18 + (1-v) * 16,
          right:  sz.width  * 0.05 - (1-v) * 12,
          child: Opacity(opacity: 0.35,
              child: _orb(90, const Color(0xFF2D6A4F))),
        ),

        // ── Orb 5 - small top left (f1 delayed) ──
        Positioned(
          top:  sz.height * 0.2 - v * 10,
          left: sz.width  * 0.2 + v * 8,
          child: Opacity(opacity: 0.15,
              child: _orb(50, const Color(0xFF52B788))),
        ),

        // ── Rings (rp: scale pulse) ──
        Center(child: _ring(420, 0.06, 1.0 + v * 0.04)),
        Center(child: _ring(310, 0.09, 1.0 + (1-v) * 0.04)),
        Center(child: _ring(200, 0.13, 1.0 + v * 0.05)),

        // ── Glow ──
        Center(
          child: Opacity(
            opacity: _gOp,
            child: Container(
              width: _gSize, height: _gSize,
              decoration: const BoxDecoration(
                color: Color(0xFF1A4A2E),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),

        // ── Center content ──
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // Logo box
              Opacity(
                opacity: _lOp,
                child: Transform.scale(
                  scale: _lScale,
                  child: Transform.rotate(
                    angle: _lRot * math.pi / 180,
                    child: Container(
                      width: 92, height: 92,
                      decoration: BoxDecoration(
                        color: const Color(0xFF142B1A),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF52B788).withOpacity(0.25),
                          width: 1,
                        ),
                        boxShadow: [BoxShadow(
                          color: const Color(0xFF52B788).withOpacity(0.2),
                          blurRadius: 40,
                          spreadRadius: 8,
                        )],
                      ),
                      child: Center(
                        child: CustomPaint(
                          size: const Size(56, 56),
                          painter: _LogoPainter(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Mind
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_mind.length,
                    (i) => _letter(i, _mind[i],
                        const Color(0xFFE8F5EE))),
              ),

              const SizedBox(height: 4),

              // Space
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_space.length,
                    (i) => _letter(i + _mind.length,
                        _space[i], const Color(0xFF52B788))),
              ),

              const SizedBox(height: 20),

              // Tagline
              FadeTransition(
                opacity: _tagCtrl,
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
      ]),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height * 0.43;
    final r  = size.height * 0.214;

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final green = Paint()
      ..color = const Color(0xFF52B788)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final dot = Paint()..color = Colors.white;

    // Circle (cx=28, cy=24, r=12 in 56x56 SVG)
    canvas.drawCircle(Offset(cx, cy), r, white);

    // Wave: M19 24 Q23.5 17 28 24 Q32.5 31 37 24
    final wave = Path()
      ..moveTo(cx - r*0.75, cy)
      ..quadraticBezierTo(cx - r*0.375, cy - r*0.583, cx, cy)
      ..quadraticBezierTo(cx + r*0.375, cy + r*0.583, cx + r*0.75, cy);
    canvas.drawPath(wave, green);

    // Eyes (cx=23,cy=20) and (cx=33,cy=20)
    canvas.drawCircle(Offset(cx - r*0.417, cy - r*0.333), 2.2, dot);
    canvas.drawCircle(Offset(cx + r*0.417, cy - r*0.333), 2.2, dot);

    // Body lines
    final body = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // line x1=28 y1=36 x2=28 y2=44
    canvas.drawLine(
      Offset(cx, cy + r * 1.0),
      Offset(cx, cy + r * 1.667),
      body,
    );
    // line x1=21 y1=41 x2=28 y2=44
    canvas.drawLine(
      Offset(cx - r*0.583, cy + r*1.417),
      Offset(cx, cy + r*1.667),
      body,
    );
    // line x1=35 y1=41 x2=28 y2=44
    canvas.drawLine(
      Offset(cx + r*0.583, cy + r*1.417),
      Offset(cx, cy + r*1.667),
      body,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}