import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../core/models/note.dart';
import '../../../core/widgets/pin_mark.dart';
import '../../../core/widgets/star_mark.dart';
import '../../note_detail/views/note_detail_screen.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleStar;
  final VoidCallback onCopyContent;
  final Function(Note) onNoteUpdated;

  const NoteCard({
    super.key,
    required this.note,
    required this.onDelete,
    required this.onTogglePin,
    required this.onToggleStar,
    required this.onCopyContent,
    required this.onNoteUpdated,
  });

  String _formatDisplayDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!date.isBefore(today)) return '今天 ${DateFormat('HH:mm').format(date)}';
    if (!date.isBefore(today.subtract(const Duration(days: 1)))) return '昨天';
    return DateFormat(date.year == now.year ? 'M月d日' : 'yyyy年M月d日')
        .format(date);
  }

  String _stripMarkdown(String input) {
    return input
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), ' ')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
          (m) => m.group(1) ?? '',
        )
        .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), ' ')
        .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), ' ')
        .replaceAll(RegExp(r'^\s*>\s?', multiLine: true), ' ')
        .replaceAll(RegExp(r'[`#>*_~-]'), ' ')
        .replaceAll(RegExp(r'\n+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _buildPreviewText({int length = 180, bool useTitleFallback = true}) {
    final content = _stripMarkdown(note.content);
    if (content.isNotEmpty) {
      if (content.length <= length) {
        return content;
      }
      return '${content.substring(0, length).trimRight()}...';
    }
    if (!useTitleFallback) return '';
    final title = note.title.trim();
    if (title.isNotEmpty && !_isDefaultTimestampTitle(title)) {
      return title.length <= length
          ? title
          : '${title.substring(0, length).trimRight()}...';
    }
    return '';
  }

  bool _isDefaultTimestampTitle(String title) {
    return RegExp(
      r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$',
    ).hasMatch(title.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isDefaultTimestampTitle(note.title) ? '' : note.title.trim();
    final preview = _buildPreviewText(useTitleFallback: false);
    final imageCount =
        RegExp(r'!\[[^\]]*\]\([^)]+\)').allMatches(note.content).length;
    return Padding(
      padding: theme.cardTheme.margin ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: LayoutBuilder(builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
        final actionWidth = 76 + (textScale - 1).clamp(0, 1) * 48;
        final paneRatio =
            ((actionWidth * 2 + 8) / constraints.maxWidth).clamp(0.1, 0.9);
        return ClipRect(
            child: Slidable(
          key: ValueKey(note.id),
          groupTag: 'notes',
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: paneRatio,
            children: [
              _SwipeAction(
                key: const ValueKey('swipe-pin'),
                onPressed: onTogglePin,
                color: const Color(0xFF966A20),
                background: const Color(0xFFFCF5E3),
                icon: PinMark(size: 24, filled: note.isPinned == 1),
                label: note.isPinned == 1 ? '取消置顶' : '置顶',
              ),
              _SwipeAction(
                key: const ValueKey('swipe-delete'),
                onPressed: onDelete,
                color: const Color(0xFFA44C43),
                background: const Color(0xFFF8EDE9),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFA44C43), size: 22),
                label: '删除',
              ),
            ],
          ),
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => NoteDetailScreen(note: note)));
                if (result == true) onNoteUpdated(note);
              },
              onLongPress: onCopyContent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (note.isPinned == 1) ...[
                          const PinMark(),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                            child: Text(_formatDisplayDate(note.updatedAt),
                                style: theme.textTheme.bodySmall)),
                        if (note.isStarred == 1) const StarMark(),
                        SizedBox(
                            height: 32,
                            width: 36,
                            child: PopupMenuButton<String>(
                              tooltip: '笔记操作',
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_horiz_rounded,
                                  size: 21),
                              onSelected: (action) {
                                switch (action) {
                                  case 'pin':
                                    onTogglePin();
                                  case 'star':
                                    onToggleStar();
                                  case 'copy':
                                    onCopyContent();
                                  case 'delete':
                                    onDelete();
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: 'pin',
                                    child: Text(
                                        note.isPinned == 1 ? '取消置顶' : '置顶笔记')),
                                PopupMenuItem(
                                    value: 'star',
                                    child: Text(
                                        note.isStarred == 1 ? '取消收藏' : '收藏笔记')),
                                const PopupMenuItem(
                                    value: 'copy', child: Text('复制正文')),
                                const PopupMenuItem(
                                    value: 'delete', child: Text('删除笔记')),
                              ],
                            )),
                      ]),
                      if (title.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontSize: 18, height: 1.45))),
                      ],
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(preview,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: title.isEmpty
                                        ? null
                                        : const Color(0xFF6B7970),
                                    fontSize: title.isEmpty ? 17 : 14,
                                    height: 1.6))),
                      ],
                      if (imageCount > 0) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          const Icon(Icons.image_outlined, size: 15),
                          const SizedBox(width: 6),
                          Text('$imageCount 张图片',
                              style: theme.textTheme.bodySmall),
                        ]),
                      ],
                      if (title.isEmpty && preview.isEmpty && imageCount == 0)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('空白笔记')),
                    ]),
              ),
            ),
          ),
        ));
      }),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  final String label;
  final Widget icon;
  final Color color;
  final Color background;
  final VoidCallback onPressed;

  const _SwipeAction(
      {super.key,
      required this.label,
      required this.icon,
      required this.color,
      required this.background,
      required this.onPressed});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
              child: SizedBox(
            width: double.infinity,
            height: 88,
            child: Material(
              color: background,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Slidable.of(context)?.close();
                  onPressed();
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon,
                        const SizedBox(height: 8),
                        Text(label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.25,
                                fontWeight: FontWeight.w500,
                                color: color)),
                      ]),
                ),
              ),
            ),
          )),
        ),
      );
}
