import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/track.dart';
import '../models/merged_track.dart';
import '../services/search_service.dart';
import '../services/netease_artist_service.dart';
import '../pages/artist_detail_page.dart';
import '../pages/album_detail_page.dart';
import '../services/player_service.dart';
import '../services/auth_service.dart';
import '../pages/auth/auth_page.dart';
import '../utils/theme_manager.dart';

/// 搜索组件（内嵌版本）
class SearchWidget extends StatefulWidget {
  final VoidCallback onClose;
  final String? initialKeyword; // 初始搜索关键词

  const SearchWidget({super.key, required this.onClose, this.initialKeyword});

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchCapsuleTabs extends StatelessWidget {
  final List<String> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _SearchCapsuleTabs({
    required this.tabs,
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = colorScheme.surfaceContainerHighest;
    final indicatorColor = colorScheme.primary;
    final selectedTextColor = colorScheme.onPrimary;
    final unselectedTextColor = colorScheme.onSurfaceVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = tabs.length;
        if (count == 0) {
          return const SizedBox.shrink();
        }

        final totalWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final tabWidth = totalWidth / count;
        final height = 48.0;
        final padding = 5.0;
        final radius = height / 2;
        final indicatorWidth = (tabWidth - padding * 2).clamp(0.0, tabWidth);

        int safeIndex = currentIndex;
        if (safeIndex < 0) {
          safeIndex = 0;
        } else if (safeIndex >= count) {
          safeIndex = count - 1;
        }

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                top: padding,
                bottom: padding,
                left: padding + safeIndex * (tabWidth - padding * 2),
                width: indicatorWidth,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(radius - padding),
                    boxShadow: [
                      BoxShadow(
                        color: indicatorColor.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(count, (index) {
                  final selected = index == safeIndex;
                  return SizedBox(
                    width: tabWidth,
                    height: height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(index),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          style: TextStyle(
                            color:
                                selected ? selectedTextColor : unselectedTextColor,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          child: Text(tabs[index]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  int _currentTabIndex = 0;
  final ThemeManager _themeManager = ThemeManager();

  bool get _isFluent => _themeManager.isFluentFramework;

  // 歌手搜索状态
  List<NeteaseArtistBrief> _artistResults = [];
  bool _artistLoading = false;
  String? _artistError;
  // 二级页面（面包屑）状态
  int? _secondaryArtistId;
  String? _secondaryArtistName;
  int? _secondaryAlbumId;
  String? _secondaryAlbumName;

  @override
  void initState() {
    super.initState();
    _searchService.addListener(_onSearchResultChanged);

    // 如果有初始关键词，自动填充并搜索
    if (widget.initialKeyword != null && widget.initialKeyword!.isNotEmpty) {
      _searchController.text = widget.initialKeyword!;
      // 延迟执行搜索，确保 UI 已经构建完成
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _performSearch();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchService.removeListener(_onSearchResultChanged);
    super.dispose();
  }

  void _onSearchResultChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 检查登录状态，如果未登录则跳转到登录页面
  /// 返回 true 表示已登录或登录成功，返回 false 表示未登录或取消登录
  Future<bool> _checkLoginStatus() async {
    if (AuthService().isLoggedIn) {
      return true;
    }

    // 显示提示并询问是否要登录
    final shouldLogin = await (_isFluent
        ? fluent.showDialog<bool>(
            context: context,
            builder: (context) => fluent.ContentDialog(
              title: const Text('需要登录'),
              content: const Text('此功能需要登录后才能使用，是否前往登录？'),
              actions: [
                fluent.Button(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                fluent.FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('去登录'),
                ),
              ],
            ),
          )
        : showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('需要登录'),
                ],
              ),
              content: const Text('此功能需要登录后才能使用，是否前往登录？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('去登录'),
                ),
              ],
            ),
          ));

    if (shouldLogin == true && mounted) {
      // 跳转到登录页面
      final result = await showAuthDialog(context);

      // 返回登录是否成功
      return result == true && AuthService().isLoggedIn;
    }

    return false;
  }

  void _performSearch() async {
    // 检查登录状态
    final isLoggedIn = await _checkLoginStatus();
    if (!isLoggedIn) return;

    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      _searchService.search(keyword);
      if (_currentTabIndex == 1) {
        _searchArtists(keyword);
      }
    }
  }

  void _triggerArtistSearchIfNeeded() {
    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      _searchArtists(keyword);
    }
  }

  void _handleTabChanged(int index) {
    if (_currentTabIndex == index) {
      if (index == 1) {
        _triggerArtistSearchIfNeeded();
      }
      return;
    }

    setState(() {
      _currentTabIndex = index;
    });

    if (index == 1) {
      _triggerArtistSearchIfNeeded();
    }
  }

  Future<void> _searchArtists(String keyword) async {
    setState(() {
      _artistLoading = true;
      _artistError = null;
      _artistResults = [];
    });
    try {
      final results = await NeteaseArtistDetailService().searchArtists(
        keyword,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _artistResults = results;
        _artistLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _artistLoading = false;
        _artistError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchResult = _searchService.searchResult;
    if (_isFluent) {
      return _buildFluentSearch(context, searchResult);
    }
    return _buildMaterialSearch(context, searchResult);
  }

  Widget _buildMaterialSearch(BuildContext context, SearchResult searchResult) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                // 搜索栏
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: widget.onClose,
                        tooltip: '返回',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: '搜索歌曲、歌手...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _searchService.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _performSearch(),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _performSearch,
                        child: const Text('搜索'),
                      ),
                    ],
                  ),
                ),

                // 选项卡 + 结果区域
                Expanded(
                  child: _buildSearchTabsArea(
                    context,
                    searchResult,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 覆盖搜索栏的二级详情层（歌手/专辑）
          if (_secondaryArtistId != null || _secondaryAlbumId != null)
            Positioned.fill(
              child: _buildSecondaryOverlayContainer(
                backgroundColor: colorScheme.surface,
                useMaterialWrapper: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFluentSearch(BuildContext context, SearchResult searchResult) {
    final fluentTheme = fluent.FluentTheme.of(context);
    final overlayBackground =
        fluentTheme.micaBackgroundColor ??
        fluentTheme.scaffoldBackgroundColor ??
        Colors.transparent;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                _buildFluentSearchBar(fluentTheme),
                Expanded(
                  child: _buildSearchTabsArea(
                    context,
                    searchResult,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  ),
                ),
              ],
            ),
          ),
          if (_secondaryArtistId != null || _secondaryAlbumId != null)
            Positioned.fill(
              child: _buildSecondaryOverlayContainer(
                backgroundColor: overlayBackground,
                useMaterialWrapper: false,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecondaryOverlayContainer({
    required Color backgroundColor,
    required bool useMaterialWrapper,
  }) {
    final title = _secondaryAlbumId != null
        ? (_secondaryAlbumName ?? '专辑详情')
        : (_secondaryArtistName ?? '歌手详情');

    final header = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _isFluent
                ? fluent.Tooltip(
                    message: '返回',
                    child: fluent.IconButton(
                      icon: const Icon(fluent.FluentIcons.back),
                      onPressed: _handleSecondaryBack,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _handleSecondaryBack,
                    tooltip: '返回',
                  ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    final dividerColor = _isFluent
        ? fluent.FluentTheme.of(context).resources?.dividerStrokeColorDefault
        : Theme.of(context).dividerColor;

    final content = Column(
      children: [
        header,
        Divider(height: 1, color: dividerColor),
        Expanded(
          child: _secondaryAlbumId != null
              ? AlbumDetailPage(albumId: _secondaryAlbumId!, embedded: true)
              : ArtistDetailContent(
                  artistId: _secondaryArtistId!,
                  onOpenAlbum: (albumId) {
                    setState(() {
                      _secondaryAlbumId = albumId;
                      _secondaryAlbumName = null;
                    });
                  },
                ),
        ),
      ],
    );

    if (useMaterialWrapper) {
      return Material(color: backgroundColor, child: content);
    }
    return Container(color: backgroundColor, child: content);
  }

  void _handleSecondaryBack() {
    setState(() {
      if (_secondaryAlbumId != null) {
        _secondaryAlbumId = null;
      } else {
        _secondaryArtistId = null;
        _secondaryArtistName = null;
      }
    });
  }

  Widget _buildFluentSearchBar(fluent.FluentThemeData theme) {
    final dividerColor =
        theme.resources?.dividerStrokeColorDefault ??
        Colors.black.withOpacity(0.06);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.micaBackgroundColor ?? theme.scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          fluent.Tooltip(
            message: '返回',
            child: fluent.IconButton(
              icon: const Icon(fluent.FluentIcons.back),
              onPressed: widget.onClose,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: fluent.TextBox(
              controller: _searchController,
              autofocus: true,
              placeholder: '搜索歌曲、歌手...',
              prefix: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(fluent.FluentIcons.search),
              ),
              suffix: _searchController.text.isNotEmpty
                  ? fluent.IconButton(
                      icon: const Icon(fluent.FluentIcons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchService.clear();
                        setState(() {});
                      },
                    )
                  : null,
              onSubmitted: (_) => _performSearch(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          fluent.FilledButton(
            onPressed: _performSearch,
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTabsArea(
    BuildContext context,
    SearchResult searchResult, {
    required EdgeInsetsGeometry padding,
  }) {
    return Column(
      children: [
        Padding(
          padding: padding,
          child: _SearchCapsuleTabs(
            tabs: const ['歌曲', '歌手'],
            currentIndex: _currentTabIndex,
            onChanged: _handleTabChanged,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutQuad,
            switchOutCurve: Curves.easeInQuad,
            child: _buildActiveTabView(context, searchResult),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTabView(
    BuildContext context,
    SearchResult searchResult,
  ) {
    final fluentTheme = fluent.FluentTheme.maybeOf(context);
    final materialTheme = Theme.of(context);
    final backgroundColor = _isFluent
        ? (fluentTheme?.micaBackgroundColor ??
            fluentTheme?.scaffoldBackgroundColor ??
            materialTheme.colorScheme.surface)
        : materialTheme.colorScheme.surface;

    if (_currentTabIndex == 0) {
      return Container(
        key: const ValueKey('songs_tab'),
        color: backgroundColor,
        child: _buildSongResults(searchResult),
      );
    }

    return Container(
      key: const ValueKey('artists_tab'),
      color: backgroundColor,
      child: _buildArtistResults(),
    );
  }

  Widget _wrapCard({
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    required Widget child,
  }) {
    if (_isFluent) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: fluent.Card(padding: padding ?? EdgeInsets.zero, child: child),
      );
    }
    return Card(
      margin: margin,
      child: padding != null ? Padding(padding: padding, child: child) : child,
    );
  }

  Widget _buildAdaptiveListTile({
    Widget? leading,
    Widget? title,
    Widget? subtitle,
    Widget? trailing,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
  }) {
    if (_isFluent) {
      final tile = fluent.ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onPressed: onPressed,
      );

      if (onLongPress == null) {
        return tile;
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: tile,
      );
    }
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onPressed,
      onLongPress: onLongPress,
    );
  }

  Widget _buildSongResults(SearchResult result) {
    // 如果没有搜索或搜索结果为空，显示搜索历史
    if (_searchService.currentKeyword.isEmpty) {
      return _buildSearchHistory();
    }

    // 显示加载状态
    final isLoading =
        result.neteaseLoading || result.qqLoading || result.kugouLoading;

    // 获取合并后的结果
    final mergedResults = _searchService.getMergedResults();

    // 如果所有平台都加载完成且没有结果
    if (result.allCompleted && mergedResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.music_off,
        title: '没有找到相关歌曲',
        subtitle: '试试其他关键词吧',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 搜索统计
        _buildSearchHeader(mergedResults.length, result),

        const SizedBox(height: 16),

        // 加载提示
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('搜索中...'),
                ],
              ),
            ),
          ),

        // 合并后的歌曲列表
        ...mergedResults.map(
          (mergedTrack) => _buildMergedTrackItem(mergedTrack),
        ),
      ],
    );
  }

  Widget _buildArtistResults() {
    final keyword = _searchService.currentKeyword;
    if (keyword.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search,
        title: '搜索歌手',
        subtitle: '输入关键词后切换到“歌手”',
      );
    }

    if (_artistLoading &&
        _secondaryArtistId == null &&
        _secondaryAlbumId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_artistError != null &&
        _secondaryArtistId == null &&
        _secondaryAlbumId == null) {
      return Center(child: Text('搜索失败: $_artistError'));
    }
    if (_artistResults.isEmpty &&
        _secondaryArtistId == null &&
        _secondaryAlbumId == null) {
      return _buildEmptyState(
        icon: Icons.person_off,
        title: '没有找到相关歌手',
        subtitle: '试试其他关键词吧',
      );
    }

    if (_secondaryArtistId != null || _secondaryAlbumId != null) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _artistResults.length,
      itemBuilder: (context, index) {
        final artist = _artistResults[index];
        final leading = artist.picUrl.isEmpty
            ? (_isFluent
                  ? fluent.CircleAvatar(
                      radius: 24,
                      child: Icon(
                        fluent.FluentIcons.contact,
                        color: fluent.FluentTheme.of(
                          context,
                        ).resources?.textFillColorSecondary,
                      ),
                    )
                  : CircleAvatar(
                      radius: 24,
                      child: Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ))
            : ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CachedNetworkImage(
                  imageUrl: artist.picUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 48,
                    height: 48,
                    color: _isFluent
                        ? fluent.FluentTheme.of(
                                context,
                              ).resources?.controlAltFillColorSecondary ??
                              Colors.black.withOpacity(0.05)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              );

        final trailing = _isFluent
            ? const Icon(fluent.FluentIcons.chevron_right)
            : const Icon(Icons.chevron_right);

        final tile = _buildAdaptiveListTile(
          leading: leading,
          title: Text(
            artist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: trailing,
          onPressed: () {
            setState(() {
              _secondaryArtistId = artist.id;
              _secondaryArtistName = artist.name;
            });
          },
        );

        return _wrapCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.zero,
          child: tile,
        );
      },
    );
  }

  /// 构建搜索头部（统计信息）
  Widget _buildSearchHeader(int totalCount, SearchResult result) {
    final textStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);

    return _wrapCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.music_note, size: 20),
          const SizedBox(width: 8),
          Text('找到 $totalCount 首歌曲', style: textStyle),
        ],
      ),
    );
  }

  /// 构建合并后的歌曲项
  Widget _buildMergedTrackItem(MergedTrack mergedTrack) {
    final placeholderColor = _isFluent
        ? fluent.FluentTheme.of(
                context,
              ).resources?.controlAltFillColorSecondary ??
              Colors.black.withOpacity(0.05)
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    final leading = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: mergedTrack.picUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 50,
          height: 50,
          color: placeholderColor,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 50,
          height: 50,
          color: placeholderColor,
          child: Icon(
            Icons.music_note,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    final tile = _buildAdaptiveListTile(
      leading: leading,
      title: Text(
        mergedTrack.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${mergedTrack.artists} • ${mergedTrack.album}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onPressed: () => _playMergedTrack(mergedTrack),
      onLongPress: () => _showPlatformSelector(mergedTrack),
    );

    return _wrapCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: tile,
    );
  }

  /// 播放合并后的歌曲（按优先级选择平台）
  void _playMergedTrack(MergedTrack mergedTrack) async {
    // 检查登录状态
    final isLoggedIn = await _checkLoginStatus();
    if (!isLoggedIn) return;

    final bestTrack = mergedTrack.getBestTrack();
    // 播放前注入封面 Provider，避免播放器再次请求
    ImageProvider? provider;
    if (bestTrack.picUrl.isNotEmpty) {
      provider = CachedNetworkImageProvider(bestTrack.picUrl);
      PlayerService().setCurrentCoverImageProvider(provider);
    }
    PlayerService().playTrack(bestTrack, coverProvider: provider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在播放: ${mergedTrack.name}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 显示平台选择器（长按时）
  void _showPlatformSelector(MergedTrack mergedTrack) {
    if (_isFluent) {
      fluent.showDialog(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: const Text('选择播放平台'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  mergedTrack.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              ...mergedTrack.tracks.map(
                (track) => fluent.ListTile(
                  leading: Text(
                    track.getSourceIcon(),
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text(track.getSourceName()),
                  subtitle: Text(track.album, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(fluent.FluentIcons.play),
                  onPressed: () async {
                    Navigator.pop(context);
                    final isLoggedIn = await _checkLoginStatus();
                    if (isLoggedIn && mounted) {
                      if (track.picUrl.isNotEmpty) {
                        final provider = CachedNetworkImageProvider(
                          track.picUrl,
                        );
                        PlayerService().setCurrentCoverImageProvider(provider);
                        PlayerService().playTrack(
                          track,
                          coverProvider: provider,
                        );
                      } else {
                        PlayerService().playTrack(track);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('正在播放: ${track.name}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            fluent.Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择播放平台',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              mergedTrack.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...mergedTrack.tracks.map(
              (track) => ListTile(
                leading: Text(
                  track.getSourceIcon(),
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(track.getSourceName()),
                subtitle: Text(track.album),
                trailing: const Icon(Icons.play_arrow),
                onTap: () async {
                  Navigator.pop(context);
                  final isLoggedIn = await _checkLoginStatus();
                  if (isLoggedIn && mounted) {
                    if (track.picUrl.isNotEmpty) {
                      final provider = CachedNetworkImageProvider(track.picUrl);
                      PlayerService().setCurrentCoverImageProvider(provider);
                      PlayerService().playTrack(track, coverProvider: provider);
                    } else {
                      PlayerService().playTrack(track);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('正在播放: ${track.name}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建搜索历史列表
  Widget _buildSearchHistory() {
    final history = _searchService.searchHistory;
    final colorScheme = Theme.of(context).colorScheme;
    final fluentTheme = fluent.FluentTheme.maybeOf(context);

    // 如果没有历史记录，显示空状态
    if (history.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search,
        title: '搜索音乐',
        subtitle: '支持网易云、QQ音乐、酷狗音乐',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 标题栏
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '搜索历史',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            _isFluent
                ? fluent.Tooltip(
                    message: '清空',
                    child: fluent.IconButton(
                      icon: Icon(
                        fluent.FluentIcons.delete,
                        color: fluentTheme?.resources?.textFillColorSecondary,
                      ),
                      onPressed: _confirmClearHistory,
                    ),
                  )
                : TextButton.icon(
                    onPressed: _confirmClearHistory,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('清空'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 8),

        // 历史记录列表
        ...history.map((keyword) {
          final trailing = _isFluent
              ? fluent.Tooltip(
                  message: '删除',
                  child: fluent.IconButton(
                    icon: const Icon(fluent.FluentIcons.chrome_close, size: 12),
                    onPressed: () => _searchService.removeSearchHistory(keyword),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => _searchService.removeSearchHistory(keyword),
                  tooltip: '删除',
                );

          final tile = _buildAdaptiveListTile(
            leading: Icon(Icons.history, color: colorScheme.primary),
            title: Text(keyword),
            trailing: trailing,
            onPressed: () {
              _searchController.text = keyword;
              _performSearch();
            },
          );

          return _wrapCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.zero,
            child: tile,
          );
        }),

        const SizedBox(height: 16),

        // 提示信息
        Center(
          child: Text(
            '点击历史记录快速搜索',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await (_isFluent
        ? fluent.showDialog<bool>(
            context: context,
            builder: (context) => fluent.ContentDialog(
              title: const Text('清空搜索历史'),
              content: const Text('确定要清空所有搜索历史吗？'),
              actions: [
                fluent.Button(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                fluent.FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('清空'),
                ),
              ],
            ),
          )
        : showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('清空搜索历史'),
              content: const Text('确定要清空所有搜索历史吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('清空'),
                ),
              ],
            ),
          ));

    if (confirmed == true) {
      _searchService.clearSearchHistory();
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
