import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'; // 导入 dart:ui 以使用 ImageFilter
import 'package:flutter/material.dart';
import '../../services/player_service.dart';
import '../../models/lyric_line.dart';

/// 流体云样式歌词面板
/// 云朵般柔和流动的歌词效果
class PlayerFluidCloudLyricsPanel extends StatefulWidget {
  final List<LyricLine> lyrics;
  final int currentLyricIndex;
  final bool showTranslation;

  const PlayerFluidCloudLyricsPanel({
    super.key,
    required this.lyrics,
    required this.currentLyricIndex,
    required this.showTranslation,
  });

  @override
  State<PlayerFluidCloudLyricsPanel> createState() => _PlayerFluidCloudLyricsPanelState();
}

class _PlayerFluidCloudLyricsPanelState extends State<PlayerFluidCloudLyricsPanel> 
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  int? _selectedLyricIndex; // 手动选择的歌词索引
  bool _isManualMode = false; // 是否处于手动模式
  Timer? _autoResetTimer; // 自动回退定时器
  AnimationController? _timeCapsuleAnimationController;
  Animation<double>? _timeCapsuleFadeAnimation;
  
  // 流体动画控制器
  late AnimationController _fluidAnimationController;
  late Animation<double> _fluidAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _autoResetTimer?.cancel();
    _timeCapsuleAnimationController?.dispose();
    _fluidAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 初始化动画
  void _initializeAnimations() {
    // 时间胶囊动画
    _timeCapsuleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _timeCapsuleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _timeCapsuleAnimationController!,
      curve: Curves.easeInOut,
    ));
    
    // 流体动画（持续循环）
    _fluidAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _fluidAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fluidAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(PlayerFluidCloudLyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果当前播放索引变化且不处于手动模式，则滚动
    if (widget.currentLyricIndex != oldWidget.currentLyricIndex && !_isManualMode) {
      _scrollToCurrentLyric();
    }
  }

  /// 滚动到当前歌词
  void _scrollToCurrentLyric() {
    if (!_scrollController.hasClients) return;
    
    // 简单的滚动计算，具体在 ListView 的 itemExtent 配合下会更准
    // 这里我们将在 LayoutBuilder 中计算 itemHeight 后再执行精确滚动
    // 但由于 didUpdateWidget 在 build 之前，可能拿不到最新的 itemHeight
    // 所以我们在 build 中也会检查滚动
    setState(() {}); // 触发 build 以重新计算滚动位置
  }

  /// 开始手动模式
  void _startManualMode() {
    if (_isManualMode) {
      _resetAutoTimer();
      return;
    }

    setState(() {
      _isManualMode = true;
    });
    
    _timeCapsuleAnimationController?.forward();
    _resetAutoTimer();
  }

  /// 重置自动回退定时器
  void _resetAutoTimer() {
    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(const Duration(seconds: 4), _exitManualMode);
  }

  /// 退出手动模式
  void _exitManualMode() {
    if (!mounted) return;
    
    setState(() {
      _isManualMode = false;
      _selectedLyricIndex = null;
    });
    
    _timeCapsuleAnimationController?.reverse();
    _autoResetTimer?.cancel();
    
    // 退出手动模式后，立即滚回当前歌词
    _scrollToCurrentLyric();
  }

  /// 跳转到选中的歌词时间
  void _seekToSelectedLyric() {
    if (_selectedLyricIndex != null && 
        _selectedLyricIndex! >= 0 && 
        _selectedLyricIndex! < widget.lyrics.length) {
      
      final selectedLyric = widget.lyrics[_selectedLyricIndex!];
      if (selectedLyric.startTime != null) {
        PlayerService().seek(selectedLyric.startTime!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已跳转到: ${selectedLyric.text}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
    
    _exitManualMode();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.zero, 
      child: Stack(
        children: [
          // 主要歌词区域
          widget.lyrics.isEmpty
              ? _buildNoLyric()
              : _buildFluidCloudLyricList(),
          
          // 时间胶囊组件 (当手动模式开启且选中的索引有效时显示)
          if (_isManualMode && _selectedLyricIndex != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _buildTimeCapsule(),
            ),
        ],
      ),
    );
  }

  /// 构建无歌词提示
  Widget _buildNoLyric() {
    return ValueListenableBuilder<Color?>(
      valueListenable: PlayerService().themeColorNotifier,
      builder: (context, themeColor, child) {
        final textColor = _getAdaptiveLyricColor(themeColor, false).withOpacity(0.5);
        return Center(
          child: Text(
            '暂无歌词',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
            ),
          ),
        );
      },
    );
  }

  /// 构建流体云样式歌词列表
  Widget _buildFluidCloudLyricList() {
    return RepaintBoundary(
      child: ValueListenableBuilder<Color?>(
        valueListenable: PlayerService().themeColorNotifier,
        builder: (context, themeColor, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              const int visibleLines = 7;
              final itemHeight = constraints.maxHeight / visibleLines;
              final viewportHeight = constraints.maxHeight;
              
              // 确保在非手动模式下滚动到正确位置
              // 使用 addPostFrameCallback 避免在 build 过程中调用 scroll
              if (!_isManualMode && _scrollController.hasClients) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                   if (_scrollController.hasClients) {
                     // 由于设置了 padding 使得首行居中，所以直接滚动到 index * itemHeight 即可让对应行居中
                     final targetOffset = widget.currentLyricIndex * itemHeight;
                     
                     // 如果距离太远，直接跳转，否则动画
                     if ((_scrollController.offset - targetOffset).abs() > viewportHeight * 2) {
                        _scrollController.jumpTo(targetOffset);
                     } else {
                        _scrollController.animateTo(
                          targetOffset,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                        );
                     }
                   }
                });
              }
              
              return NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification && 
                      notification.dragDetails != null) {
                    // 用户开始拖动
                    _startManualMode();
                  } else if (notification is ScrollUpdateNotification) {
                    if (_isManualMode) {
                      // 计算当前中心点的歌词索引
                      final centerOffset = _scrollController.offset + (viewportHeight / 2);
                      final index = (centerOffset / itemHeight).floor();
                      
                      if (index >= 0 && index < widget.lyrics.length && index != _selectedLyricIndex) {
                        setState(() {
                          _selectedLyricIndex = index;
                        });
                      }
                      _resetAutoTimer();
                    }
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: widget.lyrics.length,
                  itemExtent: itemHeight, // 固定高度优化性能
                  // 添加内边距，确保第一行和最后一行能居中
                  padding: EdgeInsets.symmetric(
                    vertical: (viewportHeight - itemHeight) / 2
                  ),
                  physics: const BouncingScrollPhysics(), // iOS 风格回弹
                  itemBuilder: (context, index) {
                    // 根据是否手动模式决定高亮逻辑
                    // 手动模式：高亮手动选中的行 (_selectedLyricIndex) - 可选，这里为了体验保持高亮当前播放行，但选中行有视觉反馈
                    // 自动模式：高亮当前播放行 (widget.currentLyricIndex)
                    
                    // 为了流体效果，我们需要计算每一行相对于"中心"的距离
                    // 在 ListView 中，我们无法直接得知每一行渲染时的位置，
                    // 但我们可以基于索引距离来模拟。
                    
                    // 决定"中心索引"：如果是手动模式，以选中的为准(视觉中心)；否则以当前播放的为准
                    // 但实际上 ListView 在滚动，所以视觉中心总是 Viewport 中间
                    // 我们希望高亮的是：处于 Viewport 中间的那一行
                    
                    // 这里简化逻辑：
                    // 高亮行 = 当前播放行 (始终高亮播放行，还是高亮视觉中心行？)
                    // Apple Music 逻辑：滚动时，高亮保持在播放行，但变暗。
                    // 我们这里：
                    // 1. 播放行始终最亮
                    // 2. 其他行根据距离播放行的距离衰减
                    
                    final lyric = widget.lyrics[index];
                    final isActuallyPlaying = index == widget.currentLyricIndex;
                    
                    // 计算视觉距离 (用于模糊和缩放)
                    // 在自动模式下，当前播放行在中心，距离 = (index - current).abs()
                    // 在手动模式下，用户滚动了，当前播放行可能不在中心
                    
                    // 我们使用逻辑距离：
                    // 如果是手动模式，我们希望用户关注他滚到的位置吗？
                    // 还是保持播放行高亮？
                    // 参考之前的逻辑：
                    // isCurrent = index == displayIndex
                    // displayIndex = _selectedLyricIndex ?? widget.currentLyricIndex
                    
                    final displayIndex = _isManualMode && _selectedLyricIndex != null 
                        ? _selectedLyricIndex! 
                        : widget.currentLyricIndex;
                    
                    final distance = (index - displayIndex).abs();
                    
                    // 视觉参数
                    final opacity = (1.0 - (distance * 0.4)).clamp(0.1, 1.0);
                    final scale = (1.0 - (distance * 0.05)).clamp(0.90, 1.0);
                    final blur = distance == 0 ? 0.0 : 1.5;
                    
                    return Center(
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                            child: isActuallyPlaying // 只有真正播放的行才用高亮样式
                                ? _buildFluidCloudLyricLine(
                                    lyric, 
                                    themeColor, 
                                    itemHeight, 
                                    true
                                  )
                                : _buildNormalLyricLine(
                                    lyric, 
                                    themeColor, 
                                    itemHeight
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 构建流体云样式的歌词行（当前歌词）
  Widget _buildFluidCloudLyricLine(
    LyricLine lyric, 
    Color? themeColor, 
    double itemHeight, 
    bool isActuallyPlaying
  ) {
    return AnimatedBuilder(
      animation: Listenable.merge([PlayerService(), _fluidAnimation]),
      builder: (context, child) {
        final isSelected = _isManualMode && !isActuallyPlaying; 
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center, // 居中
            children: [
              // 原文歌词 - 流体云效果
              _buildFluidCloudText(
                text: lyric.text,
                fontSize: 20,
                themeColor: themeColor,
                isSelected: isSelected,
                isPlaying: isActuallyPlaying,
              ),
              
              // 翻译歌词
              if (widget.showTranslation && 
                  lyric.translation != null && 
                  lyric.translation!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    lyric.translation!,
                    textAlign: TextAlign.center, // 居中
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _getAdaptiveLyricColor(themeColor, false)
                          .withOpacity(0.7),
                      fontSize: 14,
                      fontFamily: 'Microsoft YaHei',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建普通歌词行（非当前歌词）
  Widget _buildNormalLyricLine(
    LyricLine lyric, 
    Color? themeColor, 
    double itemHeight
  ) {
    final lyricColor = _getAdaptiveLyricColor(themeColor, false);
    final translationColor = lyricColor.withOpacity(0.5);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center, // 居中
        children: [
          // 原文歌词
          Text(
            lyric.text,
            textAlign: TextAlign.center, // 居中
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: lyricColor,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.2,
              fontFamily: 'Microsoft YaHei',
            ),
          ),
          // 翻译歌词
          if (widget.showTranslation && 
              lyric.translation != null && 
              lyric.translation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                lyric.translation!,
                textAlign: TextAlign.center, // 居中
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: translationColor,
                  fontSize: 13,
                  fontFamily: 'Microsoft YaHei',
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建流体云文字效果
  Widget _buildFluidCloudText({
    required String text,
    required double fontSize,
    required Color? themeColor,
    required bool isSelected,
    required bool isPlaying,
  }) {
    final baseColor = _getAdaptiveLyricColor(themeColor, false);
    final highlightColor = _getAdaptiveLyricColor(themeColor, true);
    
    // Windows 端不需要左右移动的光效，直接使用纯色或简单的渐变
    // 如果是播放中状态，使用高亮色；如果是选中状态(手动模式)，使用橙色高亮
    
    final Color textColor;
    if (isSelected) {
      textColor = Colors.orange;
    } else if (isPlaying) {
      textColor = highlightColor;
    } else {
      textColor = baseColor;
    }

    return Text(
      text,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize * 1.4, // 保持字体放大倍数
        fontWeight: FontWeight.w800,
        fontFamily: 'Microsoft YaHei',
        height: 1.2,
        shadows: isSelected 
          ? [
              Shadow(
                color: Colors.orange.withOpacity(0.6),
                blurRadius: 16,
                offset: const Offset(0, 0),
              ),
            ]
          : (isPlaying ? [
              Shadow(
                color: highlightColor.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 0),
              ),
            ] : []),
      ),
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 构建时间胶囊组件
  Widget _buildTimeCapsule() {
    if (_selectedLyricIndex == null || 
        _selectedLyricIndex! < 0 || 
        _selectedLyricIndex! >= widget.lyrics.length) {
      return const SizedBox.shrink();
    }

    final selectedLyric = widget.lyrics[_selectedLyricIndex!];
    final timeText = selectedLyric.startTime != null 
        ? _formatDuration(selectedLyric.startTime!)
        : '00:00';

    return FadeTransition(
      opacity: _timeCapsuleFadeAnimation!,
      child: Center(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _seekToSelectedLyric,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 时间显示
                  Text(
                    timeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 跳转提示
                  const Text(
                    '点击跳转',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 格式化时间显示
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 根据背景色亮度判断应该使用深色还是浅色文字
  bool _shouldUseDarkText(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5;
  }

  /// 获取自适应的歌词颜色
  Color _getAdaptiveLyricColor(Color? themeColor, bool isCurrent) {
    final color = themeColor ?? Colors.grey[700]!;
    final useDarkText = _shouldUseDarkText(color);
    
    if (useDarkText) {
      // 亮色背景，使用深色文字
      return isCurrent 
          ? Colors.black87 
          : Colors.black54;
    } else {
      // 暗色背景，使用浅色文字
      return isCurrent 
          ? Colors.white 
          : Colors.white.withOpacity(0.45);
    }
  }
}
