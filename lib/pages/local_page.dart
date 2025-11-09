import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../services/local_library_service.dart';
import '../services/player_service.dart';
import '../models/track.dart';
import '../utils/theme_manager.dart';

class LocalPage extends StatefulWidget {
  const LocalPage({super.key});

  @override
  State<LocalPage> createState() => _LocalPageState();
}

// === Fluent helpers ===
extension on _LocalPageState {
  void _showFluentInfo(String text, [fluent.InfoBarSeverity severity = fluent.InfoBarSeverity.info]) {
    _infoBarTimer?.cancel();
    setState(() {
      _fluentInfoText = text;
      _fluentInfoSeverity = severity;
    });
    _infoBarTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _fluentInfoText = null;
      });
    });
  }

  Widget _buildFluentEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(fluent.FluentIcons.folder, size: 80),
          SizedBox(height: 12),
          Text('未选择本地音乐', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('可选择单首歌曲或扫描整个文件夹（支持 mp3/wav/flac 等）', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _extOf(dynamic id) {
    if (id is String) {
      final idx = id.lastIndexOf('.');
      if (idx > 0 && idx < id.length - 1) {
        return id.substring(idx + 1).toUpperCase();
      }
    }
    return '';
  }

  Widget _buildFluentTrackTile(Track track) {
    final theme = fluent.FluentTheme.of(context);
    return fluent.Card(
      padding: EdgeInsets.zero,
      child: fluent.ListTile(
        leading: _buildFluentCover(theme, track),
        title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('本地 • ${_extOf(track.id)}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: fluent.IconButton(
          icon: const Icon(fluent.FluentIcons.play),
          onPressed: () async {
            await PlayerService().playTrack(track);
            _showFluentInfo('正在播放: ${track.name}');
          },
        ),
        onPressed: () async {
          await PlayerService().playTrack(track);
          _showFluentInfo('正在播放: ${track.name}');
        },
      ),
    );
  }

  Widget _buildFluentCover(fluent.FluentThemeData theme, Track track) {
    if (track.picUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: track.picUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 48,
            height: 48,
            color: theme.resources.controlAltFillColorSecondary,
          ),
          errorWidget: (context, url, error) => Container(
            width: 48,
            height: 48,
            color: theme.resources.controlAltFillColorSecondary,
            child: Icon(
              fluent.FluentIcons.music_in_collection,
              color: theme.resources.textFillColorTertiary,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.resources.controlAltFillColorSecondary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        fluent.FluentIcons.music_in_collection,
        color: theme.resources.textFillColorTertiary,
      ),
    );
  }
}

class _LocalPageState extends State<LocalPage> {
  final LocalLibraryService _local = LocalLibraryService();
  final ThemeManager _themeManager = ThemeManager();
  String? _fluentInfoText;
  fluent.InfoBarSeverity _fluentInfoSeverity = fluent.InfoBarSeverity.info;
  Timer? _infoBarTimer;

  @override
  void initState() {
    super.initState();
    _local.addListener(_onChanged);
  }

  @override
  void dispose() {
    _local.removeListener(_onChanged);
    _infoBarTimer?.cancel();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_themeManager.isFluentFramework) {
      return _buildFluentPage(context);
    }
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: colorScheme.surface,
            title: Text(
              '本地',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.audio_file),
                tooltip: '选择单首歌曲',
                onPressed: () async {
                  await _local.pickSingleSong();
                },
              ),
              IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: '选择文件夹并扫描',
                onPressed: () async {
                  await _local.pickAndScanFolder();
                },
              ),
              if (_local.tracks.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: '清空列表',
                  onPressed: () {
                    _local.clear();
                  },
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: _local.tracks.isEmpty
                ? SliverToBoxAdapter(child: _buildEmpty())
                : SliverList.builder(
                    itemCount: _local.tracks.length,
                    itemBuilder: (context, index) {
                      final track = _local.tracks[index];
                      return _LocalTrackTile(track: track);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluentPage(BuildContext context) {
    final tracks = _local.tracks;
    return fluent.ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                const Text(
                  '本地',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                fluent.IconButton(
                  icon: const Icon(fluent.FluentIcons.music_in_collection),
                  onPressed: () async {
                    await _local.pickSingleSong();
                  },
                ),
                const SizedBox(width: 6),
                fluent.IconButton(
                  icon: const Icon(fluent.FluentIcons.folder_open),
                  onPressed: () async {
                    await _local.pickAndScanFolder();
                  },
                ),
                if (tracks.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  fluent.IconButton(
                    icon: const Icon(fluent.FluentIcons.delete),
                    onPressed: () {
                      _local.clear();
                      _showFluentInfo('已清空');
                    },
                  ),
                ],
              ],
            ),
          ),
          if (_fluentInfoText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: fluent.InfoBar(
                title: Text(_fluentInfoText!),
                severity: _fluentInfoSeverity,
                isLong: false,
              ),
            ),
          Expanded(
            child: tracks.isEmpty
                ? _buildFluentEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemBuilder: (context, index) => _buildFluentTrackTile(tracks[index]),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: tracks.length,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('未选择本地音乐', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '可选择单首歌曲或扫描整个文件夹（支持 mp3/wav/flac 等）',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LocalTrackTile extends StatelessWidget {
  final Track track;
  const _LocalTrackTile({required this.track});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _buildCover(cs),
        title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('本地 • ${_extOf(track.id)}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () async {
            await PlayerService().playTrack(track);
          },
          tooltip: '播放',
        ),
        onTap: () async {
          await PlayerService().playTrack(track);
        },
      ),
    );
  }

  Widget _buildCover(ColorScheme cs) {
    if (track.picUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: track.picUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.music_note, color: cs.onSurfaceVariant),
    );
  }

  String _extOf(dynamic id) {
    if (id is String) {
      final idx = id.lastIndexOf('.');
      if (idx > 0 && idx < id.length - 1) return id.substring(idx + 1).toUpperCase();
    }
    return '';
  }
}


