import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

Future<T?> showZestSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  requestFocus: true,
  showDragHandle: false,
  barrierLabel: 'Dismiss $title',
  sheetAnimationStyle: ZestMotion.sheetStyle(context),
  builder: (context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(ZestSpace.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: ZestShape.control,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ZestSpace.md),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    autofocus: true,
                    tooltip: 'Close $title',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: ZestSpace.lg),
              child,
            ],
          ),
        ),
      ),
    ),
  ),
);
