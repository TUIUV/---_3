/// أدوات مساعدة للنصوص العربية والتواريخ
const List<String> _arDigits = <String>[
  '٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'
];

/// تحويل الأرقام إلى أرقام عربية
String arNum(int number) {
  final s = number.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final code = s.codeUnitAt(i);
    if (code >= 48 && code <= 57) {
      buf.write(_arDigits[code - 48]);
    } else {
      buf.write(s[i]);
    }
  }
  return buf.toString();
}

/// مفتاح اليوم بصيغة yyyy-MM-dd حسب توقيت الجهاز
String dayKeyOf(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// اليوم قبل [daysAgo] يوماً (0 = اليوم)
DateTime dayAgo(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo);
}

/// رقم اليوم (للتبديل اليومي بين الأذكار والأحاديث)
int dayIndexOf(int length) {
  if (length <= 0) return 0;
  final now = DateTime.now();
  final days =
      DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
          86400000;
  return days % length;
}

/// اسم اليوم بالعربية (weekday: 1=الاثنين ... 7=الأحد)
String arWeekday(int weekday) {
  const names = <String>[
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  return names[(weekday - 1) % 7];
}
