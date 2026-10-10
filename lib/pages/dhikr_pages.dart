import 'dart:math';
import 'package:flutter/material.dart';
import '../data/adhkar_data.dart';
import '../services/tasbih_service.dart';
import '../theme.dart';
import '../utils/ar.dart';

// ============================================================
// صفحة الأذكار (مع علامة "تم" تُحفظ لليوم الحالي)
// ============================================================
class AdhkarPage extends StatefulWidget {
  const AdhkarPage({Key? key}) : super(key: key);

  @override
  State<AdhkarPage> createState() => _AdhkarPageState();
}

class _AdhkarPageState extends State<AdhkarPage> {
  List<int> _done = <int>[];

  @override
  void initState() {
    super.initState();
    _done = TasbihService.getAdhkarDone();
  }

  void _toggle(int i) {
    final next = List<int>.from(_done);
    if (next.contains(i)) {
      next.remove(i);
    } else {
      next.add(i);
    }
    setState(() => _done = next);
    TasbihService.saveAdhkarDone(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الأذكار',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        itemCount: kAdhkar.length,
        itemBuilder: (context, i) {
          final item = kAdhkar[i];
          final done = _done.contains(i);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Opacity(
              opacity: done ? 0.55 : 1.0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                decoration: BoxDecoration(
                  color: AppTints.card(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      item.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, height: 1.9),
                    ),
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.note,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    done
                        ? FilledButton.tonalIcon(
                            onPressed: () => _toggle(i),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('تم'),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => _toggle(i),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('تم'),
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// صفحة الأحاديث (حديث اليوم + القائمة)
// ============================================================
class HadithPage extends StatefulWidget {
  const HadithPage({Key? key}) : super(key: key);

  @override
  State<HadithPage> createState() => _HadithPageState();
}

class _HadithPageState extends State<HadithPage> {
  int _today = 0;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _today = dayIndexOf(kHadith.length);
  }

  void _another() {
    if (kHadith.length < 2) return;
    int n = _today;
    while (n == _today) {
      n = _rand.nextInt(kHadith.length);
    }
    setState(() => _today = n);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c1 = dark ? const Color(0xFF0E6B53) : scheme.primary;
    final c2 = dark
        ? const Color(0xFF1C8F70)
        : Color.alphaBlend(Colors.white.withOpacity(.4), scheme.primary);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الأحاديث',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c1, c2],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Text(
                  '✦ حديث اليوم ✦',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    color: Colors.white.withOpacity(.85),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  kHadith[_today],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1.9,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _another,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('حديث آخر'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Divider(color: scheme.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'جميع الأحاديث',
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ),
              Expanded(child: Divider(color: scheme.outlineVariant)),
            ],
          ),
          const SizedBox(height: 14),
          ...kHadith.map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: AppTints.card(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  h,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 19, height: 1.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
