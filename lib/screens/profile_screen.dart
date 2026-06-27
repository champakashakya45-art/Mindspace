import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../main.dart' show themeNotifier, setTheme;
import '../services/notification_service.dart';
import 'intro_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  int  _totalLogs      = 0;
  int  _totalJournals  = 0;
  int  _streak         = 0;
  bool _loading        = true;
  bool _editing        = false;
  bool _saving         = false;
  bool _uploadingPhoto = false;
  late bool _isDark;

  bool _reminderEnabled = false;
  int  _reminderHour   = 20;
  int  _reminderMinute = 0;

  String? _photoUrl;
  String  _memberSince = 'Jun 2026';
  final _nameCtrl = TextEditingController();
  String _bdayDisplay = 'Tap to set';
  int _bdayDay = 1, _bdayMonth = 1, _bdayYear = 2000;
  Set<String> _shownAchievements = {};

  static const _cloudName    = 'dmkgeoqve';
  static const _uploadPreset = 'mindspace_upload';

  @override
  void initState() {
    super.initState();
    _isDark   = themeNotifier.value;
    _photoUrl = _auth.currentUser?.photoURL;
    themeNotifier.addListener(_onThemeChange);
    _loadPrefs();
    _loadStats();
  }

  void _onThemeChange() {
    if (mounted) setState(() => _isDark = themeNotifier.value);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final bday  = prefs.getString('bday') ?? '';
    final shown = prefs.getStringList('shownAchievements') ?? [];
    final settings = await NotificationService().getReminderSettings();

    String memberSince = 'Jun 2026';
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final userDoc = await _db.collection('users').doc(uid).get();
        final createdAt = userDoc.data()?['createdAt'];
        if (createdAt != null) {
          final dt = (createdAt as Timestamp).toDate();
          const months = ['','Jan','Feb','Mar','Apr','May','Jun',
              'Jul','Aug','Sep','Oct','Nov','Dec'];
          memberSince = '${months[dt.month]} ${dt.year}';
        }
      }
    } catch (_) {}

    setState(() {
      _bdayDisplay       = bday.isNotEmpty ? bday : 'Tap to set';
      _shownAchievements = shown.toSet();
      _reminderEnabled   = settings['enabled'] as bool;
      _reminderHour      = settings['hour'] as int;
      _reminderMinute    = settings['minute'] as int;
      _memberSince       = memberSince;
    });
  }

  Future<void> _saveTheme(bool val) async => await setTheme(val);

  Future<void> _saveBdayPref(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bday', val);
  }

  Future<void> _markAchievementShown(String key) async {
    _shownAchievements.add(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'shownAchievements', _shownAchievements.toList());
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, maxHeight: 512, imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _uploadingPhoto = true);
      final uid  = _auth.currentUser?.uid;
      final file = File(picked.path);
      final uri  = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['public_id']     = 'mindspace_profile_$uid';
      request.files.add(
          await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();
      final body     = await response.stream.bytesToString();
      final data     = jsonDecode(body);
      if (response.statusCode != 200) throw Exception('Upload failed');
      final url = data['secure_url'] as String;
      await _auth.currentUser?.updatePhotoURL(url);
      await _db.collection('users').doc(uid).update({'photoUrl': url});
      setState(() { _photoUrl = url; _uploadingPhoto = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile photo updated! ✓'),
            backgroundColor: Color(0xFF2D6A4F)));
      }
    } catch (e) {
      setState(() => _uploadingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to upload photo. Please try again.'),
            backgroundColor: Color(0xFFEF4444)));
      }
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final moodsSnap = await _db
          .collection('users').doc(uid)
          .collection('moods')
          .orderBy('timestamp', descending: false)
          .get();
      final journalsCount = await _db
          .collection('users').doc(uid)
          .collection('journals')
          .count().get();
      final now = DateTime.now();
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
      final user = _auth.currentUser;
      _nameCtrl.text =
          user?.displayName ?? user?.email?.split('@').first ?? 'User';
      final logs     = moodsSnap.docs.length;
      final journals = journalsCount.count ?? 0;
      setState(() {
        _totalLogs = logs; _totalJournals = journals;
        _streak = streak; _loading = false;
      });
      _checkAchievements(logs, streak, journals);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _checkAchievements(int logs, int streak, int journals) {
    final checks = [
      {'key': 'first_log',  'earned': logs >= 1,     'title': 'First Log! ⭐',     'icon': Icons.star_rounded,          'color': const Color(0xFFF59E0B)},
      {'key': 'streak_7',   'earned': streak >= 7,   'title': '7-Day Streak! 🔥',  'icon': Icons.local_fire_department, 'color': const Color(0xFFEF4444)},
      {'key': 'journals_5', 'earned': journals >= 5, 'title': '5 Journals! 📓',    'icon': Icons.menu_book_rounded,     'color': const Color(0xFF3B82F6)},
      {'key': 'streak_30',  'earned': streak >= 30,  'title': '30-Day Streak! 💎', 'icon': Icons.diamond_rounded,       'color': const Color(0xFF8B5CF6)},
      {'key': 'logs_100',   'earned': logs >= 100,   'title': '100 Mood Logs! 🏆', 'icon': Icons.emoji_events_rounded,  'color': const Color(0xFFF59E0B)},
    ];
    for (final c in checks) {
      final key    = c['key'] as String;
      final earned = c['earned'] as bool;
      if (earned && !_shownAchievements.contains(key)) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _showAchievementPopup(key: key,
                title: c['title'] as String,
                icon: c['icon'] as IconData,
                color: c['color'] as Color);
          }
        });
        break;
      }
    }
  }

  void _showAchievementPopup({required String key, required String title,
      required IconData icon, required Color color}) {
    _markAchievementShown(key);
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => _AchievementDialog(
            title: title, icon: icon, color: color, isDark: _isDark));
  }

  Future<void> _saveName() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await _auth.currentUser?.updateDisplayName(_nameCtrl.text.trim());
      await _db.collection('users').doc(_auth.currentUser?.uid)
          .update({'name': _nameCtrl.text.trim()});
      if (mounted) {
        setState(() { _editing = false; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Name updated!'),
            backgroundColor: Color(0xFF2D6A4F)));
      }
    } catch (_) { setState(() => _saving = false); }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const IntroScreen()),
          (_) => false);
    }
  }

  Future<void> _deleteAccount() async {
    try {
      final uid = _auth.currentUser?.uid;
      final moods = await _db.collection('users').doc(uid)
          .collection('moods').get();
      for (final doc in moods.docs) await doc.reference.delete();
      final journals = await _db.collection('users').doc(uid)
          .collection('journals').get();
      for (final doc in journals.docs) await doc.reference.delete();
      await _db.collection('users').doc(uid).delete();
      await _auth.currentUser?.delete();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const IntroScreen()),
            (_) => false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please sign in again before deleting your account.'),
            backgroundColor: Color(0xFFEF4444)));
      }
    }
  }

  Color get _bg      => _isDark ? const Color(0xFF050A06) : const Color(0xFFF7FBF8);
  Color get _cardBg  => _isDark ? const Color(0xFF0D1F14) : Colors.white;
  Color get _txtMain => _isDark ? const Color(0xFFE8F5EE) : const Color(0xFF1B3A2D);
  Color get _txtSub  => _isDark ? Colors.white.withOpacity(0.35) : const Color(0xFF6B8F7A);
  Color get _border  => _isDark
      ? const Color(0xFF52B788).withOpacity(0.15) : const Color(0xFFE2EEE7);

  @override
  Widget build(BuildContext context) {
    final user     = _auth.currentUser;
    final name     = _nameCtrl.text.isNotEmpty ? _nameCtrl.text
        : (user?.displayName ?? user?.email?.split('@').first ?? 'User');
    final email    = user?.email ?? '';
    final provider = user?.providerData.isNotEmpty == true
        ? user!.providerData.first.providerId : 'password';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        title: const Text('Profile', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _saveName,
              child: _saving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save', style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600, fontSize: 15)),
            )
          else
            TextButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('Edit', style: TextStyle(
                  color: Colors.white, fontSize: 14)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFF52B788)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(children: [

                const SizedBox(height: 24),

                // AVATAR
                Stack(alignment: Alignment.bottomRight, children: [
                  GestureDetector(
                    onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                    child: Container(
                      width: 84, height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _photoUrl == null
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2D6A4F), Color(0xFF52B788)])
                            : null,
                        border: Border.all(
                          color: _isDark
                              ? const Color(0xFF52B788).withOpacity(0.4)
                              : Colors.white,
                          width: 3)),
                      child: ClipOval(
                        child: _uploadingPhoto
                            ? Container(
                                color: const Color(0xFF2D6A4F).withOpacity(0.5),
                                child: const Center(child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)))
                            : _photoUrl != null
                                ? Image.network(_photoUrl!, fit: BoxFit.cover,
                                    width: 84, height: 84,
                                    errorBuilder: (_, __, ___) => Center(child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                      style: const TextStyle(fontSize: 34,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white))))
                                : Center(child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 34,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white))),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2D6A4F),
                        border: Border.all(color: _bg, width: 2)),
                      child: Icon(
                        _uploadingPhoto ? Icons.hourglass_empty_rounded
                            : Icons.camera_alt_rounded,
                        size: 13, color: Colors.white),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                _editing
                    ? TextField(
                        controller: _nameCtrl,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w700, color: _txtMain),
                        decoration: InputDecoration(
                          filled: true, fillColor: _cardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF52B788))),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF52B788), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10)))
                    : Text(name, style: TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w700, color: _txtMain)),
                const SizedBox(height: 4),
                Text(email, style: TextStyle(fontSize: 13, color: _txtSub)),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isDark
                        ? const Color(0xFF52B788).withOpacity(0.12)
                        : const Color(0xFFE8F5EE),
                    borderRadius: BorderRadius.circular(20),
                    border: _isDark ? Border.all(
                        color: const Color(0xFF52B788).withOpacity(0.25),
                        width: 0.5) : null),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.eco_rounded, size: 13,
                        color: _isDark
                            ? const Color(0xFF52B788)
                            : const Color(0xFF2D6A4F)),
                    const SizedBox(width: 5),
                    Text('Member since $_memberSince',
                        style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _isDark
                                ? const Color(0xFF52B788)
                                : const Color(0xFF2D6A4F))),
                  ]),
                ),
                const SizedBox(height: 20),

                // STATS
                Row(children: [
                  _statCard('$_totalLogs', 'Mood Logs',
                      [const Color(0xFF134E4A), const Color(0xFF0F766E)]),
                  const SizedBox(width: 8),
                  _statCard('$_streak 🔥', 'Day Streak',
                      [const Color(0xFF7F1D1D), const Color(0xFF991B1B)]),
                  const SizedBox(width: 8),
                  _statCard('$_totalJournals', 'Journals',
                      [const Color(0xFF2E1065), const Color(0xFF4C1D95)]),
                ]),
                const SizedBox(height: 20),

                // ACHIEVEMENTS
                _sectionTitle('ACHIEVEMENTS'),
                const SizedBox(height: 10),
                SizedBox(height: 115, child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _badgeCard('First Log', Icons.star_rounded,
                        const Color(0xFFF59E0B), const Color(0xFFFEF3C7),
                        _totalLogs >= 1,
                        _totalLogs >= 1 ? 'Earned ✓' : 'Log a mood'),
                    _badgeCard('7-Day Streak', Icons.local_fire_department,
                        const Color(0xFFEF4444), const Color(0xFFFEE2E2),
                        _streak >= 7,
                        _streak >= 7 ? 'Earned ✓' : '${(7-_streak).clamp(0,7)} days left'),
                    _badgeCard('5 Journals', Icons.menu_book_rounded,
                        const Color(0xFF3B82F6), const Color(0xFFEFF6FF),
                        _totalJournals >= 5,
                        _totalJournals >= 5 ? 'Earned ✓' : '${(5-_totalJournals).clamp(0,5)} left'),
                    _badgeCard('30-Day Streak', Icons.diamond_rounded,
                        const Color(0xFF8B5CF6), const Color(0xFFF5F3FF),
                        _streak >= 30,
                        _streak >= 30 ? 'Earned ✓' : '${(30-_streak).clamp(0,30)} days left'),
                    _badgeCard('100 Logs', Icons.emoji_events_rounded,
                        const Color(0xFFF59E0B), const Color(0xFFFEF9C3),
                        _totalLogs >= 100,
                        _totalLogs >= 100 ? 'Earned ✓' : '${(100-_totalLogs).clamp(0,100)} left'),
                  ],
                )),
                const SizedBox(height: 20),

                // ACCOUNT
                _sectionTitle('ACCOUNT'),
                const SizedBox(height: 8),
                _infoCard([
                  _row(Icons.person_outline_rounded,
                      const Color(0xFFE8F5EE), const Color(0xFF2D6A4F),
                      'Display Name', name,
                      onTap: () => setState(() => _editing = true)),
                  _row(Icons.mail_outline_rounded,
                      const Color(0xFFEFF6FF), const Color(0xFF3B82F6),
                      'Email', email),
                  _row(Icons.cake_rounded,
                      const Color(0xFFFEF3C7), const Color(0xFFF59E0B),
                      'Date of Birth', _bdayDisplay,
                      onTap: _showBdayPicker),
                  _row(provider == 'google.com'
                      ? Icons.g_mobiledata_rounded : Icons.email_rounded,
                      const Color(0xFFEFF6FF), const Color(0xFF3B82F6),
                      'Sign-in Method',
                      provider == 'google.com' ? 'Google' : 'Email'),
                ]),
                const SizedBox(height: 16),

                // PREFERENCES
                _sectionTitle('PREFERENCES'),
                const SizedBox(height: 8),
                _infoCard([
                  _toggleRow(Icons.nightlight_round,
                      const Color(0xFFF5F3FF), const Color(0xFF7C3AED),
                      'Dark Mode',
                      _isDark ? 'Currently dark' : 'Currently light',
                      _isDark, (val) async {
                        setState(() => _isDark = val);
                        await _saveTheme(val);
                      }),
                  _reminderToggleRow(),
                  _row(Icons.language_rounded,
                      const Color(0xFFFFF7ED), const Color(0xFFF97316),
                      'Language', 'English'),
                ]),
                const SizedBox(height: 16),

                // APP INFO
                _sectionTitle('APP INFO'),
                const SizedBox(height: 8),
                _infoCard([
                  _row(Icons.info_outline_rounded,
                      const Color(0xFFF0FDF4), const Color(0xFF22C55E),
                      'Version', '1.0.0'),
                  _row(Icons.shield_outlined,
                      const Color(0xFFFFF1F2), const Color(0xFFEF4444),
                      'Privacy Policy', '',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                              _PrivacyPolicyScreen(isDark: _isDark)))),
                  _row(Icons.favorite_border_rounded,
                      const Color(0xFFFFF7ED), const Color(0xFFF97316),
                      'Made with', 'Flutter + Firebase'),
                ]),
                const SizedBox(height: 20),

                // DANGER ZONE
                _sectionTitle('DANGER ZONE',
                    color: const Color(0xFFEF4444)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        width: 0.5)),
                  child: Column(children: [
                    _dangerRow(Icons.logout_rounded, 'Sign Out', '',
                        onTap: _showSignOutDialog),
                    Divider(height: 0.5,
                        color: const Color(0xFFEF4444).withOpacity(0.15)),
                    _dangerRow(Icons.delete_outline_rounded,
                        'Delete Account',
                        'Permanently removes all your data',
                        onTap: _showDeleteDialog),
                  ]),
                ),
                const SizedBox(height: 30),
              ]),
            ),
    );
  }

  Widget _reminderToggleRow() {
    final timeStr =
        '${_reminderHour.toString().padLeft(2,'0')}:'
        '${_reminderMinute.toString().padLeft(2,'0')}';

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.notifications_outlined,
                  size: 16, color: Color(0xFF10B981))),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Daily Reminder', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w500, color: _txtMain)),
            Text(_reminderEnabled ? 'Every day at $timeStr' : 'Off',
                style: TextStyle(fontSize: 11, color: _txtSub)),
          ])),
          Switch.adaptive(
            value: _reminderEnabled,
            onChanged: (val) async {
              if (val) {
                await NotificationService().scheduleDailyReminder(
                    hour: _reminderHour, minute: _reminderMinute);
                await NotificationService().showTestNotification();
                setState(() => _reminderEnabled = true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Reminder set for $timeStr daily! ✓'),
                      backgroundColor: const Color(0xFF2D6A4F)));
                }
              } else {
                await NotificationService().cancelReminder();
                setState(() => _reminderEnabled = false);
              }
            },
            activeColor: const Color(0xFF2D6A4F),
          ),
        ]),
      ),
      if (_reminderEnabled)
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                  hour: _reminderHour, minute: _reminderMinute),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: _isDark
                      ? ColorScheme.dark(
                          primary: const Color(0xFF52B788),
                          surface: _cardBg)
                      : ColorScheme.light(
                          primary: const Color(0xFF2D6A4F),
                          surface: _cardBg),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() {
                _reminderHour   = picked.hour;
                _reminderMinute = picked.minute;
              });
              await NotificationService().scheduleDailyReminder(
                  hour: picked.hour, minute: picked.minute);
              if (mounted) {
                final t = '${picked.hour.toString().padLeft(2,'0')}:'
                    '${picked.minute.toString().padLeft(2,'0')}';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Reminder updated to $t ✓'),
                    backgroundColor: const Color(0xFF2D6A4F)));
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(58, 0, 14, 12),
            child: Row(children: [
              const Icon(Icons.access_time_rounded,
                  size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Text('Tap to change time', style: TextStyle(
                  fontSize: 12, color: const Color(0xFF10B981))),
              const Spacer(),
              Text(timeStr, style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981))),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 16, color: _txtSub),
            ]),
          ),
        ),
    ]);
  }

  Widget _badgeCard(String name, IconData icon, Color iconColor,
      Color bgColor, bool earned, String status) {
    return Opacity(
      opacity: earned ? 1.0 : 0.45,
      child: Container(
        width: 80, margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: earned
              ? (_isDark ? iconColor.withOpacity(0.1) : bgColor)
              : (_isDark
                  ? Colors.white.withOpacity(0.04)
                  : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: earned ? iconColor.withOpacity(0.35)
                : (_isDark
                    ? Colors.white.withOpacity(0.07)
                    : Colors.grey.withOpacity(0.15)),
            width: 0.5)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: earned ? iconColor.withOpacity(0.15)
                    : (_isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.withOpacity(0.08))),
              child: Icon(icon, size: 22,
                  color: earned ? iconColor
                      : (_isDark
                          ? Colors.white.withOpacity(0.2)
                          : Colors.grey))),
            if (!earned)
              const Positioned(bottom: -2, right: -5,
                  child: Text('🔒', style: TextStyle(fontSize: 11))),
          ]),
          const SizedBox(height: 7),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(name, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                    color: earned ? _txtMain : _txtSub, height: 1.3))),
          const SizedBox(height: 3),
          Text(status, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8,
                  color: earned ? iconColor : _txtSub.withOpacity(0.7))),
        ]),
      ),
    );
  }

  Widget _statCard(String val, String label, List<Color> colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(val, style: const TextStyle(fontSize: 18,
              fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9,
              color: Colors.white.withOpacity(0.8))),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title,
      {Color color = const Color(0xFF2D6A4F)}) {
    return Align(alignment: Alignment.centerLeft,
      child: Text(title, style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.07, color: color)));
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 0.5),
        boxShadow: _isDark ? null : [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(children: children),
    );
  }

  Widget _row(IconData icon, Color iconBg, Color iconColor,
      String label, String value, {VoidCallback? onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(width: 32, height: 32,
              decoration: BoxDecoration(color: iconBg,
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: iconColor)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w500, color: _txtMain))),
          if (value.isNotEmpty)
            Text(value, style: TextStyle(fontSize: 12, color: _txtSub)),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, size: 18, color: _txtSub),
        ])));
  }

  Widget _toggleRow(IconData icon, Color iconBg, Color iconColor,
      String label, String sub, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(width: 32, height: 32,
            decoration: BoxDecoration(color: iconBg,
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w500, color: _txtMain)),
          Text(sub, style: TextStyle(fontSize: 11, color: _txtSub)),
        ])),
        Switch.adaptive(value: value, onChanged: onChanged,
            activeColor: const Color(0xFF2D6A4F)),
      ]),
    );
  }

  Widget _dangerRow(IconData icon, String label, String sub,
      {VoidCallback? onTap}) {
    return InkWell(onTap: onTap,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(width: 32, height: 32,
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16,
                  color: const Color(0xFFEF4444))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(label, style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFFEF4444))),
            if (sub.isNotEmpty)
              Text(sub, style: const TextStyle(fontSize: 11,
                  color: Color(0xFFEF4444), height: 1.3),
                  maxLines: 1),
          ])),
          Icon(Icons.chevron_right_rounded, size: 18,
              color: const Color(0xFFEF4444).withOpacity(0.4)),
        ])));
  }

  void _showBdayPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Column(
            mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: _border,
                  borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(16),
              child: Text('Date of Birth', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: _txtMain))),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 80, height: 120,
              child: ListWheelScrollView.useDelegate(itemExtent: 36,
                onSelectedItemChanged: (i) =>
                    setModalState(() => _bdayDay = i + 1),
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (_, i) => Center(child: Text('${i+1}',
                      style: TextStyle(fontSize: 16, color: _txtMain))),
                  childCount: 31))),
            SizedBox(width: 100, height: 120,
              child: ListWheelScrollView.useDelegate(itemExtent: 36,
                onSelectedItemChanged: (i) =>
                    setModalState(() => _bdayMonth = i + 1),
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (_, i) {
                    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                        'Jul','Aug','Sep','Oct','Nov','Dec'];
                    return Center(child: Text(m[i],
                        style: TextStyle(fontSize: 16, color: _txtMain)));
                  }, childCount: 12))),
            SizedBox(width: 90, height: 120,
              child: ListWheelScrollView.useDelegate(itemExtent: 36,
                onSelectedItemChanged: (i) =>
                    setModalState(() => _bdayYear = 2006 - i),
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (_, i) => Center(child: Text('${2006-i}',
                      style: TextStyle(fontSize: 16, color: _txtMain))),
                  childCount: 30))),
          ]),
          Padding(padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  const months = ['','Jan','Feb','Mar','Apr','May',
                      'Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                  final display =
                      '$_bdayDay ${months[_bdayMonth]} $_bdayYear';
                  setState(() => _bdayDisplay = display);
                  _saveBdayPref(display);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0),
                child: const Text('Save', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600))))),
        ]),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Sign out?', style: TextStyle(
            color: _txtMain, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: _txtSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _txtSub))),
          TextButton(
            onPressed: () { Navigator.pop(context); _signOut(); },
            child: const Text('Sign out', style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Text('⚠️ ', style: TextStyle(fontSize: 20)),
          Text('Delete Account?', style: TextStyle(
              color: _txtMain, fontWeight: FontWeight.w700,
              fontSize: 16)),
        ]),
        content: Text(
            'This will permanently delete your account and all mood logs, '
            'journal entries, and data. This cannot be undone.',
            style: TextStyle(color: _txtSub, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _txtSub))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _deleteAccount(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0),
            child: const Text('Delete', style: TextStyle(
                fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// PRIVACY POLICY SCREEN
// ══════════════════════════════════════════
class _PrivacyPolicyScreen extends StatelessWidget {
  final bool isDark;
  const _PrivacyPolicyScreen({required this.isDark});

  Color get _bg     => isDark ? const Color(0xFF050A06) : const Color(0xFFF7FBF8);
  Color get _cardBg => isDark ? const Color(0xFF0D1F14) : Colors.white;
  Color get _txtMain=> isDark ? const Color(0xFFE8F5EE) : const Color(0xFF1B3A2D);
  Color get _txtSub => isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF6B8F7A);
  Color get _border => isDark
      ? const Color(0xFF52B788).withOpacity(0.15) : const Color(0xFFE2EEE7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        title: const Text('Privacy Policy', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [

          // Header with real logo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F2E1A), Color(0xFF071A0D)]),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 0.5)),
                  child: Center(child: CustomPaint(
                      size: const Size(22, 22),
                      painter: _MindSpaceLogoPainter())),
                ),
                const SizedBox(width: 10),
                const Text('MindSpace', style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
              const SizedBox(height: 8),
              Text('Privacy Policy', style: TextStyle(fontSize: 14,
                  color: Colors.white.withOpacity(0.8))),
              const SizedBox(height: 4),
              Text('Last updated: June 2026', style: TextStyle(fontSize: 11,
                  color: Colors.white.withOpacity(0.6))),
            ]),
          ),
          const SizedBox(height: 16),

          _section('1. Information We Collect',
              'MindSpace collects the following information:\n\n'
              '• Account Information: Name, email address, and profile photo\n'
              '• Mood Data: Your daily mood logs, notes, and wellness entries\n'
              '• Journal Entries: Personal journal content you create\n'
              '• Usage Data: App interaction patterns to improve your experience'),

          _section('2. How We Use Your Information',
              'We use your information to:\n\n'
              '• Provide personalized mood tracking and insights\n'
              '• Display your wellness history and progress\n'
              '• Send daily reminders (only if enabled by you)\n'
              '• Improve app features and performance\n'
              '• Ensure account security'),

          _section('3. Data Storage & Security',
              'Your data is securely stored using Google Firebase. '
              'We implement industry-standard security measures:\n\n'
              '• End-to-end encryption for data transmission\n'
              '• Secure authentication via Firebase Auth\n'
              '• Data access restricted to your account only'),

          _section('4. Third-Party Services',
              'MindSpace uses the following third-party services:\n\n'
              '• Google Firebase: Authentication and data storage\n'
              '• Google Sign-In: Optional authentication method\n'
              '• Cloudinary: Profile photo storage'),

          _section('5. Your Rights',
              'You have the right to:\n\n'
              '• Access your personal data at any time\n'
              '• Edit or update your information\n'
              '• Delete your account and all associated data\n'
              '• Opt out of notifications at any time'),

          _section('6. Data Retention',
              'We retain your data for as long as your account is active. '
              'When you delete your account, all personal data is '
              'permanently deleted within 24 hours.'),

          _section('7. Contact Us',
              'If you have any questions about this Privacy Policy:\n\n'
              '📧 support@mindspace.app'),

          const SizedBox(height: 20),

          // Footer with real logo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border, width: 0.5)),
            child: Column(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2D6A4F), Color(0xFF52B788)])),
                child: Center(child: CustomPaint(
                    size: const Size(26, 26),
                    painter: _MindSpaceLogoPainter())),
              ),
              const SizedBox(height: 10),
              Text('MindSpace cares about your privacy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600, color: _txtMain)),
              const SizedBox(height: 4),
              Text('Your wellness journey is personal and private.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: _txtSub)),
            ]),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _section(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w700, color: _txtMain)),
        const SizedBox(height: 8),
        Text(content, style: TextStyle(fontSize: 12,
            color: _txtSub, height: 1.7)),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// MINDSPACE LOGO PAINTER
