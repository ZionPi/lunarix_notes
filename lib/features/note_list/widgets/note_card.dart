import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../core/models/note.dart';
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

  String _formatDisplayDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  String _stripMarkdown(String input) {
    return input
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), ' ')
        .replaceAllMapped(
            RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), ' ')
        .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), ' ')
        .replaceAll(RegExp(r'^\s*>\s?', multiLine: true), ' ')
        .replaceAll(RegExp(r'[`#>*_~-]'), ' ')
        .replaceAll(RegExp(r'\n+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _buildPreviewText({int length = 40}) {
    final content = _stripMarkdown(note.content);
    if (content.isNotEmpty) {
      if (content.length <= length) {
        return content;
      }
      return '${content.substring(0, length).trimRight()}...';
    }
    final title = note.title.trim();
    if (title.isNotEmpty) {
      return title.length <= length
          ? title
          : '${title.substring(0, length).trimRight()}...';
    }
    return '这条笔记还没有正文内容';
  }

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).cardTheme;
    final cardBackgroundColor = cardTheme.color ?? Colors.white;
    final cardBrightness =
        ThemeData.estimateBrightnessForColor(cardBackgroundColor);
    final textColorOnCard =
        cardBrightness == Brightness.dark ? Colors.white : Colors.black87;
    final accentColor = Theme.of(context).colorScheme.primary;
    final chipBackground = cardBrightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.42);

    final previewText = _buildPreviewText();
    DateTime timeToDisplay;
    const updateThresholdSeconds = 10;

    if (note.updatedAt.difference(note.createdAt).inSeconds.abs() <
        updateThresholdSeconds) {
      timeToDisplay = note.createdAt;
    } else {
      timeToDisplay = note.updatedAt;
    }

    final formattedTime = _formatDisplayDate(timeToDisplay);

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
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.52,
        children: [
          SlidableAction(
            onPressed: (context) => onTogglePin(),
            backgroundColor:
                note.isPinned == 1 ? accentColor : const Color(0xFF7B8DBA),
            foregroundColor: Colors.white,
            icon: note.isPinned == 1 ? Icons.push_pin : Icons.push_pin_outlined,
            label: '置顶',
          ),
          SlidableAction(
            onPressed: (context) => onToggleStar(),
            backgroundColor: note.isStarred == 1
                ? const Color(0xFFF2A93B)
                : const Color(0xFFD4A33A),
            foregroundColor: Colors.white,
            icon: note.isStarred == 1
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            label: '收藏',
          ),
        ],
      ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
          onLongPress: onCopyContent,
          child: SizedBox(
            height: 128,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: chipBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          formattedTime,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text(
                      previewText,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.46,
                        fontWeight: FontWeight.w600,
                        color: textColorOnCard,
                        letterSpacing: 0.05,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    height: 18,
                    child: Row(
                      children: [
                        const Spacer(),
                        if (note.isPinned == 1) ...[
                          _StatusMark(
                            icon: Icons.push_pin,
                            color: accentColor,
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (note.isStarred == 1)
                          _StatusMark(
                            icon: Icons.star_rounded,
                            color: Colors.amber[700]!,
                          ),
                      ],
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
}

class _StatusMark extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StatusMark({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        icon,
        size: 11,
        color: color,
      ),
    );
  }
}
