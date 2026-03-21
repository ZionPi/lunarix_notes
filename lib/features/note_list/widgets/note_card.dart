// lib/features/note_list/widgets/note_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // 用于滑动操作
import 'package:intl/intl.dart'; // 用于日期格式化

import '../../../core/models/note.dart'; // 导入 Note 模型
import '../../note_detail/views/note_detail_screen.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleStar;
  final Function(Note) onNoteUpdated;
  final bool showTitle;

  const NoteCard({
    super.key,
    required this.note,
    required this.onDelete,
    required this.onTogglePin,
    required this.onToggleStar,
    required this.onNoteUpdated,
    required this.showTitle,
  });

  String _formatDisplayDate(DateTime dt) {
    // ... (这个方法不变)
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (dt.year != now.year) {
      return DateFormat('yyyy/MM/dd HH:mm').format(dt);
    } else if (difference.inDays >= 7) {
      return DateFormat('MM/dd HH:mm').format(dt);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}天前 ${DateFormat('HH:mm').format(dt)}';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  @override
  Widget build(BuildContext context) {

    final cardTheme = Theme.of(context).cardTheme; // Dart 会推断类型为 CardTheme
    final Color cardBackgroundColor = cardTheme.color ?? Colors.white; // 从 CardTheme 获取颜色

    final Brightness cardBrightness = ThemeData.estimateBrightnessForColor(cardBackgroundColor);
    final Color textColorOnCard = cardBrightness == Brightness.dark ? Colors.white : Colors.black87;
    final Color secondaryTextColorOnCard = cardBrightness == Brightness.dark ? Colors.white70 : Colors.black54;
    // 注意：Colors.grey[600]! 使用了空断言 !, 确保你的主题中 Colors.grey[600] 总是非空
    // 或者提供一个备用颜色：Colors.grey[600] ?? Colors.grey
    final Color iconColorOnCard = cardBrightness == Brightness.dark ? Colors.white70 : (Colors.grey[600] ?? Colors.grey);




    String displayTitleText = note.title.isNotEmpty ? note.title : "无标题笔记"; // 默认如果内容也空，用这个
    if (note.title.isEmpty && note.content.isNotEmpty) { // 如果标题空但内容不空，标题预览用内容
      displayTitleText = note.content;
    }
    if (displayTitleText.isEmpty) { // 双重保险
      displayTitleText = "无标题笔记";
    }

    // --- 确定时间标签的前缀和使用的时间戳 ---
    String timePrefix;
    DateTime timeToDisplay;

    // 定义一个小的阈值，比如10秒。如果 updated_at 和 created_at 在此阈值内，
    // 我们就认为它主要是创建时间。
    const int updateThresholdSeconds = 10;

    if (note.updatedAt.difference(note.createdAt).inSeconds.abs() < updateThresholdSeconds) {
      // 如果更新时间和创建时间非常接近 (或 updatedAt 早于/等于 createdAt，这理论上不应发生但作为保护)
      // 我们认为它更像是“创建于”
      timePrefix = '创建于 '; // 或者不加前缀，直接显示时间
      timeToDisplay = note.createdAt;
    } else {
      // 如果更新时间明显晚于创建时间，则是“更新于”
      timePrefix = '更新于 ';
      timeToDisplay = note.updatedAt;
    }
    // 特殊情况：“刚刚”创建或更新的，不加前缀
    final String formattedTime = _formatDisplayDate(timeToDisplay);
    if (formattedTime == '刚刚') {
      timePrefix = ''; // 如果是“刚刚”，则不显示前缀
    }

    // 统一主要显示文本的预览长度，无论它来自标题还是内容
    const int mainPreviewLength = 50; // 预览的主要文本（标题或内容）的最大长度
    if (displayTitleText.length > mainPreviewLength) {
      displayTitleText = '${displayTitleText.substring(0, mainPreviewLength)}...';
    }

    String contentForCardPreview = "";
    if (showTitle && note.title.isNotEmpty && note.content.isNotEmpty) {
      // 如果显示标题，并且标题不为空，内容不为空，那么 contentForCardPreview 是实际的内容预览
      contentForCardPreview = note.content.replaceAll('\n', ' ');
      if (contentForCardPreview.length > 60) { // 内容预览可以稍微多一点，但也会被截断
        contentForCardPreview = '${contentForCardPreview.substring(0, 60)}...';
      }
    } else if (!showTitle && note.content.isNotEmpty) {
      // 如果不显示标题，内容就是主要显示文本
      contentForCardPreview = note.content.replaceAll('\n', ' ');
      // contentForCardPreview 的长度已由 displayTitleText 的逻辑（使用内容作为源）间接处理
      // 这里确保它不为空，长度限制将由 displayTitleText 的截断逻辑统一处理（如果 content 作为其源）
      // 或者，如果希望不显示标题时内容预览总是取自 note.content 并有独立长度：
      if (contentForCardPreview.length > mainPreviewLength + 20) { // 允许比标题模式下的内容预览长一点
        contentForCardPreview = '${contentForCardPreview.substring(0, mainPreviewLength + 20)}...';
      }
    }


    return Slidable(
      key: ValueKey(note.id),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) => onDelete(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: '删除',
          ),
        ],
      ),
      child: Card(
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteDetailScreen(note: note),
              ),
            );
            if (result == true) {
              onNoteUpdated(note);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              '$timePrefix$formattedTime', // 使用确定的前缀和格式化后的时间
                              style: TextStyle(fontSize: 12.0, color: secondaryTextColorOnCard),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                icon: Icon(
                                  note.isPinned == 1 ? Icons.push_pin : Icons.push_pin_outlined,
                                  // --- 3. 置顶/加星图标颜色也需要适应 ---
                                  // 对于置顶，激活时颜色可以来自主题的 primary，未激活时用 iconColorOnCard
                                  color: note.isPinned == 1 ? Theme.of(context).colorScheme.primary : iconColorOnCard,
                                  size: 20,
                                ),
                                onPressed: onTogglePin,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: note.isPinned == 1 ? '取消置顶' : '置顶笔记',
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: Icon(
                                  note.isStarred == 1 ? Icons.star : Icons.star_border_outlined,
                                  // 加星激活时用醒目颜色（如Amber），未激活时用 iconColorOnCard
                                  color: note.isStarred == 1 ? Colors.amber[700] : iconColorOnCard,
                                  size: 20,
                                ),
                                onPressed: onToggleStar,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: note.isStarred == 1 ? '取消加星' : '加星笔记',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),

                      if (showTitle)
                        Text(
                          displayTitleText,
                          style: TextStyle(
                            fontSize: 17.0,
                            fontWeight: FontWeight.w500,
                            // --- 2. 应用动态文本颜色 ---
                            color: textColorOnCard,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          note.content.isNotEmpty
                              ? note.content.replaceAll('\n', ' ').split('\n').first
                              : (note.title.isNotEmpty ? displayTitleText : "无内容笔记"),
                          style: TextStyle(
                            fontSize: 17.0,
                            fontWeight: FontWeight.normal,
                            // --- 2. 应用动态文本颜色 ---
                            color: textColorOnCard,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      if (showTitle && note.content.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            note.content.replaceAll('\n', ' '),
                            style: TextStyle(
                              fontSize: 15.0,
                              // --- 2. 应用动态文本颜色 ---
                              color: secondaryTextColorOnCard,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
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
