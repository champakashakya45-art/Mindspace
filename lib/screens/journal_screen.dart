import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart' show themeNotifier;

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;
  bool _loading = true;
  late bool _isDark;
  List<Map<String, dynamic>> _journals = [];

  @override
  void initState() {
    super.initState();
    _isDark = themeNotifier.value;
    themeNotifier.addListener(_onThemeChange);
    _loadJournals();
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

  Future<void> _loadJournals() async {
    setState(() => _loading = true);
    try {
      final uid  = _auth.currentUser?.uid;
      final snap = await _db
          .collection('users').doc(uid)
          .collection('journals')
          .orderBy('timestamp', descending: true)
          .get();
      setState(() {
        _journals = snap.docs.map((doc) {
          final d = doc.data();
          return {
            'id':        doc.id,
            'title':     d['title']     ?? 'Untitled',
            'content':   d['content']   ?? '',
            'moodEmoji': d['moodEmoji'] ?? '📝',
            'moodLabel': d['moodLabel'] ?? '',
            'date':      d['date']      ?? '',
          };
        }).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteJournal(String id) async {
    try {
      final uid = _auth.currentUser?.uid;
      await _db.collection('users').doc(uid)
          .collection('journals').doc(id).delete();
      _loadJournals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Journal entry deleted.'),
          backgroundColor: Color(0xFF2D6A4F)));
      }
    } catch (_) {}
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = ['','Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[d.month]} ${d.day}, ${d.year}';
    } catch (_) { return dateStr; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBar,
        title: const Text('Journal',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF52B788)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => WriteJournalScreen(isDark: _isDark)));
              _loadJournals();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFF52B788)))
          : _journals.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.book_outlined, size: 64,
                        color: _txtSub.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text('No journal entries yet.',
                        style: TextStyle(fontSize: 16, color: _txtSub)),
                    const SizedBox(height: 8),
                    Text('Tap + to write your first entry.',
                        style: TextStyle(fontSize: 13,
                            color: _txtSub.withOpacity(0.6))),
                  ],
                ))
              : RefreshIndicator(
                  color: const Color(0xFF52B788),
                  onRefresh: _loadJournals,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _journals.length,
                    itemBuilder: (_, i) {
                      final j = _journals[i];
                      return Dismissible(
                        key: Key(j['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.delete_outline,
                              color: Color(0xFFEF4444)),
                        ),
                        onDismissed: (_) => _deleteJournal(j['id']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border, width: 0.5),
                            boxShadow: _isDark ? null : [BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: _isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(12)),
                                child: Center(child: Text(
                                    j['moodEmoji'] ?? '📝',
                                    style: const TextStyle(fontSize: 20))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(child: Text(j['title'],
                                        style: TextStyle(fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _txtMain))),
                                    if ((j['moodLabel'] as String).isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF52B788)
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                        child: Text(j['moodLabel'],
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: Color(0xFF52B788))),
                                      ),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(j['content'],
                                      style: TextStyle(fontSize: 12,
                                          color: _txtSub, height: 1.5),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 6),
                                  Text(_formatDate(j['date']),
                                      style: TextStyle(fontSize: 9,
                                          color: const Color(0xFF52B788)
                                              .withOpacity(0.5))),
                                ],
                              )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2D6A4F),
        child: const Icon(Icons.edit, color: Colors.white),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => WriteJournalScreen(isDark: _isDark)));
          _loadJournals();
        },
      ),
    );
  }
}

// ── Write Journal Screen ──
class WriteJournalScreen extends StatefulWidget {
  final bool isDark;
  const WriteJournalScreen({super.key, required this.isDark});
  @override
  State<WriteJournalScreen> createState() => _WriteJournalScreenState();
}

class _WriteJournalScreenState extends State<WriteJournalScreen> {
  final _titleCtrl   = TextEditingController();
  final _contentCtrl = TextEditingController();
  int _selectedMood  = -1;
  bool _saving       = false;

  final _moods = [
    {'emoji': '😢', 'label': 'Awful',   'val': 1},
    {'emoji': '😕', 'label': 'Bad',     'val': 2},
    {'emoji': '😊', 'label': 'Okay',    'val': 3},
    {'emoji': '😄', 'label': 'Good',    'val': 4},
    {'emoji': '🤩', 'label': 'Amazing', 'val': 5},
  ];

  Color get _bg     => widget.isDark ? const Color(0xFF050A06) : const Color(0xFFF7FBF8);
  Color get _cardBg => widget.isDark ? const Color(0xFF0D1F14) : Colors.white;
  Color get _appBar => widget.isDark ? const Color(0xFF0F2E1A) : const Color(0xFF2D6A4F);
  Color get _border => widget.isDark
      ? const Color(0xFF52B788).withOpacity(0.15)
      : const Color(0xFFE2EEE7);
  Color get _txtSub => widget.isDark
      ? Colors.white.withOpacity(0.2)
      : Colors.black.withOpacity(0.3);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something first.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final uid  = FirebaseAuth.instance.currentUser?.uid;
      final mood = _selectedMood >= 0 ? _moods[_selectedMood] : null;
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('journals').add({
        'title':     _titleCtrl.text.trim().isEmpty
            ? 'Journal Entry' : _titleCtrl.text.trim(),
        'content':   _contentCtrl.text.trim(),
        'mood':      mood?['val'] ?? 0,
        'moodEmoji': mood?['emoji'] ?? '📝',
        'moodLabel': mood?['label'] ?? '',
        'date':      DateTime.now().toIso8601String().substring(0, 10),
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBar,
        title: const Text('New Entry',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Color(0xFF52B788), strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(color: Color(0xFF52B788),
                        fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('How are you feeling?',
              style: TextStyle(fontSize: 12,
                  color: Color(0xFF52B788),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: List.generate(_moods.length, (i) => Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMood = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _selectedMood == i
                      ? const Color(0xFF2D6A4F)
                      : _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedMood == i
                        ? const Color(0xFF52B788)
                        : _border,
                    width: 0.5)),
                child: Column(children: [
                  Text(_moods[i]['emoji'] as String,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 2),
                  Text(_moods[i]['label'] as String,
                      style: TextStyle(fontSize: 9,
                          color: _selectedMood == i
                              ? Colors.white : _txtSub)),
                ]),
              ),
            ),
          ))),
          const SizedBox(height: 20),

          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border, width: 0.5)),
            child: TextField(
              controller: _titleCtrl,
              style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark
                      ? const Color(0xFFE8F5EE)
                      : const Color(0xFF1B3A2D)),
              decoration: InputDecoration(
                hintText: 'Title (optional)',
                hintStyle: TextStyle(fontSize: 16,
                    color: _txtSub,
                    fontWeight: FontWeight.w600),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16)),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border, width: 0.5)),
            child: TextField(
              controller: _contentCtrl,
              style: TextStyle(fontSize: 14,
                  color: widget.isDark
                      ? Colors.white.withOpacity(0.85)
                      : const Color(0xFF1B3A2D),
                  height: 1.7),
              maxLines: 15,
              decoration: InputDecoration(
                hintText: 'Write your thoughts here...',
                hintStyle: TextStyle(fontSize: 14, color: _txtSub),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16)),
            ),
          ),
          const SizedBox(height: 60),
        ]),
      ),
    );
  }
}