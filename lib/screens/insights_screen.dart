import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart' show themeNotifier;

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;
  bool _loading = true;
  late bool _isDark;

  int _totalLogs   = 0;
  int _streak      = 0;
  int _bestStreak  = 0;
  double _avgMood  = 0;
  Map<String, int> _moodCounts = {};
  List<int> _monthMoods = [];

  final _moodLabels = ['Awful','Bad','Okay','Good','Amazing'];
  final _moodColors = [
    const Color(0xFFEF4444),
    const Color(0xFFF97316),
    const Color(0xFFFFD93D),
    const Color(0xFF52B788),
    const Color(0xFF06D6A0),
  ];
  final _moodEmojis = ['😢','😕','😊','😄','🤩'];

  @override
  void initState() {
    super.initState();
    _isDark = themeNotifier.value;
    themeNotifier.addListener(_onThemeChange);
    _loadInsights();
  }

  void _onThemeChange() {
    if (mounted) setState(() => _isDark = themeNotifier.value);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  Color get _bg     => _isDark ? const Color(0xFF050A06) : const Color(0xFFF7FBF8);
  Color get _cardBg => _isDark ? const Color(0xFF0D1F14) : Colors.white;
  Color get _appBar => _isDark ? const Color(0xFF0F2E1A) : const Color(0xFF2D6A4F);
  Color get _txtMain=> _isDark ? const Color(0xFFE8F5EE) : const Color(0xFF1B3A2D);
  Color get _txtSub => _isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF6B8F7A);
  Color get _border => _isDark
      ? const Color(0xFF52B788).withOpacity(0.15)
      : const Color(0xFFE2EEE7);
  Color get _barEmpty => _isDark
      ? Colors.white.withOpacity(0.08)
      : Colors.black.withOpacity(0.06);

  Future<void> _loadInsights() async {
    setState(() => _loading = true);
    try {
      final uid = _auth.currentUser?.uid;
      final snap = await _db
          .collection('users').doc(uid)
          .collection('moods')
          .orderBy('timestamp', descending: false)
          .get();

      final docs = snap.docs;
      if (docs.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final total = docs.length;
      final avg = docs.fold<int>(0,
          (s, d) => s + ((d.data()['mood'] as int?) ?? 0)) / total;

      final counts = <String, int>{
        'Awful':0,'Bad':0,'Okay':0,'Good':0,'Amazing':0};
      for (final doc in docs) {
        final m = (doc.data()['mood'] as int?) ?? 0;
        if (m >= 1 && m <= 5) {
          counts[_moodLabels[m-1]] =
              (counts[_moodLabels[m-1]] ?? 0) + 1;
        }
      }

      final now = DateTime.now();
      int streak = 0;
      DateTime check = DateTime(now.year, now.month, now.day);
      while (true) {
        final dateStr = check.toIso8601String().substring(0, 10);
        final hasEntry = docs.any((d) => d.data()['date'] == dateStr);
        if (!hasEntry) break;
        streak++;
        check = check.subtract(const Duration(days: 1));
      }

      int best = 0, cur = 0;
      final allDates = docs.map((d) =>
          d.data()['date'] as String? ?? '').toSet().toList()..sort();
      for (int i = 0; i < allDates.length; i++) {
        if (i == 0) { cur = 1; }
        else {
          final prev = DateTime.parse(allDates[i-1]);
          final curr = DateTime.parse(allDates[i]);
          if (curr.difference(prev).inDays == 1) cur++;
          else cur = 1;
        }
        if (cur > best) best = cur;
      }

      final monthMoods = <int>[];
      for (int i = 29; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dateStr = day.toIso8601String().substring(0, 10);
        final entry = docs.where((d) => d.data()['date'] == dateStr);
        monthMoods.add(entry.isNotEmpty
            ? (entry.first.data()['mood'] as int? ?? 0) : 0);
      }

      setState(() {
        _totalLogs   = total;
        _avgMood     = avg;
        _moodCounts  = counts;
        _streak      = streak;
        _bestStreak  = best;
        _monthMoods  = monthMoods;
        _loading     = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBar,
        title: const Text('Insights',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFF52B788)))
          : _totalLogs == 0
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart, size: 64,
                        color: _txtSub.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text('No data yet.',
                        style: TextStyle(fontSize: 16, color: _txtSub)),
                    Text('Start logging moods to see insights.',
                        style: TextStyle(fontSize: 13,
                            color: _txtSub.withOpacity(0.6))),
                  ],
                ))
              : RefreshIndicator(
                  color: const Color(0xFF52B788),
                  onRefresh: _loadInsights,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [

                      // Stats row
                      Row(children: [
                        _statCard('$_totalLogs', 'Total Logs',
                            const Color(0xFF134E4A), const Color(0xFF0F766E)),
                        const SizedBox(width: 8),
                        _statCard('$_streak 🔥', 'Streak',
                            const Color(0xFF7F1D1D), const Color(0xFF991B1B)),
                        const SizedBox(width: 8),
                        _statCard('$_bestStreak', 'Best Streak',
                            const Color(0xFF713F12), const Color(0xFF92400E)),
                      ]),
                      const SizedBox(height: 12),

                      // Average mood
                      _card(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Average Mood',
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _txtMain)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Text(_avgMood >= 1
                                ? _moodEmojis[(_avgMood.round()-1).clamp(0,4)]
                                : '😊',
                                style: const TextStyle(fontSize: 40)),
                            const SizedBox(width: 16),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_avgMood >= 1
                                    ? _moodLabels[(_avgMood.round()-1).clamp(0,4)]
                                    : 'N/A',
                                    style: TextStyle(fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: _txtMain)),
                                Text('${_avgMood.toStringAsFixed(1)} / 5.0',
                                    style: TextStyle(fontSize: 13,
                                        color: _txtSub)),
                              ],
                            )),
                          ]),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _avgMood / 5,
                              backgroundColor: _barEmpty,
                              valueColor: AlwaysStoppedAnimation(
                                _avgMood >= 1
                                    ? _moodColors[(_avgMood.round()-1).clamp(0,4)]
                                    : const Color(0xFF52B788)),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      )),
                      const SizedBox(height: 12),

                      // Mood distribution
                      _card(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mood Distribution',
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _txtMain)),
                          const SizedBox(height: 12),
                          ..._moodLabels.asMap().entries.map((e) {
                            final i     = e.key;
                            final label = e.value;
                            final count = _moodCounts[label] ?? 0;
                            final pct   = _totalLogs > 0
                                ? count / _totalLogs : 0.0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(children: [
                                Text(_moodEmojis[i],
                                    style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                SizedBox(width: 55,
                                    child: Text(label,
                                        style: TextStyle(fontSize: 11,
                                            color: _txtSub))),
                                Expanded(child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    backgroundColor: _barEmpty,
                                    valueColor: AlwaysStoppedAnimation(
                                        _moodColors[i]),
                                    minHeight: 8,
                                  ),
                                )),
                                const SizedBox(width: 8),
                                SizedBox(width: 28,
                                    child: Text('$count',
                                        style: TextStyle(fontSize: 11,
                                            color: _txtSub,
                                            fontWeight: FontWeight.w600),
                                        textAlign: TextAlign.right)),
                              ]),
                            );
                          }),
                        ],
                      )),
                      const SizedBox(height: 12),

                      // 30-day chart
                      _card(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Last 30 Days',
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _txtMain)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 80,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: _monthMoods.map((m) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 1),
                                  child: FractionallySizedBox(
                                    heightFactor: m == 0 ? 0.05 : m / 5,
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: m == 0
                                            ? _barEmpty
                                            : _moodColors[m-1],
                                        borderRadius:
                                            BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                        ],
                      )),
                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
    );
  }

  Widget _statCard(String val, String label, Color c1, Color c2) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c1, c2],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: const TextStyle(fontSize: 18,
              fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9,
              color: Colors.white.withOpacity(0.8))),
        ]),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 0.5),
        boxShadow: _isDark ? null : [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}