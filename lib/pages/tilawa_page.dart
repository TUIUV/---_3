import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/reciter.dart';
import '../models/surah.dart';
import '../services/audio_service.dart';
import '../services/quran_api.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../utils/ar.dart';

/// صفحة التلاوات: اختر القارئ ثم اضغط على السورة للاستماع
class TilawaPage extends StatefulWidget {
  const TilawaPage({Key? key}) : super(key: key);

  @override
  State<TilawaPage> createState() => _TilawaPageState();
}

class _TilawaPageState extends State<TilawaPage> {
  List<Surah> _all = <Surah>[];
  List<Surah> _filtered = <Surah>[];
  bool _loading = true;
  String? _error;
  late Reciter _reciter;
  final TextEditingController _search = TextEditingController();

  StreamSubscription? _playSub;
  StreamSubscription? _stateSub;
  bool _playing = false;
  bool _buffering = false;

  @override
  void initState() {
    super.initState();
    final reciters = QuranApi.getReciters();
    final prefId = StorageService.getPreferredReciter();
    _reciter = reciters.firstWhere(
      (r) => r.identifier == prefId,
      orElse: () => reciters.first,
    );
    _playing = AudioService.isPlaying;
    _playSub = AudioService.playingStream.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
    _stateSub = AudioService.processingStateStream.listen((s) {
      if (mounted) {
        setState(() {
          _buffering =
              s == ProcessingState.loading || s == ProcessingState.buffering;
        });
      }
    });
    _loadSurahs();
  }

  @override
  void dispose() {
    _playSub?.cancel();
    _stateSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final cached = StorageService.getSurahsCache();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _all = cached;
        _filtered = cached;
        _loading = false;
      });
      return;
    }
    try {
      final surahs = await QuranApi.fetchSurahs();
      await StorageService.saveSurahsCache(surahs);
      if (!mounted) return;
      setState(() {
        _all = surahs;
        _filtered = surahs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل السور. تأكد من الاتصال بالإنترنت.';
        _loading = false;
      });
    }
  }

  void _onSearch(String q) {
    setState(() {
      _filtered = QuranApi.searchSurahs(_all, q);
    });
  }

  String _displayName(Surah s) => s.name.replaceAll('سُورَةُ ', '');

  Future<void> _playOrToggle(Surah s) async {
    final isCurrent = AudioService.currentSurahNumber == s.number &&
        AudioService.currentReciter?.identifier == _reciter.identifier;
    if (isCurrent) {
      if (_playing) {
        await AudioService.pause();
      } else {
        await AudioService.resume();
      }
      return;
    }
    final ok = await AudioService.playSurah(
      _reciter,
      s.number,
      surahName: _displayName(s),
    );
    if (!mounted) return;
    if (ok) {
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل التلاوة — تحقق من الاتصال')),
      );
    }
  }

  void _pickReciter() {
    final reciters = QuranApi.getReciters();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Container(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withOpacity(.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.mic_rounded, color: scheme.primary),
                      const SizedBox(width: 10),
                      const Text(
                        'اختر القارئ',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: reciters.length,
                    itemBuilder: (_, i) {
                      final r = reciters[i];
                      final selected = r.identifier == _reciter.identifier;
                      return ListTile(
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        title: Text(
                          r.name,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(r.englishName),
                        onTap: () {
                          Navigator.pop(ctx);
                          _setReciter(r);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setReciter(Reciter r) async {
    setState(() => _reciter = r);
    await StorageService.setPreferredReciter(r.identifier);
    if (AudioService.currentSurahNumber != 0) {
      await AudioService.changeReciter(r);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'التلاوات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 64, color: scheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadSurahs,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      children: <Widget>[
        _buildHero(scheme),
        const SizedBox(height: 18),
        TextField(
          controller: _search,
          onChanged: _onSearch,
          decoration: const InputDecoration(
            hintText: 'ابحث عن سورة للاستماع',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            const Text(
              'السور',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              '${arNum(_filtered.length)} من ${arNum(_all.length)}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._filtered.map((s) => _buildRow(s, scheme)),
      ],
    );
  }

  Widget _buildHero(ColorScheme scheme) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c1 = dark ? const Color(0xFF0E6B53) : scheme.primary;
    final c2 = dark
        ? const Color(0xFF1C8F70)
        : Color.alphaBlend(Colors.white.withOpacity(.4), scheme.primary);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c1, c2],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'استمع إلى القرآن الكريم',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'اختر القارئ ثم اضغط على السورة للاستماع',
            style: TextStyle(color: Colors.white.withOpacity(.85)),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _pickReciter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _reciter.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more_rounded,
                      size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Surah s, ColorScheme scheme) {
    final isCurrent = AudioService.currentSurahNumber == s.number &&
        AudioService.currentReciter?.identifier == _reciter.identifier;
    final isPlayingThis = isCurrent && _playing;
    final isLoadingThis = isCurrent && _buffering && !_playing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isCurrent ? scheme.primaryContainer : AppTints.card(context),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _playOrToggle(s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isCurrent
                      ? scheme.primary
                      : scheme.primaryContainer,
                  child: Text(
                    arNum(s.number),
                    style: TextStyle(
                      color: isCurrent
                          ? scheme.onPrimary
                          : scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(s),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isCurrent
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.revelationArabic} • ${arNum(s.numberOfAyahs)} آية',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? scheme.primary
                        : scheme.secondaryContainer,
                  ),
                  child: isLoadingThis
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                scheme.onPrimary),
                          ),
                        )
                      : Icon(
                          isPlayingThis
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: isCurrent
                              ? scheme.onPrimary
                              : scheme.onSecondaryContainer,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
