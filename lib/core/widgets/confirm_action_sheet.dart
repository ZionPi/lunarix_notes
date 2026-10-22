import 'package:flutter/material.dart';

Future<bool> confirmActionSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(message, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: FilledButton(
                            style: destructive
                                ? FilledButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.error)
                                : null,
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(confirmLabel))),
                  ]),
                ]),
          ),
        ),
      ) ??
      false;
}
