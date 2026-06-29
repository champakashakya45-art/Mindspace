import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart' show themeNotifier;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;
  bool _loading = true;
  late bool _isDark;
  List<Map<String, dynamic>> _entries = [];
  String _selectedFilter = 'All';

  final _filters = ['All','Awful','Bad','Okay','Good','Amazing'];
  final _moodColors = [
    Colors.transparent,
    const Color(0xFFEF4444),
    const Color(0xFFF97316),
    const Color(0xFFFFD93D),
    const Color(0xFF52B788),
    const Color(0xFF06D6A0),
  ];
  final _filterColors = {
    'All':     const Color(0xFF2D6A4F),
    'Awful':   const Color(0xFFEF4444),
    'Bad':     const Color(0xFFF97316),
    'Okay':    const Color(0xFFFFD93D),
    'Good':    const Color(0xFF52B788),
    'Amazing': const Color(0xFF06D6A0),
  };
  final _filterEmojis = {
    'All':'📋','Awful':'😢','Bad':'😕',
    'Okay':'😊','Good':'😄','Amazing':'🤩',
  };

  @override
  void initState() {
    super.initState();
    _isDark = themeNotifier.value;
    themeNotifier.addListener(_onThemeChange);
    _loadHistory();
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
      ? const Color(0xFF52B788).withOpacity(0.12) : const Color(0xFFE2EEE7);

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final uid  = _auth.currentUser?.uid;
      final snap = await _db
          .collection('users').doc(uid)
          .collection('moods')
          .orderBy('timestamp', descending: true)
          .get();
      setState(() {
        _entries = snap.docs.map((doc) {
          final d = doc.data();
          return {
            'id':        doc.id,
            'mood':      d['mood']      ?? 0,
            'moodLabel': d['moodLabel'] ?? '',
            'emoji':     d['emoji']     ?? '😊',
            'note':      d['note']      ?? '',
            'date':      d['date']      ?? '',
          };
        }).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteEntry(String id) async {
    try {
      final uid = _auth.currentUser?.uid;
      await _db.collection('users').doc(uid)
          .collection('moods').doc(id).delete();
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Entry deleted.'),
            backgroundColor: Color(0xFF2D6A4F)));
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedFilter == 'All') return _entries;
    return _entries.where((e) =>
        e['moodLabel'] == _selectedFilter).toList();
  }

  String get _mostCommonMood {
    if (_entries.isEmpty) return 'N/A';
    final counts = <String, int>{};
    for (final e in _entries) {
      final l = e['moodLabel'] as String;
      if (l.isNotEmpty) counts[l] = (counts[l] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'N/A';
    return counts.entries
        .reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double get _avgMood {
    if (_entries.isEmpty) return 0;
    final sum = _entries.fold<int>(0,
        (s, e) => s + ((e['mood'] as int?) ?? 0));
    return sum / _entries.length;
  }

  String _groupLabel(String dateStr) {
    try {
      final d   = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today     = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final thisWeek  = today.subtract(const Duration(days: 7));
      final date = DateTime(d.year, d.month, d.day);
      if (date == today)     return 'Today';
      if (date == yesterday) return 'Yesterday';
      if (date.isAfter(thisWeek)) return 'This Week';
      const months = ['','Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[d.month]} ${d.year}';
    } catch (_) { return 'Earlier'; }
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = ['','Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
      const weekdays = ['','Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${weekdays[d.weekday]}, ${months[d.month]} ${d.day}';
    } catch (_) { return dateStr; }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    // Group by date label
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in filtered) {
      final label = _groupLabel(e['date'] as String);
      grouped.putIfAbsent(label, () => []).add(e);
    }
    final groupOrder = ['Today','Yesterday','This Week'];
    final keys = [
      ...groupOrder.where((k) => grouped.containsKey(k)),
      ...grouped.keys.where((k) => !groupOrder.contains(k)),
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBar,
        title: const Text('Mood History', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: Text('${_entries.length} logs',
                style: TextStyle(fontSize: 12,
                    color: Colors.white.withOpacity(0.8)))),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFF52B788)))
          : _entries.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64,
                        color: _txtSub.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text('No mood history yet.',
                        style: TextStyle(fontSize: 16, color: _txtSub)),
                  ]))
              : RefreshIndicator(
                  color: const Color(0xFF52B788),
                  onRefresh: _loadHistory,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [

                      // ── STATS BAR ──
                      SliverToBoxAdapter(child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: Row(children: [
                          _statChip(
                            icon: Icons.bar_chart_rounded,
                            label: 'Total',
                            value: '${_entries.length}',
                            color: const Color(0xFF2D6A4F),
                          ),
                          const SizedBox(width: 8),
                          _statChip(
                            icon: Icons.star_rounded,
                            label: 'Most Common',
                            value: _mostCommonMood,
                            color: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          _statChip(
                            icon: Icons.mood_rounded,
                            label: 'Avg Mood',
                            value: _avgMood > 0
                                ? _avgMood.toStringAsFixed(1) : 'N/A',
                            color: const Color(0xFF3B82F6),
                          ),
                        ]),
                      )),

                      // ── FILTER CHIPS ──
                      SliverToBoxAdapter(child: SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          itemCount: _filters.length,
                          itemBuilder: (_, i) {
                            final f     = _filters[i];
                            final color = _filterColors[f]!;
                            final emoji = _filterEmojis[f]!;
                            final selected = _selectedFilter == f;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedFilter = f),
                              child: AnimatedContainer(
                                duration: const Duration(
                                    milliseconds: 200),
                                margin: const EdgeInsets.only(
                                    right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? color.withOpacity(
                                          _isDark ? 0.25 : 0.15)
                                      : (_isDark
                                          ? Colors.white.withOpacity(0.04)
                                          : Colors.white),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? color
                                        : _border,
                                    width: selected ? 1.5 : 0.5),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  Text(emoji,
                                      style: const TextStyle(
                                          fontSize: 13)),
                                  const SizedBox(width: 5),
                                  Text(f, style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: selected
                                          ? color : _txtSub)),
                                ]),
                              ),
                            );
                          },
                        ),
                      )),

                      const SliverToBoxAdapter(
                          child: SizedBox(height: 8)),

                      // ── GROUPED ENTRIES ──
                      if (filtered.isEmpty)
                        SliverToBoxAdapter(child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: Column(children: [
                              Text(_filterEmojis[_selectedFilter]!,
                                  style: const TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text('No $_selectedFilter entries yet.',
                                  style: TextStyle(fontSize: 14,
                                      color: _txtSub)),
                            ]),
                          ),
                        ))
                      else
                        SliverList(delegate: SliverChildBuilderDelegate(
                          (_, index) {
                            final key   = keys[index];
                            final items = grouped[key]!;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                // Group header
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      4, 8, 0, 6),
                                  child: Row(children: [
                                    Container(
                                      width: 3, height: 14,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF52B788),
                                        borderRadius:
                                            BorderRadius.circular(2)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(key, style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF52B788),
                                        letterSpacing: 0.05)),
                                    const SizedBox(width: 6),
                                    Text('(${items.length})',
                                        style: TextStyle(fontSize: 10,
                                            color: _txtSub)),
                                  ]),
                                ),

                                // Entries
                                ...items.map((e) {
                                  final mood = (e['mood'] as int?) ?? 0;
                                  final moodColor = mood > 0 &&
                                      mood <= 5
                                      ? _moodColors[mood]
                                      : Colors.grey;
                                  return Dismissible(
                                    key: Key(e['id']),
                                    direction:
                                        DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(
                                          right: 20),
                                      margin: const EdgeInsets.only(
                                          bottom: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444)
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                      child: const Icon(
                                          Icons.delete_outline,
                                          color: Color(0xFFEF4444))),
                                    onDismissed: (_) =>
                                        _deleteEntry(e['id']),
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 8),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: _cardBg,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                            color: _border, width: 0.5),
                                        boxShadow: _isDark ? null
                                            : [BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.04),
                                                blurRadius: 8,
                                                offset: const Offset(
                                                    0, 2))]),
                                      child: Row(children: [
                                        Container(
                                          width: 44, height: 44,
                                          decoration: BoxDecoration(
                                            color: mood > 0
                                                ? moodColor
                                                    .withOpacity(0.15)
                                                : (_isDark
                                                    ? Colors.white
                                                        .withOpacity(0.06)
                                                    : const Color(
                                                        0xFFF0FDF4)),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    12),
                                            border: mood > 0
                                                ? Border.all(
                                                    color: moodColor
                                                        .withOpacity(
                                                            0.3),
                                                    width: 0.5)
                                                : null),
                                          child: Center(child: Text(
                                              e['emoji'] ?? '😊',
                                              style: const TextStyle(
                                                  fontSize: 22)))),
                                        const SizedBox(width: 12),
                                        Expanded(child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                          Row(children: [
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 8,
                                                  vertical: 2),
                                              decoration: BoxDecoration(
                                                color: moodColor
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        20)),
                                              child: Text(
                                                  e['moodLabel'] ?? '',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: moodColor))),
                                            const Spacer(),
                                            Text(_formatDate(
                                                e['date'] ?? ''),
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: _txtSub)),
                                          ]),
                                          if ((e['note'] as String?)
                                              ?.isNotEmpty == true) ...[
                                            const SizedBox(height: 5),
                                            Text(e['note'],
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: _txtSub,
                                                    height: 1.4),
                                                maxLines: 2,
                                                overflow: TextOverflow
                                                    .ellipsis),
                                          ],
                                        ])),
                                      ]),
                                    ),
                                  );
                                }),
                              ]),
                            );
                          },
                          childCount: keys.length,
                        )),

                      const SliverToBoxAdapter(
                          child: SizedBox(height: 20)),
                    ],
                  ),
                ),
    );
  }

  Widget _statChip({
    required IconData icon, required String label,
    required String value, required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border, width: 0.5),
          boxShadow: _isDark ? null : [BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6, offset: const Offset(0, 2))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 9,
                color: _txtSub, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w800, color: _txtMain)),
        ]),
      ),
    );
  }
}