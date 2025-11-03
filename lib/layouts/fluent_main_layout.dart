import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart' as fluent_ui;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../pages/home_page.dart';
import '../pages/discover_page.dart';
import '../pages/history_page.dart';
import '../pages/local_page.dart';
import '../pages/my_page.dart';
import '../pages/settings_page.dart';
import '../pages/developer_page.dart';
import '../pages/auth/auth_page.dart';
import '../services/auth_service.dart';
import '../services/auth_overlay_service.dart';
import '../services/developer_mode_service.dart';
import '../services/navigation_provider.dart';
import '../utils/page_visibility_notifier.dart';
import '../utils/theme_manager.dart';
import '../widgets/mini_player.dart';
import '../widgets/search_widget.dart';

/// Fluent UI 版本的主布局，使用 NavigationView
/// 按照 Windows 设计规范实现左侧导航栏
class FluentMainLayout extends StatefulWidget {
  const FluentMainLayout({super.key});

  @override
  State<FluentMainLayout> createState() => _FluentMainLayoutState();
}

class _FluentMainLayoutState extends State<FluentMainLayout> with WindowListener {
  // 导航状态管理
  final NavigationProvider _navigationProvider = NavigationProvider();
  
  // 窗口状态
  TextEditingController? _searchController;
  bool _isWindowMaximized = false;
  
  // Pane 显示模式（compact = 折叠，open = 展开）
  fluent_ui.PaneDisplayMode _displayMode = fluent_ui.PaneDisplayMode.compact;
  
  // 搜索覆盖层状态
  bool _isSearchVisible = false;
  String? _searchInitialKeyword;

  /// 主导航项列表
  List<fluent_ui.NavigationPaneItem> get _paneItems {
    final items = <fluent_ui.NavigationPaneItem>[
      fluent_ui.PaneItem(
        icon: const Icon(fluent_ui.FluentIcons.home),
        title: const Text('首页'),
        body: const HomePage(),
      ),
      fluent_ui.PaneItem(
        icon: const Icon(fluent_ui.FluentIcons.search),
        title: const Text('发现'),
        body: const DiscoverPage(),
      ),
      fluent_ui.PaneItem(
        icon: const Icon(fluent_ui.FluentIcons.history),
        title: const Text('历史'),
        body: const HistoryPage(),
      ),
      fluent_ui.PaneItem(
        icon: const Icon(fluent_ui.FluentIcons.folder_open),
        title: const Text('本地'),
        body: const LocalPage(),
      ),
      fluent_ui.PaneItem(
        icon: const Icon(fluent_ui.FluentIcons.contact),
        title: const Text('我的'),
        body: const MyPage(),
      ),
    ];

    // 开发者模式下添加开发者页面
    if (DeveloperModeService().isDeveloperMode) {
      items.add(
        fluent_ui.PaneItem(
          icon: const Icon(fluent_ui.FluentIcons.code),
          title: const Text('Dev'),
          body: const DeveloperPage(),
        ),
      );
    }

    return items;
  }

  /// 底部导航项（设置页面）
  List<fluent_ui.NavigationPaneItem> get _footerItems {
    return [
      fluent_ui.PaneItem(
        icon: const Icon(fluent_ui.FluentIcons.settings),
        title: const Text('设置'),
        body: const _DeferredSettingsPage(),
      ),
    ];
  }

  /// 与 Pane 对应顺序的内容页（items + footerItems）
  List<Widget> get _bodyChildren {
    final children = <Widget>[
      const HomePage(),
      const DiscoverPage(),
      const HistoryPage(),
      const LocalPage(),
      const MyPage(),
    ];
    if (DeveloperModeService().isDeveloperMode) {
      children.add(const DeveloperPage());
    }
    // footer: 设置
    children.add(const _DeferredSettingsPage());
    return children;
  }

