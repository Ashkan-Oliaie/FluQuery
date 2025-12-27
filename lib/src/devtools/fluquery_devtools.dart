import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/query_client.dart';
import '../widgets/query_client_provider.dart';
import 'devtools_controller.dart';
import 'widgets/devtools_panel.dart';

/// FluQuery Devtools - Visual debugging tool for inspecting queries and cache.
///
/// ## Usage Option 1: Wrap your app (recommended for full control)
/// ```dart
/// MaterialApp(
///   builder: (context, child) {
///     return FluQueryDevtools(child: child!);
///   },
///   home: MyHomePage(),
/// )
/// ```
///
/// ## Usage Option 2: Via QueryClientConfig (simpler)
/// ```dart
/// QueryClient(
///   config: QueryClientConfig(
///     enableDevtools: true, // defaults to kDebugMode
///   ),
/// )
/// ```
///
/// Features:
/// - View all cached queries, services, and stores
/// - See stale vs fresh queries at a glance
/// - Manually refetch, invalidate, or reset queries
/// - View retry history and cache timers
/// - Drag to move, resize from edges
/// - Mobile-friendly: auto full-width on small screens
///
/// Toggle with the floating button or keyboard shortcut (Shift+D).
class FluQueryDevtools extends StatefulWidget {
  final Widget child;

  /// The QueryClient to inspect.
  ///
  /// If not provided, will attempt to get from context via QueryClientProvider.
  final QueryClient? client;

  /// Whether to show devtools (defaults to true)
  final bool enabled;

  /// Initial position of the toggle button
  final DevtoolsPosition buttonPosition;

  /// Custom button builder
  final Widget Function(BuildContext, bool isOpen, VoidCallback toggle)?
      buttonBuilder;

  const FluQueryDevtools({
    super.key,
    required this.child,
    this.client,
    this.enabled = true,
    this.buttonPosition = DevtoolsPosition.bottomRight,
    this.buttonBuilder,
  });

  @override
  State<FluQueryDevtools> createState() => _FluQueryDevtoolsState();
}

class _FluQueryDevtoolsState extends State<FluQueryDevtools> {
  bool _isOpen = false;
  late final FocusNode _focusNode;

  // Panel position and size
  double _panelX = 0;
  double _panelY = 0;
  double _panelWidth = 420;
  double _panelHeight = 500;
  bool _positionInitialized = false;

