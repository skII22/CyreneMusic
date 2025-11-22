import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/player_service.dart';
import '../../models/track.dart';
import '../../models/lyric_line.dart';
import 'player_background.dart';
import 'player_window_controls.dart';
import 'player_fluid_cloud_lyrics_panel.dart';

/// 流体云全屏布局
/// 模仿 Apple Music 的左右分栏设计
/// 左侧：封面、信息、控制
/// 右侧：沉浸式歌词
class PlayerFluidCloudLayout extends StatelessWidget {
  final List<LyricLine> lyrics;
  final int currentLyricIndex;
  final bool showTranslation;
  final bool isMaximized;
  final VoidCallback onBackPressed;
  final VoidCallback onPlaylistPressed;
  final VoidCallback onVolumeControlPressed;

  const PlayerFluidCloudLayout({
    super.key,
    required this.lyrics,
    required this.currentLyricIndex,
    required this.showTranslation,
    required this.isMaximized,
    required this.onBackPressed,
    required this.onPlaylistPressed,
    required this.onVolumeControlPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 全局背景
        const PlayerBackground(),
        
        // 2. 玻璃拟态遮罩 (整个容器)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.black.withOpacity(0.2), // 降低亮度以突出内容
            ),
          ),
        ),

        // 3. 主要内容区域
        SafeArea(
          child: Column(
            children: [
              // 顶部窗口控制
              PlayerWindowControls(
                isMaximized: isMaximized,
                onBackPressed: onBackPressed,
              ),
              
              // 主体布局 (左右分栏)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 左侧：控制面板 (固定宽度或比例)
                      SizedBox(
                        width: 400,
                        child: _buildLeftPanel(context),
                      ),
                      
                      // 间距
                      const SizedBox(width: 60),
                      
                      // 右侧：歌词面板 (自适应)
                      Expanded(
                        child: _buildRightPanel(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建左侧面板
  Widget _buildLeftPanel(BuildContext context) {
    final player = PlayerService();
    final song = player.currentSong;
    final track = player.currentTrack;
    final imageUrl = song?.pic ?? track?.picUrl ?? '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center, // 居中对齐
      children: [
        // 1. 专辑封面
        AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[900]),
                    errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                  )
                : Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
                  ),
          ),
        ),
        
        const SizedBox(height: 40),
        
        // 2. 歌曲信息
        Text(
          track?.name ?? '未知歌曲',
          textAlign: TextAlign.center, // 居中
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
            fontFamily: 'Microsoft YaHei',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          track?.artists ?? '未知歌手',
          textAlign: TextAlign.center, // 居中
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.6),
            fontFamily: 'Microsoft YaHei',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 30),
        
        // 3. 进度条
        AnimatedBuilder(
          animation: player,
          builder: (context, _) {
            final position = player.position.inMilliseconds.toDouble();
            final duration = player.duration.inMilliseconds.toDouble();
            final value = (duration > 0) ? (position / duration).clamp(0.0, 1.0) : 0.0;
            
            return Column(
              children: [
                // 自定义半透明进度条
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    // 移除头部的圆形 Thumb
                    thumbShape: SliderComponentShape.noThumb,
                    // 移除 Overlay
                    overlayShape: SliderComponentShape.noOverlay,
                    // 激活部分：高亮白
                    activeTrackColor: Colors.white.withOpacity(0.9),
                    // 未激活部分：半透明白，形成明显区分
                    inactiveTrackColor: Colors.white.withOpacity(0.2),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: value,
                    onChanged: (v) {
                      final pos = Duration(milliseconds: (v * duration).round());
                      player.seek(pos);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(player.position),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5), 
                          fontSize: 12,
                          fontFamily: 'Consolas',
                        ),
                      ),
                      Text(
                        _formatDuration(player.duration),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5), 
                          fontSize: 12,
                          fontFamily: 'Consolas',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        ),
        
        const SizedBox(height: 20),
        
        // 4. 控制按钮 (居中，作为一个整体)
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min, // 紧凑排列，整体居中
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 上一首
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                color: Colors.white,
                iconSize: 36,
                onPressed: player.hasPrevious ? player.playPrevious : null,
              ),
              const SizedBox(width: 20),
              
              // 播放/暂停
              AnimatedBuilder(
                animation: player,
                builder: (context, _) {
                  return Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2), // 半透明背景
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      color: Colors.white,
                      iconSize: 40, 
                      onPressed: player.togglePlayPause,
                    ),
                  );
                }
              ),
              const SizedBox(width: 20),
              
              // 下一首
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                color: Colors.white,
                iconSize: 36,
                onPressed: player.hasNext ? player.playNext : null,
              ),
            ],
          ),
        ),
        
        // 列表按钮 (单独一行，或者放到其他位置？这里为了保持整体居中，可以放在最下面或者做成绝对定位)
        // 用户只说了上一首/播放/下一首要居中。列表按钮原先在右侧。
        // 为了美观，可以把列表按钮放在控制按钮下面，或者左下/右下角
        // 这里暂时把它放在控制按钮下方，居中，作为一个辅助按钮
        const SizedBox(height: 20),
        Center(
          child: IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            color: Colors.white.withOpacity(0.6),
            iconSize: 24,
            onPressed: onPlaylistPressed,
            tooltip: '播放列表',
          ),
        ),
      ],
    );
  }

  /// 构建右侧面板 (歌词)
  Widget _buildRightPanel() {
    // 使用 ShaderMask 实现上下淡入淡出
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.15, 0.85, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: PlayerFluidCloudLyricsPanel(
        lyrics: lyrics,
        currentLyricIndex: currentLyricIndex,
        showTranslation: showTranslation,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