  /// 切换 Pane 折叠/展开状态
  void _togglePane() {
    setState(() {
      if (_displayMode == fluent_ui.PaneDisplayMode.compact) {
        _displayMode = fluent_ui.PaneDisplayMode.open;
      } else {
        _displayMode = fluent_ui.PaneDisplayMode.compact;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    
    // Windows 平台初始化
    if (Platform.isWindows) {
      _searchController = TextEditingController();
      windowManager.addListener(this);
      windowManager.isMaximized().then((value) {
        if (mounted) {
          setState(() {
            _isWindowMaximized = value;
          });
        }
      });
    }
    
    // 监听服务变化
    AuthService().addListener(_onAuthChanged);
    DeveloperModeService().addListener(_onDeveloperModeChanged);
    _navigationProvider.addListener(_onNavigationChanged);

    // 初始化系统颜色
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ThemeManager().initializeSystemColor(context);
      }
    });
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    _searchController?.dispose();
    AuthService().removeListener(_onAuthChanged);
    DeveloperModeService().removeListener(_onDeveloperModeChanged);
    _navigationProvider.removeListener(_onNavigationChanged);
    _navigationProvider.dispose();
    super.dispose();
  }

  /// 认证状态变化回调
  void _onAuthChanged() {
    if (!mounted) return;
    // 使用 addPostFrameCallback 避免在构建期间调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  /// 开发者模式变化回调
  void _onDeveloperModeChanged() {
    if (!mounted) return;
    // 使用 addPostFrameCallback 延迟到构建完成后再调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        // 开发者模式切换时，检查当前索引是否有效
        final totalPageCount = _paneItems.length + _footerItems.length;
        if (_navigationProvider.currentIndex >= totalPageCount) {
          _navigationProvider.navigateTo(0);
        }
      });
    });
  }

  /// 导航状态变化回调
  void _onNavigationChanged() {
    if (!mounted) return;
    // 使用 addPostFrameCallback 避免在 NavigationView 布局过程中触发同步 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      // 通知页面可见性变化
      PageVisibilityNotifier().setCurrentPage(_navigationProvider.currentIndex);

      // 设置页面点击时触发开发者模式彩蛋
      final settingsIndex = _paneItems.length;
      if (_navigationProvider.currentIndex == settingsIndex) {
        DeveloperModeService().onSettingsClicked();
      }
    });
  }

  void _handleCaptionMinimize() {
    if (!Platform.isWindows) return;
    windowManager.minimize();
  }

  void _handleCaptionMaximizeOrRestore() {
    if (!Platform.isWindows) return;
    windowManager.isMaximized().then((isMaximized) {
      if (isMaximized) {
        windowManager.unmaximize();
      } else {
        windowManager.maximize();
      }
      if (mounted) {
        setState(() {
          _isWindowMaximized = !isMaximized;
        });
      }
    });
  }

  void _handleCaptionClose() {
    if (!Platform.isWindows) return;
    windowManager.close();
  }

  @override
  void onWindowMaximize() {
    if (!mounted) return;
    setState(() {
      _isWindowMaximized = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    if (!mounted) return;
    setState(() {
      _isWindowMaximized = false;
    });
  }

  void _onSearchSubmitted(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() {
      _isSearchVisible = true;
      _searchInitialKeyword = query;
    });
  }

  Widget _buildWindowCaptionButtons(BuildContext context) {
    final brightness = fluent_ui.FluentTheme.of(context).brightness;
    final buttons = <Widget>[
      WindowCaptionButton.minimize(
        brightness: brightness,
        onPressed: _handleCaptionMinimize,
      ),
      _isWindowMaximized
          ? WindowCaptionButton.unmaximize(
              brightness: brightness,
              onPressed: _handleCaptionMaximizeOrRestore,
            )
          : WindowCaptionButton.maximize(
              brightness: brightness,
              onPressed: _handleCaptionMaximizeOrRestore,
            ),
      WindowCaptionButton.close(
        brightness: brightness,
        onPressed: _handleCaptionClose,
      ),
    ];
    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  /// 处理导航项点击
  void _onPaneIndexChanged(int index) {
    // 推迟到当前帧结束再切换，避免在 NavigationView 布局阶段触发同步状态更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationProvider.navigateTo(index);
    });
  }

  Future<void> _handleUserButtonTap() async {
    if (AuthService().isLoggedIn) {
      await _showUserMenu();
    } else {
      await AuthOverlayService().show();
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// 显示用户菜单
  Future<void> _showUserMenu() async {
    final user = AuthService().currentUser;
    if (user == null || !mounted) return;

    final result = await fluent_ui.showDialog<_FluentUserAction>(
      context: context,
      builder: (context) {
        return fluent_ui.ContentDialog(
          title: Text(user.username),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.email),
              const SizedBox(height: 16),
              fluent_ui.Button(
                child: const Text('我的'),
                onPressed: () => Navigator.pop(context, _FluentUserAction.viewProfile),
              ),
            ],
          ),
          actions: [
            fluent_ui.Button(
              child: const Text('关闭'),
              onPressed: () => Navigator.pop(context),
            ),
            fluent_ui.FilledButton(
              child: const Text('退出登录'),
              onPressed: () => Navigator.pop(context, _FluentUserAction.logout),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    switch (result) {
      case _FluentUserAction.viewProfile:
        _navigationProvider.navigateTo(4); // 导航到「我的」页面
        break;
      case _FluentUserAction.logout:
        await _confirmLogout();
        break;
      case null:
        break;
    }
  }

  /// 确认退出登录
  Future<void> _confirmLogout() async {
    final shouldLogout = await fluent_ui.showDialog<bool>(
      context: context,
      builder: (context) {
        return fluent_ui.ContentDialog(
          title: const Text('退出登录'),
          content: const Text('确定要退出当前账号吗？'),
          actions: [
            fluent_ui.Button(
              child: const Text('取消'),
              onPressed: () => Navigator.pop(context, false),
            ),
            fluent_ui.FilledButton(
              child: const Text('退出'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      AuthService().logout();
      if (!mounted) return;
      _showLogoutSnackBar();
    }
  }

  /// 显示退出登录提示
  void _showLogoutSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已退出登录')),
    );
  }

  /// 构建用户操作组件（头像或登录按钮）
  Widget _buildUserActionWidget() {
    final isLogged = AuthService().isLoggedIn;
    final user = AuthService().currentUser;
    const double size = 28;

    if (isLogged && user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () => _navigationProvider.navigateTo(4), // 导航到「我的」页面
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.network(
            user.avatarUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              fluent_ui.FluentIcons.contact,
              size: size,
            ),
          ),
        ),
      );
    }

    return fluent_ui.IconButton(
      icon: const Icon(fluent_ui.FluentIcons.add_friend),
      onPressed: () async {
        await AuthOverlayService().show();
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  /// 构建应用栏（标题栏）
  fluent_ui.NavigationAppBar _buildAppBar(BuildContext context) {
    final userActionWidget = _buildUserActionWidget();

    if (!Platform.isWindows) {
      return fluent_ui.NavigationAppBar(
        automaticallyImplyLeading: false,
        title: const Text('Cyrene Music'),
        actions: Row(
          mainAxisSize: MainAxisSize.min,
          children: [userActionWidget],
        ),
      );
    }

    final fluentTheme = fluent_ui.FluentTheme.of(context);
    _searchController ??= TextEditingController();
    final typography = fluentTheme.typography;

    return fluent_ui.NavigationAppBar(
      automaticallyImplyLeading: false,
      // 移除顶部折叠按钮
      leading: const SizedBox.shrink(),
      height: 50,
      title: SizedBox(
        height: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DragToMoveArea(
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 1.0, right: 1.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/tray_icon.png',
                      width: 16,
                      height: 16,
                    ),
                    const SizedBox(width: 1),
                    Text(
                      'Cyrene Music',
                      style: (typography.subtitle ?? typography.bodyLarge)?.copyWith(fontSize: 12) 
                          ?? const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SizedBox(
                  height: 36,
                  child: fluent_ui.TextBox(
                    controller: _searchController,
                    placeholder: '搜索音乐、歌手或专辑',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0, right: 4.0),
                      child: Icon(fluent_ui.FluentIcons.search),
                    ),
                    prefixMode: fluent_ui.OverlayVisibilityMode.always,
                    onSubmitted: _onSearchSubmitted,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: userActionWidget,
                    ),
                    _buildWindowCaptionButtons(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: const SizedBox.shrink(),
    );
  }

  /// 构建搜索覆盖层
  Widget _buildSearchOverlay() {
    return Material(
      color: Colors.transparent,
      child: SearchWidget(
        onClose: () {
          if (!mounted) return;
          setState(() {
            _isSearchVisible = false;
            _searchInitialKeyword = null;
          });
        },
        initialKeyword: _searchInitialKeyword,
      ),
    );
  }

  /// 构建认证覆盖层
  Widget _buildAuthOverlay(BuildContext context) {
    final overlay = AuthOverlayService();
    final fluentTheme = fluent_ui.FluentTheme.of(context);
    
    // 根据 displayMode 计算左侧宽度
    final double leftPaneWidth = _displayMode == fluent_ui.PaneDisplayMode.compact ? 56.0 : 280.0;

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          width: leftPaneWidth,
          child: Container(color: fluentTheme.micaBackgroundColor.withOpacity(0.6)),
        ),
        Expanded(
          child: Container(
            color: fluentTheme.micaBackgroundColor,
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: fluent_ui.IconButton(
                      icon: const Icon(fluent_ui.FluentIcons.back),
                      onPressed: () => AuthOverlayService().hide(false),
                    ),
                  ),
                  Expanded(
                    child: PrimaryScrollController.none(
                      child: AuthPage(initialTab: overlay.initialTab),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fluentTheme = fluent_ui.FluentTheme.of(context);
    
    // 构建 NavigationView（按照 README 文档标准实现）
    final navigationView = fluent_ui.NavigationView(
      appBar: _buildAppBar(context),
      pane: fluent_ui.NavigationPane(
        selected: _navigationProvider.currentIndex,
        onChanged: _onPaneIndexChanged,
        displayMode: _displayMode,
        items: _paneItems,
        footerItems: _footerItems,
      ),
    );

    // 根据 displayMode 计算 Pane 宽度
    final double paneWidth = _displayMode == fluent_ui.PaneDisplayMode.compact ? 56.0 : 280.0;

    Widget content = AnimatedBuilder(
      animation: AuthOverlayService(),
      builder: (context, _) {
        final overlay = AuthOverlayService();
        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      navigationView,
                      if (_isSearchVisible)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          left: paneWidth,
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: _buildSearchOverlay(),
                        ),
                    ],
                  ),
                ),
                const MiniPlayer(),
              ],
            ),
            if (overlay.isVisible)
              Positioned.fill(
                child: _buildAuthOverlay(context),
              ),
          ],
        );
      },
    );

    // Windows 平台添加圆角边框
    if (Platform.isWindows) {
      final isMaximized = _isWindowMaximized;
      final borderRadius = isMaximized ? BorderRadius.zero : BorderRadius.circular(12);
      final padding = isMaximized ? EdgeInsets.zero : const EdgeInsets.all(8.0);
      final borderColor = fluentTheme.resources.controlStrokeColorDefault;

      content = Padding(
        padding: padding,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fluentTheme.micaBackgroundColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}

/// 首次进入设置页时延迟一个帧再渲染真实内容，避免在 NavigationView 首帧布局期间产生重入布局
class _DeferredSettingsPage extends StatefulWidget {
  const _DeferredSettingsPage({super.key});

  @override
  State<_DeferredSettingsPage> createState() => _DeferredSettingsPageState();
}

class _DeferredSettingsPageState extends State<_DeferredSettingsPage> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: fluent_ui.ProgressRing());
    }
    return const SettingsPage();
  }
}

enum _FluentUserAction { viewProfile, logout }

