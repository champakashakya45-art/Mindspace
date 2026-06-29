import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show themeNotifier;

class CrisisSupportScreen extends StatefulWidget {
  const CrisisSupportScreen({super.key});
  @override
  State<CrisisSupportScreen> createState() => _CrisisSupportScreenState();
}

class _CrisisSupportScreenState extends State<CrisisSupportScreen> {
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark = themeNotifier.value;
    themeNotifier.addListener(_onThemeChange);
  }

  void _onThemeChange() {
    if (mounted) setState(() => _isDark = themeNotifier.value);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  Color get _bg      => _isDark ? const Color(0xFF050A06) : const Color(0xFFF7FBF8);
  Color get _cardBg  => _isDark ? const Color(0xFF0D1F14) : Colors.white;
  Color get _txtMain => _isDark ? const Color(0xFFE8F5EE) : const Color(0xFF1B3A2D);
  Color get _txtSub  => _isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF6B8F7A);
  Color get _border  => _isDark
      ? const Color(0xFF52B788).withOpacity(0.15) : const Color(0xFFE2EEE7);

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        title: const Text('Crisis Support', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [

          // Emergency banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Text('🆘', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              const Text('Are you in crisis?', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: Colors.white)),
              const SizedBox(height: 4),
              Text('You are not alone. Help is available.',
                  style: TextStyle(fontSize: 13,
                      color: Colors.white.withOpacity(0.9))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _call('1926'),
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: const Text('Call Emergency: 1926',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0)),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Sri Lanka hotlines
          Text('🇱🇰 Sri Lanka Helplines', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: _txtMain)),
          const SizedBox(height: 10),

          _hotlineCard(emoji: '💚', name: 'Sumithrayo Sri Lanka',
              description: 'Emotional support & suicide prevention',
              number: '0800-11-2000', color: const Color(0xFF16A34A),
              onCall: () => _call('0800112000')),
          _hotlineCard(emoji: '🏥', name: 'NIMH Sri Lanka',
              description: 'National Institute of Mental Health',
              number: '011-2578234', color: const Color(0xFF2563EB),
              onCall: () => _call('0112578234')),
          _hotlineCard(emoji: '🆘', name: 'Emergency Services',
              description: 'Police / Ambulance / Fire',
              number: '119', color: const Color(0xFFDC2626),
              onCall: () => _call('119')),
          _hotlineCard(emoji: '👩‍⚕️', name: 'Shanthi Maargam',
              description: 'Mental health counselling',
              number: '1926', color: const Color(0xFF7C3AED),
              onCall: () => _call('1926')),
          const SizedBox(height: 20),

          // Self help
          Text('💆 Self-Help Resources', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: _txtMain)),
          const SizedBox(height: 10),

          _resourceCard(emoji: '🧘', title: 'Breathing Exercise',
              subtitle: '4-7-8 breathing to calm anxiety',
              color: const Color(0xFF0891B2),
              onTap: _showBreathingDialog),
          _resourceCard(emoji: '📖', title: 'Mental Health Tips',
              subtitle: 'Daily wellness practices',
              color: const Color(0xFF059669),
              onTap: _showTipsDialog),
          _resourceCard(emoji: '🌐', title: 'WHO Mental Health',
              subtitle: 'World Health Organization resources',
              color: const Color(0xFF2563EB),
              onTap: () => _openUrl(
                  'https://www.who.int/health-topics/mental-health')),
          const SizedBox(height: 20),

          // Remember
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border, width: 0.5)),
            child: Column(children: [
              const Text('💚', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 10),
              Text('Remember', style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w700, color: _txtMain)),
              const SizedBox(height: 8),
              Text(
                'It\'s okay to ask for help.\n'
                'Your feelings are valid.\n'
                'This too shall pass.\n'
                'You are stronger than you think.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13,
                    color: _txtSub, height: 1.8)),
            ]),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _hotlineCard({
    required String emoji, required String name,
    required String description, required String number,
    required Color color, required VoidCallback onCall,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 0.5),
        boxShadow: _isDark ? null : [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withOpacity(0.25), width: 0.5)),
          child: Center(child: Text(emoji,
              style: const TextStyle(fontSize: 20)))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: _txtMain)),
          const SizedBox(height: 2),
          Text(description, style: TextStyle(
              fontSize: 11, color: _txtSub)),
          const SizedBox(height: 2),
          Text(number, style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600, color: color)),
        ])),
        GestureDetector(
          onTap: onCall,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: color.withOpacity(0.3), width: 0.5)),
            child: Icon(Icons.phone_rounded,
                size: 18, color: color)),
        ),
      ]),
    );
  }

  Widget _resourceCard({
    required String emoji, required String title,
    required String subtitle, required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border, width: 0.5)),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(emoji,
                style: const TextStyle(fontSize: 20)))),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: _txtMain)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(
                fontSize: 11, color: _txtSub)),
          ])),
          Icon(Icons.chevron_right_rounded, size: 20, color: _txtSub),
        ]),
      ),
    );
  }

  void _showBreathingDialog() {
    showDialog(context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('🧘 4-7-8 Breathing', style: TextStyle(
            color: _txtMain, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('This technique helps calm anxiety and stress:',
              style: TextStyle(fontSize: 13, color: _txtSub)),
          const SizedBox(height: 12),
          _breathStep('1', 'Inhale', '4 seconds',
              const Color(0xFF2563EB)),
          _breathStep('2', 'Hold', '7 seconds',
              const Color(0xFF7C3AED)),
          _breathStep('3', 'Exhale', '8 seconds',
              const Color(0xFF059669)),
          const SizedBox(height: 8),
          Text('Repeat 4 times for best results.',
              style: TextStyle(fontSize: 12, color: _txtSub,
                  fontStyle: FontStyle.italic)),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D6A4F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0),
            child: const Text('Got it!')),
        ],
      ),
    );
  }

  Widget _breathStep(String num, String action,
      String duration, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle),
          child: Center(child: Text(num, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: color)))),
        const SizedBox(width: 10),
        Text('$action - ', style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w600, color: _txtMain)),
        Text(duration, style: TextStyle(fontSize: 13,
            color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  void _showTipsDialog() {
    showDialog(context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('📖 Wellness Tips', style: TextStyle(
            color: _txtMain, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _tip('😴', 'Get 7-8 hours of sleep'),
            _tip('🚶', 'Exercise for 30 minutes daily'),
            _tip('🥗', 'Eat balanced, nutritious meals'),
            _tip('💧', 'Stay hydrated - drink 8 glasses of water'),
            _tip('👥', 'Connect with friends and family'),
            _tip('📵', 'Limit social media usage'),
            _tip('🙏', 'Practice mindfulness or meditation'),
            _tip('📝', 'Journal your thoughts and feelings'),
            _tip('🌳', 'Spend time in nature'),
            _tip('🎯', 'Set small, achievable daily goals'),
          ]),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D6A4F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0),
            child: const Text('Thanks!')),
        ],
      ),
    );
  }

  Widget _tip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(
            fontSize: 12, color: _txtSub))),
      ]),
    );
  }
}