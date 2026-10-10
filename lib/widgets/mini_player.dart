import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../pages/player_page.dart';
import '../services/audio_service.dart';

/// مشغل مصغّر يظهر أعلى شريط التنقل عند وجود تلاوة
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _playSub;
  StreamSubscription? _stateSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _playing = AudioService.isPlaying;
    _position = AudioService.position;
    _duration = AudioService.duration ?? Duration.zero;
    _posSub = AudioService.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = AudioService.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
    _playSub = AudioService.playingStream.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
    _stateSub = AudioService.processingStateStream.listen((s) {
      if (mounted) {
        setState(() {
          _loading =
              s == ProcessingState.loading || s == ProcessingState.buffering;
        });
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await AudioService.pause();
    } else {
      await AudioService.resume();
    }
  }

  Future<void> _skip(int seconds) async {
    if (_duration == Duration.zero) return;
    final target = _position.inSeconds + seconds;
    final max = _duration.inSeconds;
    final int clamped = target < 0 ? 0 : (target > max ? max : target);
    await AudioService.seek(Duration(seconds: clamped));
  }

  void _openPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AudioService.hasAudio || AudioService.currentSurahNumber == 0) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;
    final reciterName = AudioService.currentReciter?.name ?? '';

    return Material(
      color: scheme.surfaceVariant,
      child: InkWell(
        onTap: _openPlayer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: scheme.surfaceVariant,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _loading ? null : _toggle,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: _loading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      scheme.onPrimary),
                                ),
                              )
                            : Icon(
                                _playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 24,
                                color: scheme.onPrimary,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سورة ${AudioService.currentSurahName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.mic_rounded,
                                size: 12, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                reciterName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    iconSize: 22,
                    tooltip: '10 ثواني للخلف',
                    icon: const Icon(Icons.replay_10_rounded),
                    onPressed: _loading ? null : () => _skip(-10),
                  ),
                  IconButton(
                    iconSize: 22,
                    tooltip: '10 ثواني للأمام',
                    icon: const Icon(Icons.forward_10_rounded),
                    onPressed: _loading ? null : () => _skip(10),
                  ),
                  Icon(Icons.keyboard_arrow_up_rounded,
                      color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
