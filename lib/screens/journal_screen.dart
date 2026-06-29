import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
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
  bool _exporting = false;
  late bool _isDark;
  List<Map<String, dynamic>> _journals = [];
  List<Map<String, dynamic>> _filtered = [];
  String _searchQuery        = '';
  String _selectedMoodFilter = 'All';
  final _searchCtrl = TextEditingController();

  final _moodFilters = ['All','Awful','Bad','Okay','Good','Amazing'];
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
    _loadJournals();
  }

  void _onThemeChange() {
    if (mounted) setState(() => _isDark = themeNotifier.value);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    _searchCtrl.dispose();
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
      final list = snap.docs.map((doc) {
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
      setState(() {
        _journals = list;
        _applyFilter();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    var list = _journals;
    if (_selectedMoodFilter != 'All') {
      list = list.where((j) =>
          j['moodLabel'] == _selectedMoodFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((j) =>
          (j['title'] as String).toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (j['content'] as String).toLowerCase()
              .contains(_searchQuery.toLowerCase())).toList();
    }
    _filtered = list;
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

  int _wordCount(String text) =>
      text.trim().isEmpty ? 0
          : text.trim().split(RegExp(r'\s+')).length;

  String _readTime(String text) {
    final words = _wordCount(text);
    final mins  = (words / 200).ceil();
    return mins <= 1 ? '1 min read' : '$mins min read';
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

  // ── PDF EXPORT ──
  Future<void> _exportPDF() async {
    if (_journals.isEmpty) return;
    setState(() => _exporting = true);

    try {
      final pdf  = pw.Document();
      final user = FirebaseAuth.instance.currentUser;
      final name = user?.displayName
          ?? user?.email?.split('@').first ?? 'User';
      final now  = DateTime.now();
      const months = ['','Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
      const fullMonths = ['','January','February','March','April',
          'May','June','July','August','September',
          'October','November','December'];
      final dateStr = '${months[now.month]} ${now.day}, ${now.year}';

      final totalWords = _journals.fold(0,
          (s, j) => s + _wordCount(j['content'] as String));
      final thisMonth  = _journals.where((j) {
        try {
          final d = DateTime.parse(j['date']);
          return d.month == now.month && d.year == now.year;
        } catch (_) { return false; }
      }).length;

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 16),
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFF2D6A4F),
            borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
            pw.Text('MindSpace Journal',
                style: pw.TextStyle(fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text('Page ${ctx.pageNumber}',
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.white)),
          ])),
        footer: (_) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            'Generated by MindSpace · $dateStr',
            style: const pw.TextStyle(
                fontSize: 9, color: PdfColors.grey),
            textAlign: pw.TextAlign.center)),
        build: (pw.Context ctx) => [

          // Title section
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFF2D6A4F),
              borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
              pw.Text('My Journal Report',
                  style: pw.TextStyle(fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              pw.SizedBox(height: 6),
              pw.Text('$name  ·  $dateStr',
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.white)),
            ])),

          pw.SizedBox(height: 20),

          // Stats
          pw.Row(children: [
            _pdfStatBox('Total Entries',
                '${_journals.length}'),
            pw.SizedBox(width: 10),
            _pdfStatBox('This Month', '$thisMonth'),
            pw.SizedBox(width: 10),
            _pdfStatBox('Total Words', '$totalWords'),
          ]),

          pw.SizedBox(height: 24),

          pw.Text('Journal Entries',
              style: pw.TextStyle(fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF1B3A2D))),

          pw.SizedBox(height: 12),

          // Entries
          ..._journals.map((j) {
            String dateLabel = '';
            try {
              final d = DateTime.parse(j['date']);
              dateLabel =
                  '${fullMonths[d.month]} ${d.day}, ${d.year}';
            } catch (_) { dateLabel = j['date']; }

            final wc = _wordCount(j['content'] as String);

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 14),
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                    color: const PdfColor.fromInt(0xFFE2EEE7),
                    width: 0.5),
                borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                // Title row
                pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                  pw.Text(j['title'] ?? 'Untitled',
                      style: pw.TextStyle(fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(
                              0xFF1B3A2D))),
                  pw.Text(dateLabel,
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey)),
                ]),

                if ((j['moodLabel'] as String).isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFE8F5EE),
                      borderRadius: pw.BorderRadius.circular(20)),
                    child: pw.Text(
                        'Feeling: ${j['moodLabel']}',
                        style: pw.TextStyle(fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(
                                0xFF2D6A4F)))),
                ],

                pw.SizedBox(height: 8),

                pw.Text(j['content'] ?? '',
                    style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.black),
                    maxLines: 50),

                pw.SizedBox(height: 6),

                pw.Text('$wc words',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey)),
              ]));
          }),
        ],
      ));

      // Save file
      final dir  = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/MindSpace_Journal_${now.year}${now.month}${now.day}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Share
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'My MindSpace Journal Report 🌿',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journal exported as PDF! ✓'),
            backgroundColor: Color(0xFF2D6A4F)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  pw.Widget _pdfStatBox(String label, String value) {
    return pw.Expanded(child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFE8F5EE),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
            color: const PdfColor.fromInt(0xFFB7D5C4))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF2D6A4F))),
        pw.SizedBox(height: 2),
        pw.Text(label, style: const pw.TextStyle(
            fontSize: 9, color: PdfColors.grey)),
      ])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBar,
        title: const Text('Journal', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // PDF Export button
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Color(0xFF52B788),
                          strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded,
                      color: Color(0xFF52B788)),
                  tooltip: 'Export PDF',
                  onPressed: _journals.isEmpty ? null : _exportPDF),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF52B788)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) =>
                      WriteJournalScreen(isDark: _isDark)));
              _loadJournals();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFF52B788)))
          : Column(children: [

              // ── SEARCH BAR ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border, width: 0.5)),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() {
                      _searchQuery = v;
                      _applyFilter();
                    }),
                    style: TextStyle(fontSize: 13, color: _txtMain),
                    decoration: InputDecoration(
                      hintText: '🔍  Search journals...',
                      hintStyle: TextStyle(
                          fontSize: 13, color: _txtSub),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  size: 16, color: _txtSub),
                              onPressed: () => setState(() {
                                _searchCtrl.clear();
                                _searchQuery = '';
                                _applyFilter();
                              }))
                          : null),
                  ),
                ),
              ),

              // ── MOOD FILTER ──
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  itemCount: _moodFilters.length,
                  itemBuilder: (_, i) {
                    final f      = _moodFilters[i];
                    final color  = _filterColors[f]!;
                    final emoji  = _filterEmojis[f]!;
                    final active = _selectedMoodFilter == f;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedMoodFilter = f;
                        _applyFilter();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: active
                              ? color.withOpacity(
                                  _isDark ? 0.25 : 0.15)
                              : (_isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active ? color : _border,
                            width: active ? 1.5 : 0.5)),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          Text(emoji,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(f, style: TextStyle(fontSize: 11,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: active ? color : _txtSub)),
                        ]),
                      ),
                    );
                  },
                ),
              ),

              // ── STATS ROW ──
              if (_journals.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(children: [
                    _miniStat('${_journals.length}', 'Total'),
                    const SizedBox(width: 8),
                    _miniStat('${_filtered.length}', 'Showing'),
                    const SizedBox(width: 8),
                    _miniStat(
                      '${_journals.fold(0, (s, j) => s + _wordCount(j['content'] as String))}',
                      'Words'),
                  ]),
                ),

              const SizedBox(height: 8),

              // ── JOURNAL LIST ──
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_searchQuery.isNotEmpty ||
                              _selectedMoodFilter != 'All'
                              ? '🔍' : '📖',
                              style: const TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(_searchQuery.isNotEmpty
                              ? 'No results for "$_searchQuery"'
                              : _selectedMoodFilter != 'All'
                                  ? 'No $_selectedMoodFilter entries yet.'
                                  : 'No journal entries yet.',
                              style: TextStyle(
                                  fontSize: 14, color: _txtSub)),
                          if (_searchQuery.isEmpty &&
                              _selectedMoodFilter == 'All') ...[
                            const SizedBox(height: 8),
                            Text('Tap + to write your first entry.',
                                style: TextStyle(fontSize: 12,
                                    color: _txtSub.withOpacity(0.6))),
                          ],
                        ]))
                    : RefreshIndicator(
                        color: const Color(0xFF52B788),
                        onRefresh: _loadJournals,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              12, 0, 12, 80),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final j     = _filtered[i];
                            final words = _wordCount(
                                j['content'] as String);
                            final readT = _readTime(
                                j['content'] as String);
                            return Dismissible(
                              key: Key(j['id']),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(
                                    right: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444)
                                      .withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(16)),
                                child: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFEF4444))),
                              onDismissed: (_) =>
                                  _deleteJournal(j['id']),
                              child: GestureDetector(
                                onTap: () async {
                                  await Navigator.push(context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              ViewJournalScreen(
                                                  journal: j,
                                                  isDark: _isDark)));
                                  _loadJournals();
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(
                                      bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _cardBg,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    border: Border.all(
                                        color: _border, width: 0.5),
                                    boxShadow: _isDark ? null
                                        : [BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.04),
                                            blurRadius: 8,
                                            offset: const Offset(
                                                0, 2))]),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: _isDark
                                              ? Colors.white
                                                  .withOpacity(0.06)
                                              : const Color(
                                                  0xFFF0FDF4),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12)),
                                        child: Center(child: Text(
                                            j['moodEmoji'] ?? '📝',
                                            style: const TextStyle(
                                                fontSize: 22)))),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Expanded(child: Text(
                                                j['title'],
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: _txtMain))),
                                            if ((j['moodLabel']
                                                    as String)
                                                .isNotEmpty)
                                              Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                      0xFF52B788)
                                                      .withOpacity(
                                                          0.12),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                              20)),
                                                child: Text(
                                                    j['moodLabel'],
                                                    style: const TextStyle(
                                                        fontSize: 9,
                                                        color: Color(
                                                            0xFF52B788)))),
                                          ]),
                                          const SizedBox(height: 4),
                                          Text(j['content'],
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: _txtSub,
                                                  height: 1.5),
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis),
                                          const SizedBox(height: 6),
                                          Row(children: [
                                            Text(_formatDate(
                                                j['date']),
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    color: const Color(
                                                        0xFF52B788)
                                                        .withOpacity(
                                                            0.6))),
                                            const Spacer(),
                                            Text('$words words',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    color: _txtSub
                                                        .withOpacity(
                                                            0.6))),
                                            const SizedBox(width: 6),
                                            Text('·',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    color: _txtSub
                                                        .withOpacity(
                                                            0.4))),
                                            const SizedBox(width: 6),
                                            Text(readT,
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    color: _txtSub
                                                        .withOpacity(
                                                            0.6))),
                                          ]),
                                        ])),
                                    ]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ]),
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

  Widget _miniStat(String val, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border, width: 0.5)),
        child: Column(children: [
          Text(val, style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w800, color: _txtMain)),
          Text(label, style: TextStyle(
              fontSize: 9, color: _txtSub)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// VIEW JOURNAL SCREEN
// ══════════════════════════════════════════
class ViewJournalScreen extends StatelessWidget {
  final Map<String, dynamic> journal;
  final bool isDark;
  const ViewJournalScreen({
      super.key, required this.journal, required this.isDark});

  Color get _bg     => isDark
      ? const Color(0xFF050A06) : const Color(0xFFF7FBF8);
  Color get _cardBg => isDark
      ? const Color(0xFF0D1F14) : Colors.white;
  Color get _appBar => isDark
      ? const Color(0xFF0F2E1A) : const Color(0xFF2D6A4F);
  Color get _txtMain=> isDark
      ? const Color(0xFFE8F5EE) : const Color(0xFF1B3A2D);
  Color get _txtSub => isDark
      ? Colors.white.withOpacity(0.4) : const Color(0xFF6B8F7A);
  Color get _border => isDark
      ? const Color(0xFF52B788).withOpacity(0.15)
      : const Color(0xFFE2EEE7);

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = ['','January','February','March','April','May',
          'June','July','August','September','October',
          'November','December'];
      const weekdays = ['','Monday','Tuesday','Wednesday',
          'Thursday','Friday','Saturday','Sunday'];
      return '${weekdays[d.weekday]}, ${months[d.month]} ${d.day}, ${d.year}';
    } catch (_) { return dateStr; }
  }

  int _wordCount(String text) =>
      text.trim().isEmpty ? 0
          : text.trim().split(RegExp(r'\s+')).length;

  @override
  Widget build(BuildContext context) {
    final words = _wordCount(journal['content'] as String);
    final mins  = (words / 200).ceil();
    final readT = mins <= 1 ? '1 min read' : '$mins min read';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBar,
        title: Text(journal['title'] ?? 'Journal Entry',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [

          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border, width: 0.5)),
            child: Row(children: [
              Text(journal['moodEmoji'] ?? '📝',
                  style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(_formatDate(journal['date'] ?? ''),
                    style: TextStyle(fontSize: 12,
                        color: const Color(0xFF52B788),
                        fontWeight: FontWeight.w500)),
                if ((journal['moodLabel'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF52B788)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          'Feeling ${journal['moodLabel']}',
                          style: const TextStyle(fontSize: 11,
                              color: Color(0xFF52B788),
                              fontWeight: FontWeight.w500)))),
                const SizedBox(height: 4),
                Row(children: [
                  Text('$words words',
                      style: TextStyle(
                          fontSize: 10, color: _txtSub)),
                  const SizedBox(width: 6),
                  Text('·', style: TextStyle(fontSize: 10,
                      color: _txtSub.withOpacity(0.5))),
                  const SizedBox(width: 6),
                  Text(readT, style: TextStyle(
                      fontSize: 10, color: _txtSub)),
                ]),
              ])),
            ]),
          ),
          const SizedBox(height: 16),

          // Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border, width: 0.5)),
            child: Text(journal['content'] ?? '',
                style: TextStyle(fontSize: 15,
                    color: _txtMain, height: 1.8)),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// WRITE JOURNAL SCREEN
