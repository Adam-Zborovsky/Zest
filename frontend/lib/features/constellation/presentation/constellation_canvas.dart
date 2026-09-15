import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/design/zest_tokens.dart';
import '../domain/graph_layout.dart';
import '../domain/ingredient_graph.dart';
import 'constellation_painter.dart';
import 'constellation_scene.dart';

/// Hit-target bounds, in screen pixels at every zoom. A node of any size
/// answers taps within a 48-logical-pixel diameter around its center
/// ([maxHitRadius]); an edge answers within [edgeHitHalfWidth] of its curve.
///
/// [edgeHitHalfWidth] is a recorded 32-pixel hit-target exception, deliberate
/// because every edge has three non-canvas equivalents at full size: the
/// info-surface button under the canvas, the list-view connection rows, and
/// the shared-recipes sheet each open the same edge without a corridor.
const maxHitRadius = 24.0;
const edgeHitHalfWidth = 16.0;

/// The interactive constellation: a borderless, pannable, zoomable view
/// onto a world larger than the canvas, whose nodes float, can be dragged,
/// and answer taps.
///
/// Gestures. One finger never moves the view, so the page scrolls through
/// the canvas like any other content:
/// - a tap on a node selects it, a tap on a line opens it, a tap on open
///   space clears the selection, and a double tap there returns to the
///   opening view;
/// - a long press on a node picks it up to drag — neighbors are tugged
///   along and discs in the way are shoved aside;
/// - two fingers pan and pinch-zoom together;
/// - with a mouse, dragging a node moves it and dragging open space pans
///   (with a fling); Ctrl+wheel or a trackpad pinch zooms around the
///   cursor, and a plain wheel scrolls the page.
///
/// Performance contract (the 60fps bar): the layout is computed once per
/// graph or canvas-size change — never per frame, and never when only the
/// selection or search filter changes. Paint data is prepared once per state
/// change; per frame the ticker advances the scene springs and the painter
/// reads precomputed paints, so the frame cost is O(nodes + edges) at the
/// bounded 40-node view. The painter repaints through a notifier, never a
/// widget rebuild. The ticker runs while ambient float is on, and otherwise
/// only while something is settling. The canvas is decorative and excluded
/// from semantics; the list view carries the accessible equivalent.
///
/// Reduced motion creates no ticker at all: no entrance, float, fling, or
/// animated reset. Dragging, panning, and zooming still work and move
/// things directly.
class ConstellationCanvas extends StatefulWidget {
  const ConstellationCanvas({
    super.key,
    required this.graph,
    required this.onSelectNode,
    required this.onSelectEdge,
    this.selectedNodeId,
    this.selectedEdge,
    this.query = '',
  });

  final IngredientGraph graph;
  final String? selectedNodeId;
  final IngredientEdge? selectedEdge;
  final ValueChanged<String?> onSelectNode;
  final ValueChanged<IngredientEdge?> onSelectEdge;
  final String query;

  /// How much larger than the canvas the world the layout spreads over is,
  /// per axis. The opening view shows nearly all of it; the rest is found
  /// by panning.
  static const worldScale = (width: 1.35, height: 1.25);

  /// The opening zoom relative to fitting the whole world: every node is
  /// on the canvas at first, the outermost ones softened by the edge fade.
  static const openingZoom = 1.0;

  /// Zoom bounds: out to [minZoomOfFit] of the fitted world, in to [maxZoom].
  static const minZoomOfFit = 0.6;
  static const maxZoom = 3.0;

  static Size worldSizeFor(Size canvas) =>
      Size(canvas.width * worldScale.width, canvas.height * worldScale.height);

  @override
  State<ConstellationCanvas> createState() => ConstellationCanvasState();
}

/// A pointer sequence the canvas itself owns: a mouse drag of a node or of
/// open space, or a two-finger pan and pinch. Long-press node drags and
/// taps come from their own recognizers.
enum _Gesture { none, pan, drag, pinch }