// ══════════════════════════════════════════
class _MindSpaceLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.43;
    final r  = size.height * 0.214;

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final green = Paint()
      ..color = const Color(0xFF52B788)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), r, white);

    final wave = Path()
      ..moveTo(cx - r * 0.75, cy)
      ..quadraticBezierTo(cx - r * 0.35, cy - r * 0.6, cx, cy)
      ..quadraticBezierTo(cx + r * 0.35, cy + r * 0.6,
          cx + r * 0.75, cy);
    canvas.drawPath(wave, green);

    final dot = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - r * 0.42, cy - r * 0.35), 1.8, dot);
    canvas.drawCircle(Offset(cx + r * 0.42, cy - r * 0.35), 1.8, dot);

    final body = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy + r),
        Offset(cx, cy + r * 1.65), body);
    canvas.drawLine(Offset(cx - r * 0.6, cy + r * 1.4),
        Offset(cx, cy + r * 1.65), body);
    canvas.drawLine(Offset(cx + r * 0.6, cy + r * 1.4),
        Offset(cx, cy + r * 1.65), body);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════
// ACHIEVEMENT DIALOG
// ══════════════════════════════════════════
class _AchievementDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _AchievementDialog({required this.title, required this.icon,
      required this.color, required this.isDark});
  @override
  State<_AchievementDialog> createState() => _AchievementDialogState();
}

