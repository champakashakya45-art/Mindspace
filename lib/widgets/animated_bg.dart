import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedForestBg extends StatefulWidget {
  final Widget child;
  const AnimatedForestBg({super.key, required this.child});

  @override
  State<AnimatedForestBg> createState() => _AnimatedForestBgState();
}

class _AnimatedForestBgState extends State<AnimatedForestBg>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _v = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..addListener(() {
      setState(() => _v = _ctrl.value);
    })..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final v = _v;
    return Stack(children: [
      // Base color
      Container(color: const Color(0xFF050A06)),

      // Orbs
      Positioned(top: -100 + v*22, right: -80 + v*15,
          child: _orb(320, const Color(0xFF0F2E1A))),
      Positioned(bottom: -60 - v*20, left: -60 + v*15,
          child: _orb(240, const Color(0xFF081A0D))),
      Positioned(
          top: sz.height*0.35 - v*16,
          left: sz.width*0.05 + v*12,
          child: Opacity(opacity: 0.6,
              child: _orb(160, const Color(0xFF1A4A2E)))),
      Positioned(
          bottom: sz.height*0.18 + (1-v)*16,
          right: sz.width*0.05 - (1-v)*12,
          child: Opacity(opacity: 0.35,
              child: _orb(90, const Color(0xFF2D6A4F)))),
      Positioned(
          top: sz.height*0.2 - v*10,
          left: sz.width*0.2 + v*8,
          child: Opacity(opacity: 0.15,
              child: _orb(50, const Color(0xFF52B788)))),

      // Rings
      Center(child: _ring(sz.width*1.1, 0.06, 1.0 + v*0.04)),
      Center(child: _ring(sz.width*0.82, 0.09, 1.0 + (1-v)*0.04)),
      Center(child: _ring(sz.width*0.53, 0.13, 1.0 + v*0.05)),

      // Child
      widget.child,
    ]);
  }

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
}