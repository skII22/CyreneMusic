import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent_ui;
import '../../widgets/desktop_lyric_settings.dart';
import '../../widgets/android_floating_lyric_settings.dart';
import '../../widgets/fluent_settings_card.dart';
import '../../services/lyric_style_service.dart';

/// 歌词设置组件
class LyricSettings extends StatefulWidget {
  const LyricSettings({super.key});

  @override
  State<LyricSettings> createState() => _LyricSettingsState();
}

class _LyricSettingsState extends State<LyricSettings> {
  final _lyricStyleService = LyricStyleService();

  @override
  Widget build(BuildContext context) {
    final isFluent = fluent_ui.FluentTheme.maybeOf(context) != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 全屏播放器歌词样式选择（所有平台通用）
        _buildSectionTitle(context, '全屏播放器歌词样式', isFluent),
        const SizedBox(height: 8),
        _buildLyricStyleSelector(context, isFluent),
        
        const SizedBox(height: 24),
        
        // 平台特定的歌词设置
        if (Platform.isWindows) ...[
          _buildSectionTitle(context, '桌面歌词', isFluent),
          const SizedBox(height: 8),
          if (isFluent)
            const DesktopLyricSettings()
          else
            const DesktopLyricSettings(),
        ] else if (Platform.isAndroid) ...[
          _buildSectionTitle(context, '悬浮歌词', isFluent),
          const SizedBox(height: 8),
          const AndroidFloatingLyricSettings(),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, bool isFluent) {
    if (isFluent) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
        child: fluent_ui.Text(
          title,
          style: fluent_ui.FluentTheme.of(context).typography.subtitle?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  /// 构建歌词样式选择器
  Widget _buildLyricStyleSelector(BuildContext context, bool isFluent) {
    return AnimatedBuilder(
      animation: _lyricStyleService,
      builder: (context, child) {
        if (isFluent) {
          return _buildFluentStyleSelector(context);
        }
        return _buildMaterialStyleSelector(context);
      },
    );
  }

  /// 构建 Material Design 样式选择器
  Widget _buildMaterialStyleSelector(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.style,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '歌词样式',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...LyricStyle.values.map((style) {
              final isSelected = _lyricStyleService.currentStyle == style;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: () => _lyricStyleService.setStyle(style),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _lyricStyleService.getStyleName(style),
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _lyricStyleService.getStyleDescription(style),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// 构建 Fluent Design 样式选择器
  Widget _buildFluentStyleSelector(BuildContext context) {
    return fluent_ui.Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(
                fluent_ui.FluentIcons.edit_style,
                size: 20,
                color: fluent_ui.FluentTheme.of(context).accentColor,
              ),
              const SizedBox(width: 8),
              fluent_ui.Text(
                '歌词样式',
                style: fluent_ui.FluentTheme.of(context).typography.subtitle,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 样式选项
          ...LyricStyle.values.map((style) {
            final isSelected = _lyricStyleService.currentStyle == style;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? fluent_ui.FluentTheme.of(context).accentColor.withOpacity(0.1)
                      : fluent_ui.FluentTheme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? fluent_ui.FluentTheme.of(context).accentColor
                        : fluent_ui.FluentTheme.of(context).resources.dividerStrokeColorDefault,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: fluent_ui.Button(
                  onPressed: () => _lyricStyleService.setStyle(style),
                  style: fluent_ui.ButtonStyle(
                    backgroundColor: fluent_ui.WidgetStateProperty.all(Colors.transparent),
                    padding: fluent_ui.WidgetStateProperty.all(
                      const EdgeInsets.all(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      fluent_ui.RadioButton(
                        checked: isSelected,
                        onChanged: (value) {
                          if (value) _lyricStyleService.setStyle(style);
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            fluent_ui.Text(
                              _lyricStyleService.getStyleName(style),
                              style: fluent_ui.FluentTheme.of(context).typography.body?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            fluent_ui.Text(
                              _lyricStyleService.getStyleDescription(style),
                              style: fluent_ui.FluentTheme.of(context).typography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

