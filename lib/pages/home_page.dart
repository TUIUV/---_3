import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/adhkar_data.dart';
import '../services/storage_service.dart';
import '../services/tasbih_service.dart';
import '../theme.dart';
import '../utils/ar.dart';
import 'reader_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    Key? key,
    this.active = true,
    this.refreshTick = 0,
    this.onGoToQuran,
    this.onGoToTilawa,
    this.onGoToTasbih,
    this.onOpenAdhkar,
    this.onOpenHadith,
    this.onOpenSaved,
    this.onToggleTheme,
  }) : super(key: key);

  /// هل تبويب الرئيسية ظاهر الآن؟ (لتحديث البيانات عند الرجوع إليه)
  final bool active;

  /// يتغيّر عند الرجوع من صفحة فرعية لتحديث البيانات
  final int refreshTick;
  final VoidCallback? onGoToQuran;
  final VoidCallback? onGoToTilawa;
  final VoidCallback? onGoToTasbih;
  final VoidCallback? onOpenAdhkar;
  final VoidCallback? onOpenHadith;
  final VoidCallback? onOpenSaved;
  final VoidCallback? onToggleTheme;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _lastRead;
  late StreakInfo _streak;
  int _bookmarkCount = 0;

  // آية اليوم (ثابتة — يمكن تحويلها لديناميكية لاحقاً)
  static const String _dailyAyahText =
      '﴿ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ ﴾';
  static const String _dailyAyahRef = 'الرعد • ٢٨';
  static const int _dailySurahNumber = 13;
  static const int _dailyAyahNumber = 28;

  @override
  void initState() {
    super.initState();
    TasbihService.load();
    _streak = TasbihService.streak();
    _lastRead = StorageService.getLastRead();
    _bookmarkCount = StorageService.getBookmarks().length;
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.active && !oldWidget.active) ||
        widget.refreshTick != oldWidget.refreshTick) {
      // لا نستدعي setState هنا: البناء يحدث مباشرة بعد didUpdateWidget
      _refreshData();
    }
  }

  void _refreshData() {
    _lastRead = StorageService.getLastRead();
    _streak = TasbihService.streak();
    _bookmarkCount = StorageService.getBookmarks().length;
  }

  void _reload() {
    setState(_refreshData);
  }

  // ============================================================
  // مشاركة آية اليوم
  // ============================================================
  Future<void> _shareDailyAyah() async {
    final text = '$_dailyAyahText\n\n$_dailyAyahRef';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الآية — الصقها في أي تطبيق')),
    );
  }

  // ============================================================
  // حفظ آية اليوم في المفضلة
  // ============================================================
  Future<void> _bookmarkDailyAyah() async {
    final isMarked = StorageService.isBookmarked(
      _dailySurahNumber,
      _dailyAyahNumber,
    );
    if (isMarked) {
      await StorageService.removeBookmark(
        _dailySurahNumber,
        _dailyAyahNumber,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إزالة الآية من المحفوظات')),
      );
    } else {
      await StorageService.addBookmark(
        surahNumber: _dailySurahNumber,
        surahName: 'الرعد',
        ayahNumber: _dailyAyahNumber,
        ayahText: _dailyAyahText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الآية')),
      );
    }
    setState(() {
      _bookmarkCount = StorageService.getBookmarks().length;
    });
  }

  void _openSurah(int number, String name) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ReaderPage(surahNumber: number, surahName: name),
          ),
        )
        .then((_) {
      if (mounted) _reload();
    });
  }

  void _call(VoidCallback? cb) {
    if (cb != null) cb();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final zikr = kAdhkar[dayIndexOf(kAdhkar.length)].text;
    final hadith = kHadith[dayIndexOf(kHadith.length)];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: <Widget>[
            // ============ الرأس ============
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      Text('السلام عليكم', style: TextStyle(fontSize: 15)),
                      SizedBox(height: 4),
                      Text(
                        'رفيقك مع القرآن',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_streak.current > 0)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _call(widget.onGoToTasbih),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: AppTints.sand(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Opacity(
                        opacity: _streak.todayDone ? 1.0 : 0.7,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_rounded,
                                size: 20, color: AppTints.flame(context)),
                            const SizedBox(width: 4),
                            Text(
                              arNum(_streak.current),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTints.onSand(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _call(widget.onToggleTheme),
                  child: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ============ بطاقة "متابعة القراءة" ============
            _buildContinueCard(scheme),

            const SizedBox(height: 28),

            // ============ أقسام أثر القرآن ============
            const _SectionHeader(title: 'أقسام أثر القرآن'),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _QuickAction(
                    icon: Icons.menu_book_rounded,
                    title: 'المصحف',
                    subtitle: '١١٤ سورة',
                    color: scheme.primaryContainer,
                    onColor: scheme.onPrimaryContainer,
                    onTap: () => _call(widget.onGoToQuran),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.headphones_rounded,
                    title: 'التلاوات',
                    subtitle: '١٠ قراء',
                    color: scheme.secondaryContainer,
                    onColor: scheme.onSecondaryContainer,
                    onTap: () => _call(widget.onGoToTilawa),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _QuickAction(
                    icon: Icons.blur_circular_rounded,
                    title: 'التسبيح',
                    subtitle: 'عدّاد وستريك',
                    color: AppTints.sky(context),
                    onColor: AppTints.onSky(context),
                    onTap: () => _call(widget.onGoToTasbih),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.favorite_rounded,
                    title: 'الأذكار',
                    subtitle: '${arNum(kAdhkar.length)} ذكر',
                    color: AppTints.sand(context),
                    onColor: AppTints.onSand(context),
                    onTap: () => _call(widget.onOpenAdhkar),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _QuickAction(
                    icon: Icons.format_quote_rounded,
                    title: 'الأحاديث',
                    subtitle: '${arNum(kHadith.length)} حديث',
                    color: scheme.primaryContainer,
                    onColor: scheme.onPrimaryContainer,
                    onTap: () => _call(widget.onOpenHadith),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.bookmark_rounded,
                    title: 'المحفوظات',
                    subtitle: _bookmarkCount > 0
                        ? '${arNum(_bookmarkCount)} آية'
                        : 'آياتك المفضلة',
                    color: scheme.secondaryContainer,
                    onColor: scheme.onSecondaryContainer,
                    onTap: () => _call(widget.onOpenSaved),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ============ آية اليوم ============
            const _SectionHeader(title: 'آية اليوم'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTints.card(context),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  GestureDetector(
                    onTap: () => _openSurah(_dailySurahNumber, 'الرعد'),
                    child: Text(
                      _dailyAyahText,
                      style: TextStyle(
                        fontSize: 22,
                        height: 1.8,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    _dailyAyahRef,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 22),
                        color: scheme.primary,
                        tooltip: 'مشاركة',
                        onPressed: _shareDailyAyah,
                      ),
                      IconButton(
                        icon: Icon(
                          StorageService.isBookmarked(
                                  _dailySurahNumber, _dailyAyahNumber)
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 22,
                        ),
                        color: scheme.primary,
                        tooltip: 'حفظ',
                        onPressed: _bookmarkDailyAyah,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () =>
                            _openSurah(_dailySurahNumber, 'الرعد'),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('فتح السورة'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ============ ذكر وحديث اليوم ============
            const _SectionHeader(title: 'ذكر وحديث اليوم'),
            const SizedBox(height: 12),
            _DailyTextCard(
              icon: Icons.favorite_rounded,
              label: 'ذكر',
              text: zikr,
            ),
            const SizedBox(height: 12),
            _DailyTextCard(
              icon: Icons.format_quote_rounded,
              label: 'حديث',
              text: hadith,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // بطاقة "متابعة القراءة"
  // ============================================================
  Widget _buildContinueCard(ColorScheme scheme) {
    if (_lastRead == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.auto_awesome_rounded,
                    color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  'ابدأ رحلتك',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'لم تبدأ القراءة بعد',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'افتح المصحف وابدأ من سورة الفاتحة',
              style: TextStyle(
                color: scheme.onPrimaryContainer.withOpacity(.75),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _openSurah(1, 'الفاتحة'),
              child: const Text('ابدأ القراءة'),
            ),
          ],
        ),
      );
    }

    final surahNumber = _lastRead!['surahNumber'] as int? ?? 1;
    final surahName = _lastRead!['surahName'] as String? ?? 'الفاتحة';
    final ayahNumber = _lastRead!['ayahNumber'] as int? ?? 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, color: scheme.onPrimary),
              const SizedBox(width: 8),
              Text(
                'مواصلة الورد',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'سورة $surahName',
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'الآية ${arNum(ayahNumber)}',
            style: TextStyle(
              color: scheme.onPrimary.withOpacity(.75),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => _openSurah(surahNumber, surahName),
            child: const Text('متابعة القراءة'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// عناصر مساعدة
// ============================================================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onColor,
    this.onTap,
  }) : super(key: key);

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color onColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: onColor),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: onColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: onColor.withOpacity(.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyTextCard extends StatelessWidget {
  const _DailyTextCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.text,
  }) : super(key: key);

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTints.card(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, height: 1.9),
          ),
        ],
      ),
    );
  }
}