// ══════════════════════════════════════════
class WriteJournalScreen extends StatefulWidget {
  final bool isDark;
  const WriteJournalScreen({super.key, required this.isDark});
  @override
  State<WriteJournalScreen> createState() => _WriteJournalScreenState();
}

class _WriteJournalScreenState extends State<WriteJournalScreen> {
  final _titleCtrl   = TextEditingController();
  final _contentCtrl = TextEditingController();
  int  _selectedMood = -1;
  bool _saving       = false;
  int  _wordCount    = 0;

  final _moods = [
    {'emoji': '😢', 'label': 'Awful',   'val': 1},
    {'emoji': '😕', 'label': 'Bad',     'val': 2},
    {'emoji': '😊', 'label': 'Okay',    'val': 3},
    {'emoji': '😄', 'label': 'Good',    'val': 4},
    {'emoji': '🤩', 'label': 'Amazing', 'val': 5},
  ];

  Color get _bg     => widget.isDark
      ? const Color(0xFF050A06) : const Color(0xFFF7FBF8);
  Color get _cardBg => widget.isDark
      ? const Color(0xFF0D1F14) : Colors.white;
  Color get _appBar => widget.isDark
      ? const Color(0xFF0F2E1A) : const Color(0xFF2D6A4F);
  Color get _border => widget.isDark
      ? const Color(0xFF52B788).withOpacity(0.15)
      : const Color(0xFFE2EEE7);
  Color get _txtSub => widget.isDark
      ? Colors.white.withOpacity(0.2)
      : Colors.black.withOpacity(0.3);
  Color get _txtMain => widget.isDark
      ? const Color(0xFFE8F5EE) : const Color(0xFF1B3A2D);

