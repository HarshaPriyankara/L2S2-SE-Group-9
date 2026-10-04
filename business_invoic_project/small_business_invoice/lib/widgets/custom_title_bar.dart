import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Custom window title bar (replaces the default OS title bar).
/// Drag to move, double-click to maximize/restore.
class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncState() async {
    final max = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = max);
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            // Draggable area (logo + title)
            Expanded(
              child: DragToMoveArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _toggleMaximize,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(Icons.point_of_sale, size: 16, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'EasyBill POS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Window buttons
            _TitleButton(
              icon: Icons.remove,
              onTap: () => windowManager.minimize(),
            ),
            _TitleButton(
              icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
              iconSize: _isMaximized ? 14 : 16,
              onTap: _toggleMaximize,
            ),
            _TitleButton(
              icon: Icons.close,
              isClose: true,
              onTap: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;
  final double iconSize;

  const _TitleButton({
    required this.icon,
    required this.onTap,
    this.isClose = false,
    this.iconSize = 16,
  });

  @override
  State<_TitleButton> createState() => _TitleButtonState();
}

class _TitleButtonState extends State<_TitleButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color bg = _hover
        ? (widget.isClose ? Colors.red : cs.surfaceContainerHighest)
        : Colors.transparent;
    final Color fg =
        (_hover && widget.isClose) ? Colors.white : cs.onSurfaceVariant;

    // No Tooltip here: the title bar sits above the Navigator's Overlay.
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 32,
          color: bg,
          alignment: Alignment.center,
          child: Icon(widget.icon, size: widget.iconSize, color: fg),
        ),
      ),
    );
  }
}