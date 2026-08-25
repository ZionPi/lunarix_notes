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
  final bool showDragHandle;
  final int? dragIndex;

  const NoteCard({
    super.key,
    required this.note,
    required this.onDelete,
    required this.onTogglePin,
    required this.onToggleStar,
    required this.onCopyContent,
    required this.onNoteUpdated,
    this.showDragHandle = false,
    this.dragIndex,
  });

  String _formatDisplayDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
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

  String _buildPreviewText({int length = 40, bool useTitleFallback = true}) {
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
    final cardTheme = Theme.of(context).cardTheme;
    final cardBackgroundColor = cardTheme.color ?? Colors.white;
    final cardBrightness = ThemeData.estimateBrightnessForColor(
      cardBackgroundColor,
    );
    final textColorOnCard =
        cardBrightness == Brightness.dark ? Colors.white : Colors.black87;
    final accentColor = Theme.of(context).colorScheme.primary;
    final mutedTextColor = textColorOnCard.withValues(alpha: 0.66);
    final chipBackground = cardBrightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.05);
    final chipBorder = cardBrightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.06);
    final isWhiteCard = cardBackgroundColor.computeLuminance() > 0.96;
    final polishedCardColor = cardBrightness == Brightness.dark || isWhiteCard
        ? cardBackgroundColor
        : Color.alphaBlend(
            cardBackgroundColor.withValues(alpha: 0.88),
            Colors.white,
          );
    final cardBorderColor = cardBrightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.05);

    final displayTitle =
        _isDefaultTimestampTitle(note.title) ? '' : note.title.trim();
    final previewText = _buildPreviewText(
      useTitleFallback: displayTitle.isEmpty,
    );
    final hasImages = RegExp(r'!\[[^\]]*\]\([^)]+\)').hasMatch(note.content);
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
        color: polishedCardColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: cardBorderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
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
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      13,
                      showDragHandle ? 6 : 14,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (displayTitle.isNotEmpty) ...[
                              Expanded(
                                child: Text(
                                  displayTitle,
                                  style: TextStyle(
                                    fontSize: 17,
                                    height: 1.18,
                                    fontWeight: FontWeight.w800,
                                    color: textColorOnCard,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (displayTitle.isEmpty) const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: chipBackground,
                                border: Border.all(color: chipBorder),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                formattedTime,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: mutedTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: displayTitle.isEmpty ? 12 : 18),
                        Expanded(
                          child: previewText.isEmpty
                              ? const SizedBox.shrink()
                              : Text(
                                  previewText,
                                  style: TextStyle(
                                    fontSize: displayTitle.isEmpty ? 17 : 14,
                                    height: displayTitle.isEmpty ? 1.46 : 1.42,
                                    fontWeight: displayTitle.isEmpty
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: displayTitle.isEmpty
                                        ? textColorOnCard
                                        : textColorOnCard.withValues(
                                            alpha: 0.78),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                        SizedBox(
                          height: 18,
                          child: Row(
                            children: [
                              if (hasImages) ...[
                                _StatusMark(
                                  icon: Icons.image_outlined,
                                  color: mutedTextColor,
                                ),
                                const SizedBox(width: 6),
                              ],
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
                if (showDragHandle)
                  ReorderableDragStartListener(
                    index: dragIndex ?? 0,
                    child: Container(
                      width: 54,
                      height: double.infinity,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: Container(
                        width: 34,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 26,
                          color: textColorOnCard.withValues(alpha: 0.44),
                        ),
                      ),
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

class _StatusMark extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StatusMark({required this.icon, required this.color});

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
      child: Icon(icon, size: 11, color: color),
    );
  }
}