  @override
  void initState() {
    super.initState();
    _contentCtrl.addListener(() {
      final text  = _contentCtrl.text.trim();
      final count = text.isEmpty ? 0
          : text.split(RegExp(r'\s+')).length;
      setState(() => _wordCount = count);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please write something first.')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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
        title: const Text('New Entry', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Center(child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('$_wordCount words',
                style: TextStyle(fontSize: 11,
                    color: Colors.white.withOpacity(0.6))),
          )),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Color(0xFF52B788), strokeWidth: 2))
                : const Text('Save', style: TextStyle(
                    color: Color(0xFF52B788),
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [

          // Mood selector
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border, width: 0.5)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('How are you feeling?',
                  style: TextStyle(fontSize: 11,
                      color: const Color(0xFF52B788),
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(children: List.generate(_moods.length,
                  (i) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMood = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _selectedMood == i
                          ? const Color(0xFF2D6A4F)
                          : Colors.transparent,
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
            ]),
          ),
          const SizedBox(height: 12),

          // Title
          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border, width: 0.5)),
            child: TextField(
              controller: _titleCtrl,
              style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w600, color: _txtMain),
              decoration: InputDecoration(
                hintText: 'Title (optional)',
                hintStyle: TextStyle(fontSize: 16,
                    color: _txtSub, fontWeight: FontWeight.w600),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16)),
            ),
          ),
          const SizedBox(height: 10),

          // Content
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
              maxLines: 18,
              decoration: InputDecoration(
                hintText: 'Write your thoughts here... ✍️',
                hintStyle: TextStyle(fontSize: 14, color: _txtSub),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16)),
            ),
          ),
          const SizedBox(height: 12),

          // Word count bar
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border, width: 0.5)),
            child: Row(children: [
              Icon(Icons.text_fields_rounded, size: 14,
                  color: const Color(0xFF52B788).withOpacity(0.7)),
              const SizedBox(width: 8),
              Text('$_wordCount words written',
                  style: TextStyle(fontSize: 12, color: _txtSub)),
              const Spacer(),
              Text(_wordCount >= 200
                  ? '✓ Great entry!'
                  : _wordCount >= 100
                      ? '👍 Good progress'
                      : _wordCount >= 50
                          ? '✍️ Keep writing...'
                          : '💭 Just start...',
                  style: TextStyle(fontSize: 11,
                      color: _wordCount >= 100
                          ? const Color(0xFF52B788)
                          : _txtSub)),
            ]),
          ),
          const SizedBox(height: 60),
        ]),
      ),
    );
  }
}