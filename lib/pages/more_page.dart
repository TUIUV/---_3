import 'package:flutter/material.dart';
import '../theme.dart';

/// صفحة "المزيد": الأذكار، الأحاديث، المحفوظات، الإعدادات
class MorePage extends StatelessWidget {
  const MorePage({
    Key? key,
    required this.onOpenAdhkar,
    required this.onOpenHadith,
    required this.onOpenSaved,
    required this.onOpenSettings,
  }) : super(key: key);

  final VoidCallback onOpenAdhkar;
  final VoidCallback onOpenHadith;
  final VoidCallback onOpenSaved;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المزيد',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: <Widget>[
          const Text(
            'الأقسام',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppTints.card(context),
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                _tile(
                  context,
                  Icons.favorite_rounded,
                  'الأذكار',
                  'أذكار وأدعية مع علامة الإنجاز',
                  onOpenAdhkar,
                ),
                const Divider(height: 1),
                _tile(
                  context,
                  Icons.format_quote_rounded,
                  'الأحاديث',
                  'حديث اليوم ومجموعة أحاديث',
                  onOpenHadith,
                ),
                const Divider(height: 1),
                _tile(
                  context,
                  Icons.bookmark_rounded,
                  'المحفوظات',
                  'آياتك المحفوظة وملاحظاتك',
                  onOpenSaved,
                ),
                const Divider(height: 1),
                _tile(
                  context,
                  Icons.settings_rounded,
                  'الإعدادات',
                  'المظهر وحجم الخط والقارئ',
                  onOpenSettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'أثر القرآن — ذكر الله طمأنينة القلوب',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'تواصل معنا: @scs_.f',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