  static const double _minWidth = 320;
  static const double _minHeight = 300;
  static const double _maxWidth = 800;
  static const double _maxHeight = 900;
  static const double _mobileBreakpoint = 600;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
  }

  void _handleKeyEvent(KeyEvent event) {
    // Shift+D to toggle
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyD &&
        HardwareKeyboard.instance.isShiftPressed) {
      _toggle();
    }
  }

  void _initializePanelPosition(Size screenSize) {
    if (_positionInitialized) return;
    _positionInitialized = true;

    final isMobile = screenSize.width < _mobileBreakpoint;

    if (isMobile) {
      // Mobile: full width, bottom half
      _panelWidth = screenSize.width;
      _panelHeight = screenSize.height * 0.6;
      _panelX = 0;
      _panelY = screenSize.height - _panelHeight;
    } else {
      // Desktop: floating panel on the right
      _panelWidth = 420;
      _panelHeight = 500.0.clamp(_minHeight, screenSize.height - 100);
      _panelX = screenSize.width - _panelWidth - 16;
      _panelY = (screenSize.height - _panelHeight) / 2;
    }
  }

  QueryClient? _getClient(BuildContext context) {
    // Use provided client or try to get from context
    return widget.client ?? QueryClientProvider.maybeOf(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final client = _getClient(context);

    // If no client available, just show the child without devtools
    if (client == null) {
      return widget.child;
    }

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,

            // Use LayoutBuilder only for the panel to get screen size
            if (_isOpen)
              LayoutBuilder(
                builder: (context, constraints) {
                  final screenSize =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  _initializePanelPosition(screenSize);
                  final isMobile = screenSize.width < _mobileBreakpoint;

                  return Stack(
                    children: [
                      // Devtools panel (draggable/resizable)
                      Positioned(
                        left: _panelX,
                        top: _panelY,
                        child: _DevtoolsPanel(
                          client: client,
                          width: _panelWidth,
                          height: _panelHeight,
                          minWidth: isMobile ? screenSize.width : _minWidth,
                          minHeight: _minHeight,
                          maxWidth: isMobile
                              ? screenSize.width
                              : _maxWidth.clamp(0, screenSize.width - 32),
                          maxHeight:
                              _maxHeight.clamp(0, screenSize.height - 32),
                          isMobile: isMobile,
                          onMove: (delta) {
                            setState(() {
                              _panelX = (_panelX + delta.dx)
                                  .clamp(0, screenSize.width - _panelWidth);
                              _panelY = (_panelY + delta.dy)
                                  .clamp(0, screenSize.height - _panelHeight);
                            });
                          },
                          onResize: (newWidth, newHeight) {
                            setState(() {
                              _panelWidth = newWidth;
                              _panelHeight = newHeight;
                              // Keep panel in bounds
                              _panelX = _panelX.clamp(
                                  0, screenSize.width - _panelWidth);
                              _panelY = _panelY.clamp(
                                  0, screenSize.height - _panelHeight);
                            });
                          },
                          onClose: _toggle,
                        ),
                      ),
                    ],
                  );
                },
              ),

            // Toggle button
            Positioned(
              right: widget.buttonPosition == DevtoolsPosition.bottomRight
                  ? 16
                  : null,
              left: widget.buttonPosition == DevtoolsPosition.bottomLeft
                  ? 16
                  : null,
              bottom: 16,
              child: widget.buttonBuilder?.call(context, _isOpen, _toggle) ??
                  _DefaultDevtoolsButton(
                    isOpen: _isOpen,
                    onPressed: _toggle,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Main panel with drag and resize functionality
class _DevtoolsPanel extends StatefulWidget {
  final QueryClient client;
  final double width;
  final double height;
  final double minWidth;
  final double minHeight;
  final double maxWidth;
  final double maxHeight;
  final bool isMobile;
  final void Function(Offset delta) onMove;
  final void Function(double width, double height) onResize;
  final VoidCallback onClose;

  const _DevtoolsPanel({
    required this.client,
    required this.width,
    required this.height,
    required this.minWidth,
    required this.minHeight,
    required this.maxWidth,
    required this.maxHeight,
    required this.isMobile,
    required this.onMove,
    required this.onResize,
    required this.onClose,
  });

  @override
  State<_DevtoolsPanel> createState() => _DevtoolsPanelState();
}

class _DevtoolsPanelState extends State<_DevtoolsPanel> {
  late final DevtoolsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DevtoolsController(widget.client);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          // Main panel with Overlay for tooltips
          ClipRRect(
            borderRadius: BorderRadius.circular(widget.isMobile ? 0 : 12),
            child: Localizations(
              locale: const Locale('en', 'US'),
              delegates: const [
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
              ],
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (_) => DevtoolsPanel(
                      controller: _controller,
                      onClose: widget.onClose,
                      onDragHeader: widget.isMobile ? null : widget.onMove,
                      isMobile: widget.isMobile,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Resize handles (desktop only)
          if (!widget.isMobile) ...[
            // Right edge
            Positioned(
              right: 0,
              top: 20,
              bottom: 20,
              child: _ResizeHandle(
                cursor: SystemMouseCursors.resizeLeftRight,
                onDrag: (delta) {
                  final newWidth = (widget.width + delta.dx)
                      .clamp(widget.minWidth, widget.maxWidth);
                  widget.onResize(newWidth, widget.height);
                },
              ),
            ),
            // Bottom edge
            Positioned(
              left: 20,
              right: 20,
              bottom: 0,
              child: _ResizeHandle(
                cursor: SystemMouseCursors.resizeUpDown,
                onDrag: (delta) {
                  final newHeight = (widget.height + delta.dy)
                      .clamp(widget.minHeight, widget.maxHeight);
                  widget.onResize(widget.width, newHeight);
                },
              ),
            ),
            // Bottom-right corner
            Positioned(
              right: 0,
              bottom: 0,
              child: _ResizeHandle(
                cursor: SystemMouseCursors.resizeDownRight,
                size: 16,
                onDrag: (delta) {
                  final newWidth = (widget.width + delta.dx)
                      .clamp(widget.minWidth, widget.maxWidth);
                  final newHeight = (widget.height + delta.dy)
                      .clamp(widget.minHeight, widget.maxHeight);
                  widget.onResize(newWidth, newHeight);
                },
              ),
            ),
            // Left edge
            Positioned(
              left: 0,
              top: 20,
              bottom: 20,
              child: _ResizeHandle(
                cursor: SystemMouseCursors.resizeLeftRight,
                onDrag: (delta) {
                  final newWidth = (widget.width - delta.dx)
                      .clamp(widget.minWidth, widget.maxWidth);
                  if (newWidth != widget.width) {
                    widget.onMove(Offset(widget.width - newWidth, 0));
                    widget.onResize(newWidth, widget.height);
                  }
                },
              ),
            ),
            // Top edge
            Positioned(
              left: 20,
              right: 20,
              top: 0,
              child: _ResizeHandle(
                cursor: SystemMouseCursors.resizeUpDown,
                onDrag: (delta) {
                  final newHeight = (widget.height - delta.dy)
                      .clamp(widget.minHeight, widget.maxHeight);
                  if (newHeight != widget.height) {
                    widget.onMove(Offset(0, widget.height - newHeight));
                    widget.onResize(widget.width, newHeight);
                  }
                },
              ),
            ),
          ],

          // Mobile resize handle (top edge only - to expand/shrink)
          if (widget.isMobile)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  final newHeight = (widget.height - details.delta.dy)
                      .clamp(widget.minHeight, widget.maxHeight);
                  if (newHeight != widget.height) {
                    widget.onMove(Offset(0, widget.height - newHeight));
                    widget.onResize(widget.width, newHeight);
                  }
                },
                child: Container(
                  height: 20,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6e7681),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Invisible resize handle
class _ResizeHandle extends StatelessWidget {
  final MouseCursor cursor;
  final void Function(Offset delta) onDrag;
  final double size;

  const _ResizeHandle({
    required this.cursor,
    required this.onDrag,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          width: cursor == SystemMouseCursors.resizeUpDown
              ? double.infinity
              : size,
          height: cursor == SystemMouseCursors.resizeLeftRight
              ? double.infinity
              : size,
          color: Colors.transparent,
        ),
      ),
    );
  }
}

class _DefaultDevtoolsButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onPressed;

  const _DefaultDevtoolsButton({
    required this.isOpen,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1a1a2e),
      shape: const CircleBorder(),
      elevation: 6,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: AnimatedRotation(
            turns: isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(
              Icons.bug_report,
              color: Color(0xFF00d9ff),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Position for the devtools toggle button
enum DevtoolsPosition {
  bottomLeft,
  bottomRight,
}
