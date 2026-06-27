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

  final _moodColors = [
    Colors.transparent,
    const Color(0xFFEF4444),
    const Color(0xFFF97316),
    const Color(0xFFFFD93D),
    const Color(0xFF52B788),
    const Color(0xFF06D6A0),
  ];

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
      ? const Color(0xFF52B788).withOpacity(0.12)
      : const Color(0xFFE2EEE7);

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
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBar,
        title: const Text('Mood History',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
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
                  ],
                ))
              : RefreshIndicator(
                  color: const Color(0xFF52B788),
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) {
                      final e    = _entries[i];
                      final mood = (e['mood'] as int?) ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border, width: 0.5),
                          boxShadow: _isDark ? null : [BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2))],
                        ),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: mood > 0
                                  ? _moodColors[mood].withOpacity(0.15)
                                  : (_isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : const Color(0xFFF0FDF4)),
                              borderRadius: BorderRadius.circular(12),
                              border: mood > 0 ? Border.all(
                                  color: _moodColors[mood].withOpacity(0.3),
                                  width: 0.5) : null),
                            child: Center(child: Text(
                                e['emoji'] ?? '😊',
                                style: const TextStyle(fontSize: 22))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(e['moodLabel'] ?? '',
                                    style: TextStyle(fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: mood > 0
                                            ? _moodColors[mood]
                                            : _txtMain)),
                                const Spacer(),
                                Text(_formatDate(e['date'] ?? ''),
                                    style: TextStyle(fontSize: 10,
                                        color: _txtSub)),
                              ]),
                              if ((e['note'] as String?)?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(e['note'],
                                      style: TextStyle(fontSize: 12,
                                          color: _txtSub, height: 1.4),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ),
                            ],
                          )),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}