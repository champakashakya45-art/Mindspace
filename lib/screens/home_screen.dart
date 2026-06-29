import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart' show themeNotifier, setTheme;
import 'intro_screen.dart';
import 'journal_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late bool _isDark;
  int  _selectedMood = -1;
  int  _selectedNav  = 0;
  final _noteCtrl    = TextEditingController();
  bool _moodLogged   = false;
  bool _logging      = false;
  bool _loading      = true;

  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  Map<int, int> _calMoods   = {};
  List<int>     _weekMoods  = [0,0,0,0,0,0,0];
  int _streak        = 0;
  int _totalLogs     = 0;
  int _totalJournals = 0;
  List<Map<String, dynamic>> _recentJournals = [];
  String? _photoUrl;
  DateTime _calMonth = DateTime.now();

  final _moods = [
    {'emoji': '😢', 'label': 'Awful',   'val': 1},
    {'emoji': '😕', 'label': 'Bad',     'val': 2},
    {'emoji': '😊', 'label': 'Okay',    'val': 3},
    {'emoji': '😄', 'label': 'Good',    'val': 4},
    {'emoji': '🤩', 'label': 'Amazing', 'val': 5},
  ];

  final _moodColors = [
    Colors.transparent,
    const Color(0xFFEF4444),
    const Color(0xFFF97316),
    const Color(0xFFFFD93D),
    const Color(0xFF52B788),
    const Color(0xFF06D6A0),
  ];

  final _weekDays = ['M','T','W','T','F','S','S'];

  @override
  void initState() {
    super.initState();
    _isDark   = themeNotifier.value;
    _photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
    themeNotifier.addListener(_onThemeChange);
    _loadAllData();
  }

  void _onThemeChange() {
    if (mounted) setState(() => _isDark = themeNotifier.value);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    _noteCtrl.dispose();
    super.dispose();
  }

  Color get _bg      => _isDark ? const Color(0xFF050A06) : const Color(0xFFF7FBF8);
  Color get _cardBg  => _isDark ? const Color(0xFF0D1F14) : Colors.white;
  Color get _txtMain => _isDark ? const Color(0xFFE8F5EE) : const Color(0xFF1B3A2D);
  Color get _txtSub  => _isDark ? Colors.white.withOpacity(0.35) : const Color(0xFF6B8F7A);
  Color get _border  => _isDark
      ? const Color(0xFF52B788).withOpacity(0.15)
      : const Color(0xFFE2EEE7);

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final now = DateTime.now();

      final moodsSnap = await _db
          .collection('users').doc(uid)
          .collection('moods')
          .orderBy('timestamp', descending: false)
          .get();

      final journalsSnap = await _db
          .collection('users').doc(uid)
          .collection('journals')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      // Calendar - selected month
      final calMap = <int, int>{};
      for (final doc in moodsSnap.docs) {
        final data = doc.data();
        final date = data['date'] as String?;
        if (date == null) continue;
        try {
          final d = DateTime.parse(date);
          if (d.month == _calMonth.month &&
              d.year  == _calMonth.year) {
            calMap[d.day] = (data['mood'] as int?) ?? 0;
          }
        } catch (_) {}
      }

      final weekMoods = <int>[];
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dateStr = day.toIso8601String().substring(0, 10);
        final entries = moodsSnap.docs.where(
            (d) => d.data()['date'] == dateStr);
        weekMoods.add(entries.isNotEmpty
            ? (entries.first.data()['mood'] as int? ?? 0) : 0);
      }

      int streak = 0;
      DateTime check = DateTime(now.year, now.month, now.day);
      while (true) {
        final dateStr = check.toIso8601String().substring(0, 10);
        final hasEntry = moodsSnap.docs.any(
            (d) => d.data()['date'] == dateStr);
        if (!hasEntry) break;
        streak++;
        check = check.subtract(const Duration(days: 1));
      }

      final today = now.toIso8601String().substring(0, 10);
      final todayMood = moodsSnap.docs.where(
          (d) => d.data()['date'] == today);
      final moodLogged = todayMood.isNotEmpty;

      final recentJournals = journalsSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'id':        doc.id,
          'title':     data['title']     ?? 'Untitled',
          'content':   data['content']   ?? '',
          'mood':      data['mood']      ?? 0,
          'moodEmoji': data['moodEmoji'] ?? '📝',
          'moodLabel': data['moodLabel'] ?? '',
          'date':      data['date']      ?? '',
          'timestamp': data['timestamp'],
        };
      }).toList();

      final allJournals = await _db
          .collection('users').doc(uid)
          .collection('journals')
          .count().get();

      if (mounted) {
        setState(() {
          _calMoods       = calMap;
          _weekMoods      = weekMoods;
          _streak         = streak;
          _totalLogs      = moodsSnap.docs.length;
          _totalJournals  = allJournals.count ?? 0;
          _moodLogged     = moodLogged;
          _recentJournals = recentJournals;
          _photoUrl       = _auth.currentUser?.photoURL;
          _loading        = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logMood() async {
    if (_selectedMood < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a mood first!'),
        backgroundColor: Color(0xFFF97316)));
      return;
    }
    setState(() => _logging = true);
    try {
      final uid  = _auth.currentUser?.uid;
      final mood = _moods[_selectedMood];
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await _db.collection('users').doc(uid)
          .collection('moods').add({
        'mood':      mood['val'],
        'moodLabel': mood['label'],
        'emoji':     mood['emoji'],
        'note':      _noteCtrl.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'date':      today,
      });
      if (mounted) {
        setState(() {
          _moodLogged = true;
          _totalLogs++;
          _calMoods[DateTime.now().day] = mood['val'] as int;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Mood logged! ${mood['emoji']}'),
          backgroundColor: const Color(0xFF2D6A4F)));
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to log mood. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const IntroScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now      = DateTime.now();
    final hour     = now.hour;
    final greeting = hour < 12 ? 'Good morning ☀️'
        : hour < 17 ? 'Good afternoon 🌤️'
        : 'Good evening 🌙';
    final user = _auth.currentUser;
    final name = user?.displayName?.split(' ').first
        ?? user?.email?.split('@').first ?? 'User';

    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _buildHeader(greeting, name),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: Color(0xFF52B788)))
              : RefreshIndicator(
                  color: const Color(0xFF52B788),
                  onRefresh: _loadAllData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                    child: Column(children: [
                      _buildQuote(),
                      const SizedBox(height: 10),
                      _buildCalendar(),
                      const SizedBox(height: 10),
                      _buildMoodCard(),
                      const SizedBox(height: 10),
                      _buildStreaks(),
                      const SizedBox(height: 10),
                      _buildWeeklySummary(),
                      const SizedBox(height: 10),
                      _buildChart(),
                      const SizedBox(height: 10),
                      _buildJournal(),
                      const SizedBox(height: 10),
                    ]),
                  ),
                ),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── HEADER ──
  Widget _buildHeader(String greeting, String name) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDark
              ? [const Color(0xFF0A1F0E), const Color(0xFF0F2E1A)]
              : [const Color(0xFF1B4332), const Color(0xFF2D6A4F)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: TextStyle(fontSize: 11,
                    color: Colors.white.withOpacity(0.55))),
                const SizedBox(height: 2),
                Text('Hello, $name', style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: Colors.white)),
              ],
            )),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileScreen()))
                  .then((_) => _loadAllData()),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2)),
                child: ClipOval(
                  child: _photoUrl != null && _photoUrl!.isNotEmpty
                      ? Image.network(_photoUrl!,
                          fit: BoxFit.cover, width: 40, height: 40,
                          errorBuilder: (_, __, ___) =>
                              _avatarFallback(name))
                      : _avatarFallback(name),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      width: 40, height: 40,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight)),
      child: Center(child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(fontSize: 16,
            fontWeight: FontWeight.w700, color: Colors.white))),
    );
  }

  // ── QUOTE ──
  Widget _buildQuote() {
    final quotes = [
      'Every day is a new beginning. 🌱',
      'You are stronger than you think. 💪',
      'Small steps lead to big changes. 👣',
      'Be kind to yourself today. 💚',
      'Progress, not perfection. ✨',
      'Your mental health matters. 🌿',
      'Breathe. You\'ve got this. 🧘',
      'One step at a time. 🚶',
      'Healing is not linear. 💙',
      'You matter more than you know. 🌟',
    ];
    final quote = quotes[DateTime.now().day % quotes.length];
    return _card(child: Row(children: [
      Container(width: 3, height: 44,
          decoration: BoxDecoration(
              color: const Color(0xFF52B788),
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 12),
      Expanded(child: Text('"$quote"',
          style: TextStyle(fontSize: 12,
              color: _txtMain, fontStyle: FontStyle.italic,
              height: 1.5))),
      const SizedBox(width: 8),
      const Text('💚', style: TextStyle(fontSize: 20)),
    ]));
  }

  // ── WEEKLY SUMMARY ──
  Widget _buildWeeklySummary() {
    final nonZero = _weekMoods.where((m) => m > 0).toList();
    if (nonZero.isEmpty) return const SizedBox();

    final moodLabels = ['','Awful','Bad','Okay','Good','Amazing'];
    final moodEmojis = ['','😢','😕','😊','😄','🤩'];
    final moodColors = [
      Colors.transparent,
      const Color(0xFFEF4444), const Color(0xFFF97316),
      const Color(0xFFFFD93D), const Color(0xFF52B788),
      const Color(0xFF06D6A0),
    ];

    final counts = <int,int>{};
    for (final m in nonZero) counts[m] = (counts[m] ?? 0) + 1;
    final topMood = counts.entries
        .reduce((a, b) => a.value > b.value ? a : b).key;
    final avg = nonZero.reduce((a,b) => a+b) / nonZero.length;

    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Row(children: [
        const Text('📊', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text('This Week\'s Mood', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: _txtMain)),
      ]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: moodColors[topMood].withOpacity(
              _isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: moodColors[topMood].withOpacity(0.3),
              width: 0.5)),
        child: Row(children: [
          Text(moodEmojis[topMood],
              style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text('This week you felt mostly',
                style: TextStyle(fontSize: 11, color: _txtSub)),
            Text(moodLabels[topMood], style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: moodColors[topMood])),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end,
              children: [
            Text('Avg', style: TextStyle(fontSize: 9, color: _txtSub)),
            Text(avg.toStringAsFixed(1), style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: _txtMain)),
            Text('/ 5.0', style: TextStyle(
                fontSize: 9, color: _txtSub)),
          ]),
        ]),
      ),
    ]));
  }

  // ── CALENDAR ──
  Widget _buildCalendar() {
    final now = DateTime.now();
    final isCurrentMonth = _calMonth.month == now.month &&
        _calMonth.year == now.year;

    return _card(child: Column(children: [
      Row(children: [
        Text('${_monthName(_calMonth.month)} ${_calMonth.year}',
            style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700, color: _txtMain)),
        const Spacer(),
        // Prev month
        GestureDetector(
          onTap: () {
            setState(() => _calMonth =
                DateTime(_calMonth.year, _calMonth.month - 1));
            _loadAllData();
          },
          child: _calNavBtn('‹')),
        const SizedBox(width: 4),
        // Next month - future block
       GestureDetector(
  onTap: () {
    final now2 = DateTime.now();
    final next = DateTime(
        _calMonth.year, _calMonth.month + 1);
    final nowMonth  = DateTime(now2.year, now2.month);
    final nextMonth = DateTime(next.year, next.month);
    if (nextMonth.year < nowMonth.year ||
        (nextMonth.year == nowMonth.year &&
         nextMonth.month <= nowMonth.month)) {
      setState(() => _calMonth = next);
      _loadAllData();
    }
  },
  child: _calNavBtn('›',
      disabled: isCurrentMonth)),
      ]),
      const SizedBox(height: 10),
      Row(children: ['Su','Mo','Tu','We','Th','Fr','Sa']
          .map((d) => Expanded(child: Text(d,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9,
                  fontWeight: FontWeight.w600, color: _txtSub))))
          .toList()),
      const SizedBox(height: 4),
      _buildCalGrid(),
      const SizedBox(height: 10),
      Row(children: [
        {'c': const Color(0xFFEF4444), 'l': 'Awful'},
        {'c': const Color(0xFFF97316), 'l': 'Bad'},
        {'c': const Color(0xFFFFD93D), 'l': 'Okay'},
        {'c': const Color(0xFF52B788), 'l': 'Good'},
        {'c': const Color(0xFF06D6A0), 'l': 'Amazing'},
      ].map((item) => Expanded(child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6,
              decoration: BoxDecoration(
                  color: item['c'] as Color,
                  shape: BoxShape.circle)),
          const SizedBox(width: 2),
          Flexible(child: Text(item['l'] as String,
              style: TextStyle(fontSize: 8, color: _txtSub),
              overflow: TextOverflow.ellipsis)),
        ],
      ))).toList()),
    ]));
  }

  Widget _calNavBtn(String label, {bool disabled = false}) {
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: disabled
            ? (_isDark
                ? Colors.white.withOpacity(0.03)
                : const Color(0xFFF0F0F0))
            : (_isDark
                ? const Color(0xFF52B788).withOpacity(0.1)
                : const Color(0xFFE8F5EE)),
        borderRadius: BorderRadius.circular(8),
        border: _isDark ? Border.all(
            color: const Color(0xFF52B788).withOpacity(
                disabled ? 0.05 : 0.2),
            width: 0.5) : null),
      child: Center(child: Text(label, style: TextStyle(
          color: disabled
              ? _txtSub.withOpacity(0.3)
              : const Color(0xFF2D6A4F),
          fontWeight: FontWeight.w700, fontSize: 14))),
    );
  }

  Widget _buildCalGrid() {
    final now         = DateTime.now();
    final firstDay    = DateTime(_calMonth.year, _calMonth.month, 1);
    final startWD     = firstDay.weekday % 7;
    final daysInMonth = DateTime(
        _calMonth.year, _calMonth.month + 1, 0).day;
    final cells = <Widget>[];

    for (int i = 0; i < startWD; i++) cells.add(const SizedBox());

    for (int d = 1; d <= daysInMonth; d++) {
      final isToday = d == now.day &&
          _calMonth.month == now.month &&
          _calMonth.year  == now.year;
      final mood = _calMoods[d] ?? 0;
      cells.add(Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isToday
              ? const Color(0xFF2D6A4F)
              : (mood > 0
                  ? (_isDark
                      ? Colors.white.withOpacity(0.04)
                      : const Color(0xFFF0F7F2))
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(8)),
        child: Stack(alignment: Alignment.center, children: [
          Text('$d', style: TextStyle(fontSize: 11,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? Colors.white
                  : (_isDark
                      ? Colors.white.withOpacity(0.5)
                      : const Color(0xFF4A7C59)))),
          if (mood > 0 && !isToday)
            Positioned(bottom: 2, child: Container(
              width: 4, height: 4,
              decoration: BoxDecoration(
                  color: _moodColors[mood],
                  shape: BoxShape.circle))),
        ]),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }

  // ── MOOD CARD ──
  Widget _buildMoodCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDark
              ? [const Color(0xFF1A4A2E), const Color(0xFF0F2E1A)]
              : [const Color(0xFF52B788), const Color(0xFF2D6A4F)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: _isDark ? Border.all(
            color: const Color(0xFF52B788).withOpacity(0.25),
            width: 0.5) : null,
        boxShadow: [BoxShadow(
          color: const Color(0xFF52B788).withOpacity(
              _isDark ? 0.1 : 0.22),
          blurRadius: 20, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('How are you feeling?', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: Colors.white)),
            Text('Log your mood for today', style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.6))),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _isDark
                  ? const Color(0xFF52B788).withOpacity(0.15)
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: _isDark ? Border.all(
                  color: const Color(0xFF52B788).withOpacity(0.3),
                  width: 0.5) : null),
            child: Text('Today', style: TextStyle(fontSize: 10,
                color: _isDark
                    ? const Color(0xFF52B788) : Colors.white,
                fontWeight: FontWeight.w500)),
          ),
        ]),
        const SizedBox(height: 14),

        _moodLogged
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.check_circle,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Mood logged today! ${_selectedMood >= 0 ? _moods[_selectedMood]['emoji'] : '✓'}',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                ]))
            : Column(children: [
                Row(children: List.generate(_moods.length,
                    (i) => Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedMood = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedMood == i
                            ? Colors.white.withOpacity(0.25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: _selectedMood == i
                            ? Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 0.5)
                            : null),
                      child: Column(children: [
                        Text(_moods[i]['emoji'] as String,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 3),
                        Text(_moods[i]['label'] as String,
                            style: TextStyle(fontSize: 9,
                                color: _selectedMood == i
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.6),
                                fontWeight: _selectedMood == i
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                      ]),
                    ),
                  ),
                ))),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteCtrl,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '✏️  Add a note... (optional)',
                    hintStyle: TextStyle(fontSize: 12,
                        color: Colors.white.withOpacity(0.45)),
                    filled: true,
                    fillColor: _isDark
                        ? Colors.black.withOpacity(0.2)
                        : Colors.white.withOpacity(0.15),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _logging ? null : _logMood,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDark
                          ? const Color(0xFF2D6A4F) : Colors.white,
                      foregroundColor: _isDark
                          ? Colors.white : const Color(0xFF2D6A4F),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0),
                    child: _logging
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF2D6A4F)))
                        : const Text('✓  Log Mood',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
      ]),
    );
  }

  // ── STREAKS ──
  Widget _buildStreaks() {
    return Row(children: [
      _streakCard('$_streak 🔥', 'Day streak',
          [const Color(0xFF7F1D1D), const Color(0xFF991B1B)]),
      const SizedBox(width: 8),
      _streakCard('$_totalLogs', 'Total logs',
          [const Color(0xFF134E4A), const Color(0xFF0F766E)]),
      const SizedBox(width: 8),
      _streakCard('$_totalJournals', 'Journals',
          [const Color(0xFF2E1065), const Color(0xFF4C1D95)]),
    ]);
  }

  Widget _streakCard(String num, String label, List<Color> colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft,
              end: Alignment.bottomRight, colors: colors),
          borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(num, style: const TextStyle(fontSize: 20,
              fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 9,
              color: Colors.white.withOpacity(0.8))),
        ]),
      ),
    );
  }

  // ── CHART ──
  Widget _buildChart() {
    final moodColors = [
      const Color(0xFFEF4444), const Color(0xFFF97316),
      const Color(0xFFFFD93D), const Color(0xFF52B788),
      const Color(0xFF06D6A0),
    ];
    return _card(child: Column(children: [
      Row(children: [
        Text('Mood this week', style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w700, color: _txtMain)),
        const Spacer(),
        const Text('This week ›', style: TextStyle(
            fontSize: 10, color: Color(0xFF52B788),
            fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(height: 12),
      SizedBox(height: 70,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_weekMoods.length, (i) {
            final m = _weekMoods[i];
            return Expanded(child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: m == 0 ? 0.05 : m / 5,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 3),
                      decoration: BoxDecoration(
                        color: m == 0
                            ? (_isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.06))
                            : moodColors[m-1].withOpacity(
                                i == 6 ? 1.0 : 0.55),
                        borderRadius: BorderRadius.circular(5)),
                    ),
                  ),
                )),
                const SizedBox(height: 4),
                Text(_weekDays[i],
                    style: TextStyle(fontSize: 9, color: _txtSub)),
              ],
            ));
          }),
        ),
      ),
    ]));
  }

  // ── JOURNAL ──
  Widget _buildJournal() {
    return _card(child: Column(children: [
      Row(children: [
        Text('Recent Journal', style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w700, color: _txtMain)),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(
                builder: (_) => const JournalScreen()));
            _loadAllData();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _isDark
                  ? const Color(0xFF52B788).withOpacity(0.12)
                  : const Color(0xFFE8F5EE),
              borderRadius: BorderRadius.circular(20),
              border: _isDark ? Border.all(
                  color: const Color(0xFF52B788).withOpacity(0.25),
                  width: 0.5) : null),
            child: const Text('+ New', style: TextStyle(
                fontSize: 11, color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
      const SizedBox(height: 10),

      _recentJournals.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(children: [
                Icon(Icons.book_outlined, size: 36,
                    color: _txtSub.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text('No journal entries yet.',
                    style: TextStyle(fontSize: 12, color: _txtSub)),
                const SizedBox(height: 4),
                Text('Tap "+ New" to write your first entry.',
                    style: TextStyle(fontSize: 11,
                        color: _txtSub.withOpacity(0.6))),
              ]))
          : Column(
              children: _recentJournals.take(2).map((j) {
                final emoji   = j['moodEmoji'] as String? ?? '📝';
                final date    = j['date']      as String? ?? '';
                final label   = j['moodLabel'] as String? ?? '';
                final content = j['content']   as String? ?? '';
                final dateLabel = date.isNotEmpty
                    ? _formatDate(date) +
                        (label.isNotEmpty ? ' · $label' : '')
                    : '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const JournalScreen()));
                      _loadAllData();
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _isDark
                                ? Colors.white.withOpacity(0.06)
                                : const Color(0xFFF0F7F2),
                            borderRadius: BorderRadius.circular(10)),
                          child: Center(child: Text(emoji,
                              style: const TextStyle(fontSize: 18))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (dateLabel.isNotEmpty)
                              Text(dateLabel, style: TextStyle(
                                  fontSize: 9,
                                  color: _isDark
                                      ? const Color(0xFF52B788)
                                          .withOpacity(0.6)
                                      : const Color(0xFF52B788),
                                  fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(content, style: TextStyle(
                                fontSize: 11.5,
                                color: _isDark
                                    ? Colors.white.withOpacity(0.4)
                                    : const Color(0xFF4A7C59),
                                height: 1.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    ]));
  }

  // ── BOTTOM NAV ──
  Widget _buildBottomNav() {
    final items = [
      ['Home',     Icons.home_rounded],
      ['Insights', Icons.bar_chart_rounded],
      ['Journal',  Icons.book_rounded],
      ['History',  Icons.calendar_month_rounded],
      ['Profile',  Icons.person_rounded],
    ];

    return Container(
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF080F09) : Colors.white,
        border: Border(top: BorderSide(color: _border, width: 0.5))),
      child: SafeArea(top: false,
        child: SizedBox(height: 56,
          child: Row(children: items.asMap().entries.map((e) {
            final i      = e.key;
            final item   = e.value;
            final active = _selectedNav == i;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedNav = i);
                  if (i == 1) {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const InsightsScreen()));
                  } else if (i == 2) {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const JournalScreen()))
                        .then((_) => _loadAllData());
                  } else if (i == 3) {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const HistoryScreen()));
                  } else if (i == 4) {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const ProfileScreen()))
                        .then((_) => _loadAllData());
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item[1] as IconData, size: 22,
                        color: active
                            ? const Color(0xFF2D6A4F)
                            : (_isDark
                                ? Colors.white.withOpacity(0.2)
                                : const Color(0xFFC8E6D4))),
                    const SizedBox(height: 2),
                    Text(item[0] as String, style: TextStyle(
                        fontSize: 9,
                        fontWeight: active
                            ? FontWeight.w600 : FontWeight.normal,
                        color: active
                            ? const Color(0xFF2D6A4F)
                            : (_isDark
                                ? Colors.white.withOpacity(0.2)
                                : const Color(0xFF95B8A2)))),
                  ],
                ),
              ),
            );
          }).toList()),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border, width: 0.5),
        boxShadow: _isDark ? null : [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10, offset: const Offset(0, 2))]),
      child: child,
    );
  }

  String _monthName(int m) {
    const names = ['','January','February','March','April','May',
        'June','July','August','September','October',
        'November','December'];
    return names[m];
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = ['','Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[d.month]} ${d.day}';
    } catch (_) { return dateStr; }
  }
}