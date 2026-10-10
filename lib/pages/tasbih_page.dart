import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/tasbih_service.dart';
import '../theme.dart';
import '../utils/ar.dart';

/// صفحة التسبيح مع الستريك اليومي
/// اليوم الذي يصل فيه مجموع التسبيح إلى 500 يُحسب في الستريك
class TasbihPage extends StatefulWidget {
  const TasbihPage({Key? key}) : super(key: key);

  @override
  State<TasbihPage> createState() => _TasbihPageState();
}

class _TasbihPageState extends State<TasbihPage> {
  List<DhikrItem> _custom = <DhikrItem>[];
  int _index = 0;
  int _count = 0;
  bool _goalLock = false;
  bool _pop = false;
  bool _dialogOpen = false;
  Timer? _resetTimer;
  late StreakInfo _streak;

  List<DhikrItem> get _all =>
      <DhikrItem>[...TasbihService.baseDhikr, ..._custom];

  DhikrItem get _current {
    final list = _all;
    if (_index >= list.length) return list.first;
    return list[_index];
  }

  @override
  void initState() {
    super.initState();
    TasbihService.load();
    _custom = TasbihService.getCustom();
    _streak = TasbihService.streak();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // العد
  // ============================================================
  Future<void> _tap() async {
    if (_goalLock) return;
    final goal = _current.goal;

    setState(() => _count++);
    HapticFeedback.selectionClick();

    // نقفل العدّ فوراً عند بلوغ الهدف حتى لا تتكرر الاحتفالات
    final bool reached = _count >= goal;
    if (reached) _goalLock = true;

    await TasbihService.addOne();
    if (!mounted) return;

    final info = TasbihService.streak();
    final bool justDone = !_streak.todayDone && info.todayDone;
    setState(() => _streak = info);

    if (justDone) {
      // وصل اليوم إلى 500 لأول مرة → احتفال الستريك
      setState(() => _pop = true);
      Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _pop = false);
      });
      _celebrateStreak(info.current);
    }

    if (reached) {
      HapticFeedback.heavyImpact();
      if (!_dialogOpen) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('بارك الله بيك'),
            duration: Duration(milliseconds: 1300),
          ),
        );
      }
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 1300), () {
        if (!mounted) return;
        setState(() {
          _count = 0;
          _goalLock = false;
        });
      });
    }
  }

  Future<void> _celebrateStreak(int days) async {
    HapticFeedback.vibrate();
    _dialogOpen = true;
    final timer = Timer(const Duration(milliseconds: 2800), () {
      if (_dialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppTints.flame(ctx).withOpacity(.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_fire_department_rounded,
                      size: 52, color: AppTints.flame(ctx)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ثبّتّ ستريك اليوم!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  days <= 1
                      ? 'بدأت ستريكك، واصل غداً بإذن الله'
                      : 'ستريكك الآن ${arNum(days)} أيام متتالية',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
    _dialogOpen = false;
    timer.cancel();
  }

  void _select(int i) {
    _resetTimer?.cancel();
    setState(() {
      _index = i;
      _count = 0;
      _goalLock = false;
    });
  }

  void _reset() {
    _resetTimer?.cancel();
    setState(() {
      _count = 0;
      _goalLock = false;
    });
  }

  Future<void> _deleteCustom(int allIndex) async {
    final ci = allIndex - TasbihService.baseDhikr.length;
    if (ci < 0 || ci >= _custom.length) return;
    final next = List<DhikrItem>.from(_custom)..removeAt(ci);
    await TasbihService.saveCustom(next);
    if (!mounted) return;
    setState(() {
      _custom = next;
      if (_index >= allIndex) _index = _index > 0 ? _index - 1 : 0;
      _count = 0;
    });
  }

  Future<void> _addDialog() async {
    final textCtrl = TextEditingController();
    final goalCtrl = TextEditingController(text: '100');
    final result = await showDialog<DhikrItem>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('إضافة تسبيحة جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                autofocus: true,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'نص التسبيحة',
                  hintText: 'اكتب الذكر هنا...',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: goalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الهدف (عدد)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final t = textCtrl.text.trim();
                int g = int.tryParse(goalCtrl.text.trim()) ?? 100;
                if (g < 1) g = 1;
                if (g > 9999) g = 9999;
                if (t.isEmpty) return;
                Navigator.pop(ctx, DhikrItem(t, g));
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    final next = List<DhikrItem>.from(_custom)..add(result);
    await TasbihService.saveCustom(next);
    if (!mounted) return;
    setState(() {
      _custom = next;
      _index = TasbihService.baseDhikr.length + next.length - 1;
      _count = 0;
      _goalLock = false;
    });
  }

  // ============================================================
  // الواجهة
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = _all;
    final goal = _current.goal;
    final p = (_count / goal).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'التسبيح',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: <Widget>[
          _StreakCard(info: _streak, pop: _pop),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: List<Widget>.generate(all.length, (i) {
              final selected = i == _index;
              final isCustom = i >= TasbihService.baseDhikr.length;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _select(i),
                child: Container(
                  height: 36,
                  padding: EdgeInsetsDirectional.fromSTEB(16, 0, isCustom ? 6 : 16, 0),
                  decoration: BoxDecoration(
                    color: selected ? scheme.secondaryContainer : null,
                    borderRadius: BorderRadius.circular(10),
                    border: selected
                        ? null
                        : Border.all(color: scheme.outline, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCustom)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _deleteCustom(i),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      Text(
                        all[i].text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected
                              ? scheme.onSecondaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: _addDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة تسبيحة'),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            _current.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 236,
              height: 236,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 236,
                    height: 236,
                    child: CircularProgressIndicator(
                      value: p,
                      strokeWidth: 8,
                      backgroundColor: scheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                    ),
                  ),
                  GestureDetector(
                    onTap: _tap,
                    child: Container(
                      width: 204,
                      height: 204,
                      decoration: BoxDecoration(
                        color: AppTints.card(context),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withOpacity(.2),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            arNum(_count),
                            style: TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'اضغط للتسبيح',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الهدف: ${arNum(goal)}',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    '${arNum((p * 100).round())}٪',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// بطاقة الستريك
// ============================================================
class _StreakCard extends StatelessWidget {
  const _StreakCard({Key? key, required this.info, required this.pop})
      : super(key: key);

  final StreakInfo info;
  final bool pop;

  @override
  Widget build(BuildContext context) {
    final sand = AppTints.sand(context);
    final on = AppTints.onSand(context);
    final flame = AppTints.flame(context);
    final left = (TasbihService.streakGoal - info.todayCount) < 0
        ? 0
        : (TasbihService.streakGoal - info.todayCount);
    final progress = (info.todayCount / TasbihService.streakGoal)
        .clamp(0.0, 1.0)
        .toDouble();
    final active = info.current > 0 || info.todayDone;

    String msg;
    if (info.todayDone) {
      msg = 'أحسنت! ثبّتّ ستريك اليوم، واصل غداً';
    } else if (info.current > 0) {
      msg = 'سبّح ${arNum(left)} مرة أخرى حتى لا ينقطع ستريكك';
    } else {
      msg = 'سبّح ${arNum(TasbihService.streakGoal)} مرة في اليوم لتبدأ ستريكك';
    }

    final String unit = info.current == 1
        ? 'يوم'
        : (info.current == 2 ? 'يومان' : 'أيام');

    final days = <Widget>[];
    for (int i = 6; i >= 0; i--) {
      final date = dayAgo(i);
      final ok = TasbihService.doneDaysAgo(i);
      final isToday = i == 0;
      days.add(
        Expanded(
          child: Column(
            children: [
              Text(
                arWeekday(date.weekday),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: on.withOpacity(.9),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ok ? flame : on.withOpacity(.09),
                  border: (isToday && !ok)
                      ? Border.all(color: flame, width: 2)
                      : null,
                ),
                child: ok
                    ? Icon(Icons.local_fire_department_rounded,
                        size: 19, color: AppTints.onFlame(context))
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: sand,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedScale(
                scale: pop ? 1.3 : 1.0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? flame.withOpacity(.24)
                        : on.withOpacity(.1),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: 34,
                    color: active ? flame : on.withOpacity(.45),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          arNum(info.current),
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: on,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '$unit متتالية',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: on,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      msg,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: on.withOpacity(.78),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: on.withOpacity(.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'الأفضل ${arNum(info.best)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: on,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تسبيحات اليوم',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: on),
              ),
              Text(
                '${arNum(info.todayCount)} / ${arNum(TasbihService.streakGoal)}',
                style: TextStyle(fontSize: 13, color: on.withOpacity(.75)),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: on.withOpacity(.13),
              valueColor: AlwaysStoppedAnimation<Color>(flame),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: on.withOpacity(.14)),
          const SizedBox(height: 14),
          Row(children: days),
        ],
      ),
    );
  }
}