class _AchievementDialogState extends State<_AchievementDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _confetti.play();
    });
  }

  @override
  void dispose() { _confetti.dispose(); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cardBg  = widget.isDark ? const Color(0xFF0D1F14) : Colors.white;
    final txtMain = widget.isDark
        ? const Color(0xFFE8F5EE) : const Color(0xFF1B3A2D);
    final txtSub  = widget.isDark
        ? Colors.white.withOpacity(0.4) : const Color(0xFF6B8F7A);

    return Stack(alignment: Alignment.topCenter, children: [
      Positioned(top: 0,
        child: ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 25, gravity: 0.25,
          emissionFrequency: 0.04,
          maxBlastForce: 20, minBlastForce: 8,
          colors: const [
            Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF3B82F6),
            Color(0xFF10B981), Color(0xFF8B5CF6), Color(0xFFF97316),
            Color(0xFF06D6A0), Color(0xFFFFD93D), Color(0xFFFF6B6B),
            Color(0xFF52B788)],
        )),

      FadeTransition(opacity: _fade,
        child: Dialog(backgroundColor: Colors.transparent,
          child: ScaleTransition(scale: _scale,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: cardBg, borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: widget.color.withOpacity(0.3), width: 0.5),
                boxShadow: [BoxShadow(
                    color: widget.color.withOpacity(
                        widget.isDark ? 0.15 : 0.1),
                    blurRadius: 30, spreadRadius: 5)]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 96, height: 96,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: widget.color.withOpacity(
                        widget.isDark ? 0.12 : 0.08),
                    border: Border.all(
                        color: widget.color.withOpacity(0.35), width: 2),
                    boxShadow: [BoxShadow(
                        color: widget.color.withOpacity(0.25),
                        blurRadius: 20, spreadRadius: 2)]),
                  child: Icon(widget.icon, size: 44, color: widget.color)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: widget.color.withOpacity(0.25), width: 0.5)),
                  child: Text('Achievement Unlocked!', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: widget.color, letterSpacing: 0.05))),
                const SizedBox(height: 10),
                Text(widget.title, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w700, color: txtMain)),
                const SizedBox(height: 8),
                Text('Keep up the great work!',
                    style: TextStyle(fontSize: 13, color: txtSub)),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                      elevation: 0,
                      shadowColor: widget.color.withOpacity(0.4)),
                    child: const Text('Awesome! 🎉', style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)))),
              ]),
            )))),
    ]);
  }
}