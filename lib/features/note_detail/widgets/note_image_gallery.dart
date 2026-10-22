import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/confirm_action_sheet.dart';

/// Image management only changes Markdown order, never the underlying files.
class NoteImageGallery extends StatelessWidget {
  final List<String> uris;
  final ValueChanged<int> onRemove;
  final void Function(int from, int to) onReorder;
  final VoidCallback onAdd;

  const NoteImageGallery({
    super.key,
    required this.uris,
    required this.onRemove,
    required this.onReorder,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (uris.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('${uris.length} 张图片', style: theme.textTheme.titleSmall),
          const SizedBox(width: 10),
          Expanded(
              child: Text('点按预览 · 长按拖动排序', style: theme.textTheme.bodySmall)),
          IconButton(
              onPressed: onAdd,
              tooltip: '添加图片',
              icon: const Icon(Icons.add_photo_alternate_outlined)),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final columns =
              uris.length == 1 ? 1 : (constraints.maxWidth > 600 ? 3 : 2);
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < uris.length; i++)
                SizedBox(
                  key: ValueKey('image-$i-${uris[i]}'),
                  width: width,
                  height: columns == 1 ? width * 0.75 : width * 1.05,
                  child: DragTarget<int>(
                    onWillAcceptWithDetails: (details) => details.data != i,
                    onAcceptWithDetails: (details) =>
                        onReorder(details.data, i),
                    builder: (context, candidates, rejected) =>
                        LongPressDraggable<int>(
                      data: i,
                      onDragStarted: () => HapticFeedback.selectionClick(),
                      feedback: Material(
                        elevation: 12,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                            width: width * 0.85,
                            height: width * 0.85,
                            child: NoteImage(uri: uris[i])),
                      ),
                      childWhenDragging: Container(
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: EdgeInsets.all(candidates.isEmpty ? 0 : 4),
                        decoration: BoxDecoration(
                          color: candidates.isEmpty
                              ? const Color(0xFFEBEEE8)
                              : theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(fit: StackFit.expand, children: [
                            Material(
                              color: const Color(0xFFEBEEE8),
                              child: InkWell(
                                key: ValueKey('preview-image-$i'),
                                onTap: () =>
                                    showNoteImageViewer(context, uris, i),
                                child: NoteImage(
                                    uri: uris[i], fit: BoxFit.contain),
                              ),
                            ),
                            Positioned(
                                left: 10,
                                bottom: 10,
                                child: _Badge(
                                    child: Text('${i + 1}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12)))),
                            Positioned(
                                right: 4,
                                top: 4,
                                child: PopupMenuButton<String>(
                                  tooltip: '图片操作',
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.90),
                                    foregroundColor: const Color(0xFF44564B),
                                  ),
                                  itemBuilder: (_) => [
                                    if (i > 0)
                                      const PopupMenuItem(
                                          value: 'first', child: Text('移到第一张')),
                                    const PopupMenuItem(
                                        value: 'remove', child: Text('移除图片')),
                                  ],
                                  onSelected: (action) async {
                                    if (action == 'first') {
                                      onReorder(i, 0);
                                      return;
                                    }
                                    final remove = await confirmActionSheet(
                                        context,
                                        title: '从笔记移除这张图片？',
                                        message: '可撤销恢复，原始图片文件仍会保留。',
                                        confirmLabel: '移除',
                                        destructive: true);
                                    if (remove == true) onRemove(i);
                                  },
                                  icon: const Icon(Icons.more_horiz_rounded,
                                      size: 20),
                                )),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;
  const _Badge({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(8)),
        child: child,
      );
}

class NoteImage extends StatelessWidget {
  final String uri;
  final BoxFit fit;
  const NoteImage({super.key, required this.uri, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    final parsed = Uri.tryParse(uri);
    Widget broken(BuildContext _, Object error, StackTrace? trace) =>
        const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.broken_image_outlined, color: Color(0xFF89958D)),
            SizedBox(height: 8),
            Text('图片暂时无法读取',
                style: TextStyle(color: Color(0xFF89958D), fontSize: 12)),
          ]),
        );
    if (parsed?.scheme == 'file') {
      return Image.file(File(parsed!.toFilePath()),
          fit: fit, errorBuilder: broken);
    }
    if (parsed?.scheme == 'https' || parsed?.scheme == 'http') {
      return Image.network(uri, fit: fit, errorBuilder: broken);
    }
    return broken(
        context, const FormatException('Unsupported image URI'), null);
  }
}

void showNoteImageViewer(BuildContext context, List<String> uris, int index) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => _ImageViewer(uris: List.of(uris), initialIndex: index),
  ));
}

class _ImageViewer extends StatefulWidget {
  final List<String> uris;
  final int initialIndex;
  const _ImageViewer({required this.uris, required this.initialIndex});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF121614),
        appBar: AppBar(
          backgroundColor: const Color(0xFF121614),
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: IconButton(
              onPressed: () => Navigator.pop(context),
              tooltip: '关闭预览',
              icon: const Icon(Icons.close_rounded)),
          title: Text('${_index + 1} / ${widget.uris.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          centerTitle: true,
        ),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: PageView.builder(
            controller: _controller,
            itemCount: widget.uris.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (_, index) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: SizedBox.expand(child: NoteImage(uri: widget.uris[index])),
            ),
          )),
          const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '双指缩放查看细节 · 左右滑动切换',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              )),
        ])),
      );
}
