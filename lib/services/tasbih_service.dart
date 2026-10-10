import 'dart:convert';
import '../utils/ar.dart';
import 'storage_service.dart';

/// معلومات الستريك الحالية
class StreakInfo {
  final int current; // عدد الأيام المتتالية
  final int best; // أفضل ستريك
  final bool todayDone; // هل أنجز اليوم 500؟
  final int todayCount; // تسبيحات اليوم

  const StreakInfo({
    required this.current,
    required this.best,
    required this.todayDone,
    required this.todayCount,
  });
}

/// تسبيحة (نص + هدف)
class DhikrItem {
  final String text;
  final int goal;
  const DhikrItem(this.text, this.goal);

  Map<String, dynamic> toJson() => {'t': text, 'g': goal};

  factory DhikrItem.fromJson(Map<String, dynamic> j) {
    return DhikrItem(
      j['t'] as String? ?? '',
      j['g'] as int? ?? 100,
    );
  }
}

/// خدمة التسبيح والستريك
/// - كل البيانات تُحفظ على الهاتف عبر shared_preferences
/// - اليوم يُحسب ضمن الستريك إذا وصل مجموع التسبيح فيه إلى 500
class TasbihService {
  static const int streakGoal = 500;

  static const String _keyHistory = 'tasbih_history';
  static const String _keyBest = 'tasbih_best';
  static const String _keyCustom = 'tasbih_custom';
  static const String _keyAdhkarDone = 'adhkar_done';

  static const List<DhikrItem> baseDhikr = <DhikrItem>[
    DhikrItem('سبحان الله', 100),
    DhikrItem('الحمد لله', 100),
    DhikrItem('الله أكبر', 100),
    DhikrItem('أستغفر الله', 100),
    DhikrItem('لا إله إلا الله', 100),
  ];

  static Map<String, int> _history = <String, int>{};
  static bool _loaded = false;

  // ============================================================
  // التحميل
  // ============================================================
  static void load() {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = StorageService.getString(_keyHistory);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> m = jsonDecode(raw) as Map<String, dynamic>;
        final result = <String, int>{};
        m.forEach((k, v) {
          if (v is int) {
            result[k] = v;
          } else if (v is num) {
            result[k] = v.toInt();
          }
        });
        _history = result;
      }
    } catch (_) {
      _history = <String, int>{};
    }
  }

  static Future<void> _save() async {
    // نحتفظ بآخر 400 يوماً فقط
    if (_history.length > 400) {
      final keys = _history.keys.toList()..sort();
      final extra = keys.length - 400;
      for (int i = 0; i < extra; i++) {
        _history.remove(keys[i]);
      }
    }
    await StorageService.setString(_keyHistory, jsonEncode(_history));
  }

  // ============================================================
  // العدّ
  // ============================================================
  static int countFor(DateTime day) => _history[dayKeyOf(day)] ?? 0;

  static int get todayCount => countFor(DateTime.now());

  /// يضيف تسبيحة واحدة لليوم الحالي ويعيد المجموع الجديد
  static Future<int> addOne() async {
    load();
    final key = dayKeyOf(DateTime.now());
    final next = (_history[key] ?? 0) + 1;
    _history[key] = next;
    await _save();
    return next;
  }

  // ============================================================
  // الستريك
  // ============================================================
  static bool _done(int daysAgo) => countFor(dayAgo(daysAgo)) >= streakGoal;

  static StreakInfo streak() {
    load();
    final todayDone = _done(0);
    int offset = todayDone ? 0 : 1;
    int current = 0;
    while (_done(offset) && offset < 1000) {
      current++;
      offset++;
    }

    // أفضل ستريك من السجل كاملاً
    final doneKeys = _history.keys
        .where((k) => (_history[k] ?? 0) >= streakGoal)
        .toList()
      ..sort();
    int best = 0;
    int run = 0;
    int? prevDay;
    for (final k in doneKeys) {
      final parts = k.split('-');
      if (parts.length != 3) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) continue;
      final dayNumber =
          DateTime.utc(y, m, d).millisecondsSinceEpoch ~/ 86400000;
      if (prevDay != null && dayNumber - prevDay == 1) {
        run++;
      } else {
        run = 1;
      }
      prevDay = dayNumber;
      if (run > best) best = run;
    }
    final stored = StorageService.getInt(_keyBest);
    if (current > best) best = current;
    if (stored > best) best = stored;
    if (best != stored) {
      StorageService.setInt(_keyBest, best);
    }

    return StreakInfo(
      current: current,
      best: best,
      todayDone: todayDone,
      todayCount: countFor(DateTime.now()),
    );
  }

  /// هل أُنجز اليوم الذي قبل [daysAgo] يوماً؟
  static bool doneDaysAgo(int daysAgo) {
    load();
    return _done(daysAgo);
  }

  // ============================================================
  // التسبيحات المخصصة
  // ============================================================
  static List<DhikrItem> getCustom() {
    try {
      final raw = StorageService.getString(_keyCustom);
      if (raw == null || raw.isEmpty) return <DhikrItem>[];
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => DhikrItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return <DhikrItem>[];
    }
  }

  static Future<void> saveCustom(List<DhikrItem> items) async {
    await StorageService.setString(
        _keyCustom, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  // ============================================================
  // الأذكار المنجزة اليوم
  // ============================================================
  static List<int> getAdhkarDone() {
    try {
      final raw = StorageService.getString(_keyAdhkarDone);
      if (raw == null || raw.isEmpty) return <int>[];
      final Map<String, dynamic> m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['day'] != dayKeyOf(DateTime.now())) return <int>[];
      return (m['ids'] as List<dynamic>).map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return <int>[];
    }
  }

  static Future<void> saveAdhkarDone(List<int> ids) async {
    await StorageService.setString(
      _keyAdhkarDone,
      jsonEncode({'day': dayKeyOf(DateTime.now()), 'ids': ids}),
    );
  }
}