class ConstellationCanvasState extends State<ConstellationCanvas>
    with TickerProviderStateMixin {
  ConstellationScene? _scene;
  Size? _laidOutSize;
  IngredientGraph? _laidOutGraph;
  bool _everAnimated = false;
  ConstellationPaintData? _paintData;
  AnimationController? _pop;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  final _frame = _FrameNotifier();

  final _camera = ConstellationCamera();
  Size _viewport = Size.zero;
  Size _world = Size.zero;
  double _homeScale = 1;
  Offset _homeOrigin = Offset.zero;
  double _minScale = 0.1;
  bool _returningHome = false;
  Offset _fling = Offset.zero;

  final _pointers = <int, Offset>{};
  _Gesture _gesture = _Gesture.none;
  bool _holdingNode = false;
  Offset _downPosition = Offset.zero;
  bool _tapCandidate = false;
  VelocityTracker? _panVelocity;
  double _pinchStartDistance = 1;
  double _pinchStartScale = 1;
  Offset _pinchWorldFocal = Offset.zero;
  final _tapClock = Stopwatch()..start();
  Duration? _lastOpenTap;
  Offset _lastOpenTapPosition = Offset.zero;

  bool get _reducedMotion => ZestMotion.reduced(context);

  /// Where [identity] is drawn right now, in canvas-local pixels.
  @visibleForTesting
  Offset screenPositionOf(String identity) =>
      _camera.toScreen(_scene!.positionOf(identity));

  @visibleForTesting
  double get cameraScale => _camera.scale;

  @visibleForTesting
  Offset get cameraOrigin => _camera.origin;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion requested mid-animation: stop ticking and rebuild the
    // scene without springs. Reduced motion never *starts* a ticker; this
    // only ends a running one.
    if (_reducedMotion) {
      _ticker?.stop();
      _pop?.dispose();
      _pop = null;
      _returningHome = false;
      _fling = Offset.zero;
      if (_scene?.animated ?? false) _laidOutSize = null;
    }
  }

  @override
  void didUpdateWidget(ConstellationCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedNodeId;
    if (selected != null &&
        selected != oldWidget.selectedNodeId &&
        !_reducedMotion) {
      final pop = _pop ??= AnimationController(
        vsync: this,
        duration: ZestMotion.pop,
      );
      pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _pop?.dispose();
    _paintData?.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// Computes the layout and a fresh scene when the graph or the canvas
  /// size changed, and — in motion mode only, and only once per State
  /// lifetime — springs the nodes in from a seeded scatter. Selection and
  /// filter changes never reach this.
  void _ensureScene(Size size) {
    if (identical(_laidOutGraph, widget.graph) && _laidOutSize == size) return;
    _laidOutGraph = widget.graph;
    _laidOutSize = size;
    final world = ConstellationCanvas.worldSizeFor(size);
    final layout = GraphLayout.compute(widget.graph, size: world);
    final animated = !_reducedMotion;
    final entrance =
        animated && !_everAnimated && widget.graph.nodes.length >= 2;
    if (entrance) _everAnimated = true;
    _scene = ConstellationScene(
      graph: widget.graph,
      layout: layout,
      worldSize: world,
      animated: animated,
      ambient: ZestMotion.ambientMotion,
      entranceFrom: entrance ? _scatter(widget.graph, world) : null,
    );
    _fitCamera(size, world);
    _pointers.clear();
    _gesture = _Gesture.none;
    _holdingNode = false;
    if (animated) _wake();
  }

  /// The seeded scatter the entrance springs from: the deterministic
  /// initial placement, pulled toward the center.
  static Map<String, Offset> _scatter(IngredientGraph graph, Size world) {
    final layout = GraphLayout.compute(graph, size: world, iterations: 0);
    final center = world.center(Offset.zero);
    return {
      for (final entry in layout.positions.entries)
        entry.key: Offset.lerp(center, entry.value, 0.35)!,
    };
  }

  void _fitCamera(Size viewport, Size world) {
    _viewport = viewport;
    _world = world;
    final fit = math.min(
      viewport.width / world.width,
      viewport.height / world.height,
    );
    _minScale = fit * ConstellationCanvas.minZoomOfFit;
    _homeScale = math.min(1.0, fit * ConstellationCanvas.openingZoom);
    _homeOrigin =
        viewport.center(Offset.zero) - world.center(Offset.zero) * _homeScale;
    _camera
      ..scale = _homeScale
      ..origin = _homeOrigin;
    _fling = Offset.zero;
    _returningHome = false;
  }

  /// Keeps at least 30% of the canvas on each axis over the world, so the
  /// constellation can be pushed aside but never lost.
  Offset _clampOrigin(Offset origin, double scale) {
    final width = _world.width * scale;
    final height = _world.height * scale;
    return Offset(
      origin.dx.clamp(_viewport.width * 0.3 - width, _viewport.width * 0.7),
      origin.dy.clamp(_viewport.height * 0.3 - height, _viewport.height * 0.7),
    );
  }

  void _wake() {
    if (_reducedMotion) return;
    final ticker = _ticker ??= createTicker(_tick);
    if (ticker.isActive) return;
    _lastTick = Duration.zero;
    ticker.start();
  }

  void _tick(Duration elapsed) {
    final seconds = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final scene = _scene;
    var busy = scene?.step(seconds) ?? false;
    busy = _stepCamera(seconds) || busy;
    _frame.ping();
    if (!busy && !(scene?.ambient ?? false)) _ticker?.stop();
  }

  bool _stepCamera(double seconds) {
    if (_returningHome) {
      final t = 1 - math.exp(-seconds * 10);
      _camera
        ..scale = _camera.scale + (_homeScale - _camera.scale) * t
        ..origin = Offset.lerp(_camera.origin, _homeOrigin, t)!;
      if ((_camera.scale - _homeScale).abs() < 0.001 &&
          (_camera.origin - _homeOrigin).distance < 0.5) {
        _camera
          ..scale = _homeScale
          ..origin = _homeOrigin;
        _returningHome = false;
        return false;
      }
      return true;
    }
    if (_fling != Offset.zero) {
      _camera.origin = _clampOrigin(
        _camera.origin + _fling * seconds,
        _camera.scale,
      );
      _fling *= math.exp(-seconds * 5);
      if (_fling.distance < 12) {
        _fling = Offset.zero;
        return false;
      }
      return true;
    }
    return false;
  }

  void _stopCameraMotion() {
    _fling = Offset.zero;
    _returningHome = false;
  }

  String? _nodeAt(Offset local) => _scene?.nodeAt(
    _camera.toWorld(local),
    minHitRadius: maxHitRadius / _camera.scale,
  );

  void _handlePointerDown(PointerDownEvent event) {
    final scene = _scene;
    if (scene == null) return;
    _pointers[event.pointer] = event.localPosition;
    if (event.kind == PointerDeviceKind.mouse) {
      _stopCameraMotion();
      _downPosition = event.localPosition;
      _tapCandidate = true;
      final node = _nodeAt(event.localPosition);
      if (node != null) {
        scene.grab(node, _camera.toWorld(event.localPosition));
        _gesture = _Gesture.drag;
        _wake();
      } else {
        _gesture = _Gesture.pan;
        _panVelocity = VelocityTracker.withKind(event.kind)
          ..addPosition(event.timeStamp, event.localPosition);
      }
    } else if (_pointers.length >= 2 && !_holdingNode) {
      _stopCameraMotion();
      _startPinch();
    }
    _frame.ping();
  }

  void _startPinch() {
    final points = _pointers.values.take(2).toList();
    _pinchStartDistance = math.max(1, (points[0] - points[1]).distance);
    _pinchStartScale = _camera.scale;
    _pinchWorldFocal = _camera.toWorld((points[0] + points[1]) / 2);
    _gesture = _Gesture.pinch;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final previous = _pointers[event.pointer];
    final scene = _scene;
    if (previous == null || scene == null) return;
    final position = event.localPosition;
    _pointers[event.pointer] = position;
    if (_tapCandidate && (position - _downPosition).distance > kTouchSlop) {
      _tapCandidate = false;
    }
    switch (_gesture) {
      case _Gesture.drag:
        scene.dragTo(_camera.toWorld(position));
        _wake();
      case _Gesture.pan:
        _panVelocity?.addPosition(event.timeStamp, position);
        _camera.origin = _clampOrigin(
          _camera.origin + (position - previous),
          _camera.scale,
        );
      case _Gesture.pinch:
        final points = _pointers.values.take(2).toList();
        final scale =
            (_pinchStartScale *
                    (points[0] - points[1]).distance /
                    _pinchStartDistance)
                .clamp(_minScale, ConstellationCanvas.maxZoom);
        final focal = (points[0] + points[1]) / 2;
        _camera
          ..scale = scale
          ..origin = _clampOrigin(focal - _pinchWorldFocal * scale, scale);
      case _Gesture.none:
        return;
    }
    _frame.ping();
  }

  void _handlePointerEnd(int pointer, {required bool cancelled}) {
    final position = _pointers.remove(pointer);
    final scene = _scene;
    if (position == null || scene == null) return;
    switch (_gesture) {
      case _Gesture.pinch:
        // Lifting one of two fingers ends the pinch; a single finger left
        // behind never pans.
        if (_pointers.length >= 2) {
          _startPinch();
        } else {
          _gesture = _Gesture.none;
        }
      case _Gesture.drag:
        _gesture = _Gesture.none;
        final held = scene.draggedIdentity;
        scene.release();
        if (_tapCandidate && !cancelled && held != null) {
          widget.onSelectEdge(null);
          widget.onSelectNode(held);
        }
      case _Gesture.pan:
        _gesture = _Gesture.none;
        final velocity = _panVelocity?.getVelocity().pixelsPerSecond;
        _panVelocity = null;
        if (_tapCandidate && !cancelled) {
          _handleOpenTap(position);
        } else if (!cancelled &&
            !_reducedMotion &&
            velocity != null &&
            velocity.distance > 120) {
          _fling = velocity;
          _wake();
        }
      case _Gesture.none:
        break;
    }
    _frame.ping();
  }

  /// A touch tap (mouse clicks are handled with the mouse's own sequence).
  void _handleTapUp(TapUpDetails details) {
    if (details.kind == PointerDeviceKind.mouse) return;
    final node = _nodeAt(details.localPosition);
    if (node != null) {
      _lastOpenTap = null;
      widget.onSelectEdge(null);
      widget.onSelectNode(node);
      return;
    }
    _handleOpenTap(details.localPosition);
  }

  /// A tap away from every node: an edge under it opens that edge; a second
  /// tap on open space in quick succession returns to the opening view;
  /// otherwise the selection clears.
  void _handleOpenTap(Offset local) {
    final scene = _scene!;
    final world = _camera.toWorld(local);
    final corridor = edgeHitHalfWidth / _camera.scale;
    for (final edge in widget.graph.edges) {
      final a = scene.positionOf(edge.aIdentity);
      final b = scene.positionOf(edge.bIdentity);
      if (_distanceToSegment(world, a, b) <= corridor) {
        _lastOpenTap = null;
        widget.onSelectNode(null);
        widget.onSelectEdge(edge);
        return;
      }
    }
    final now = _tapClock.elapsed;
    final last = _lastOpenTap;
    if (last != null &&
        now - last <= kDoubleTapTimeout &&
        (local - _lastOpenTapPosition).distance <= kDoubleTapSlop) {
      _lastOpenTap = null;
      _returnHome();
      return;
    }
    _lastOpenTap = now;
    _lastOpenTapPosition = local;
    widget.onSelectNode(null);
    widget.onSelectEdge(null);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final scene = _scene;
    final node = _nodeAt(details.localPosition);
    if (scene == null || node == null || _gesture != _Gesture.none) return;
    _stopCameraMotion();
    scene.grab(node, _camera.toWorld(details.localPosition));
    _holdingNode = true;
    HapticFeedback.selectionClick();
    _wake();
    _frame.ping();
  }

  void _handleLongPressMove(LongPressMoveUpdateDetails details) {
    if (!_holdingNode) return;
    _scene?.dragTo(_camera.toWorld(details.localPosition));
    _wake();
    _frame.ping();
  }

  void _endHold() {
    if (!_holdingNode) return;
    _holdingNode = false;
    _scene?.release();
    _frame.ping();
  }

  void _returnHome() {
    _fling = Offset.zero;
    if (_reducedMotion) {
      _camera
        ..scale = _homeScale
        ..origin = _homeOrigin;
      _frame.ping();
      return;
    }
    _returningHome = true;
    _wake();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    final double factor;
    if (event is PointerScaleEvent) {
      factor = event.scale;
    } else if (event is PointerScrollEvent &&
        HardwareKeyboard.instance.isControlPressed) {
      factor = math.exp(-event.scrollDelta.dy / 300);
    } else {
      // A plain wheel belongs to the page scroll.
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final focal = resolved.localPosition;
      final world = _camera.toWorld(focal);
      final scale = (_camera.scale * factor).clamp(
        _minScale,
        ConstellationCanvas.maxZoom,
      );
      _stopCameraMotion();
      _camera
        ..scale = scale
        ..origin = _clampOrigin(focal - world * scale, scale);
      _frame.ping();
    });
  }

  static double _distanceToSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.distanceSquared;
    if (lengthSquared == 0) return (point - a).distance;
    final ap = point - a;
    var t = (ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    return (point - (a + ab * t)).distance;
  }

  /// The selected node's radius multiplier: a single soft swell that returns
  /// exactly to 1 when the pop completes.
  double _selectionScale() {
    final pop = _pop;
    if (pop == null || !pop.isAnimating) return 1;
    final t = Curves.easeOut.transform(pop.value);
    return 1 + 0.22 * math.sin(math.pi * t);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.isEmpty) return const SizedBox.expand();
        _ensureScene(size);
        final scene = _scene!;
        final paintData = ConstellationPaintData(
          graph: widget.graph,
          selectedNode: widget.selectedNodeId == null
              ? null
              : widget.graph.node(widget.selectedNodeId!),
          selectedEdge: widget.selectedEdge,
          query: widget.query,
          labelStyle: Theme.of(
            context,
          ).textTheme.labelSmall!.copyWith(color: ZestPalette.leaf),
        );
        // Each prepared paint data owns laid-out TextPainters; dispose the
        // previous set when a new one replaces it, or selection and search
        // changes would leak a label set per rebuild.
        _paintData?.dispose();
        _paintData = paintData;

        // The gesture layer is decorative too: without ExcludeSemantics the
        // detector would surface an unlabeled target to screen readers. The
        // list view is the accessible route to every node and edge.
        return ExcludeSemantics(
          child: Listener(
            onPointerSignal: _handlePointerSignal,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                _CanvasPointerRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      _CanvasPointerRecognizer
                    >(() => _CanvasPointerRecognizer(debugOwner: this), (
                      recognizer,
                    ) {
                      recognizer
                        ..onDown = _handlePointerDown
                        ..onMove = _handlePointerMove
                        ..onEnd = _handlePointerEnd;
                    }),
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                      () => TapGestureRecognizer(debugOwner: this),
                      (recognizer) => recognizer.onTapUp = _handleTapUp,
                    ),
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(() => LongPressGestureRecognizer(debugOwner: this), (
                      recognizer,
                    ) {
                      recognizer
                        ..onLongPressStart = _handleLongPressStart
                        ..onLongPressMoveUpdate = _handleLongPressMove
                        ..onLongPressEnd = ((_) => _endHold())
                        ..onLongPressCancel = _endHold;
                    }),
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                // RepaintBoundary keeps the per-frame repaints inside this
                // layer instead of the whole page.
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: ConstellationPainter(
                      data: paintData,
                      scene: scene,
                      camera: _camera,
                      selectionScale: _selectionScale,
                      repaint: Listenable.merge([_frame, ?_pop]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _FrameNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Claims the pointers the canvas moves the view with, and only those, so a
/// single finger stays with the page scroll:
/// - a mouse pointer is claimed the moment it goes down (a mouse drag never
///   scrolls the page);
/// - a touch pointer is claimed only once a second touch joins it, turning
///   both into a two-finger pan and pinch. A lone touch that lifts is
///   released to the tap recognizer.
class _CanvasPointerRecognizer extends OneSequenceGestureRecognizer {
  _CanvasPointerRecognizer({super.debugOwner});

  ValueChanged<PointerDownEvent>? onDown;
  ValueChanged<PointerMoveEvent>? onMove;
  void Function(int pointer, {required bool cancelled})? onEnd;

  final _pending = <int>{};
  final _accepted = <int>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    onDown?.call(event);
    if (event.kind == PointerDeviceKind.mouse) {
      resolvePointer(event.pointer, GestureDisposition.accepted);
      return;
    }
    _pending.add(event.pointer);
    if (_pending.length + _accepted.length >= 2) {
      for (final pointer in _pending.toList()) {
        resolvePointer(pointer, GestureDisposition.accepted);
      }
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onMove?.call(event);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_pending.remove(event.pointer)) {
        // Never claimed: leave the sequence to the tap recognizer.
        resolvePointer(event.pointer, GestureDisposition.rejected);
      } else {
        _accepted.remove(event.pointer);
      }
      onEnd?.call(event.pointer, cancelled: event is PointerCancelEvent);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) {
    _pending.remove(pointer);
    _accepted.add(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    _pending.remove(pointer);
    _accepted.remove(pointer);
    onEnd?.call(pointer, cancelled: true);
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'constellation canvas';
}
