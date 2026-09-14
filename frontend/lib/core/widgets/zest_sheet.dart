import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

/// Shows Zest's modal bottom sheet. Most callers render the default title
/// row (a heading plus a ringed close icon) inside the sheet's page padding.
/// A caller with a bolder header — full-bleed art, its own close control —
/// passes [header] instead: it renders edge-to-edge above the padded [child]
/// and is responsible for its own dismissal (typically `Navigator.of(context
/// ).pop()` from a close button). [title] still names the sheet for the
/// dismiss barrier's semantics even when [header] supplies the visible
/// heading.
Future<T?> showZestSheet<T>({
  required BuildContext context,
  required String title,
  WidgetBuilder? header,
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
        child: header != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ZestSpace.page,
                      ZestSpace.lg,
                      ZestSpace.page,
                      ZestSpace.page,
                    ),
                    child: child,
                  ),
                ],
              )
            : Padding(
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
