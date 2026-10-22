import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../services/app_session.dart';

/// Title bar height (shared so other widgets can match it)
const double kTitleBarHeight = 44;

/// Custom window title bar (replaces the default OS title bar).
/// Drag to move, double-click to maximize/restore.
/// Shows: app name > current page, and (after login) date + user name/role.
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

  // e.g. 22 Oct 2026
  String _today() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final n = DateTime.now();
    return '${n.day} ${months[n.month - 1]} ${n.year}';
  }

  // Date + welcome message + logout button (hidden on the login screen)
  Widget _buildUserInfo(ColorScheme cs) {
    return ValueListenableBuilder<String>(
      valueListenable: AppSession.userName,
      builder: (context, name, _) {
        if (name.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            children: [
              Icon(Icons.calendar_today,
                  size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                _today(),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 16),
              Text(
                'Welcome, $name',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              // Logout button
              TextButton.icon(
                onPressed: () => AppSession.onLogout?.call(),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Logout'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  backgroundColor: Colors.red.withValues(alpha: 0.08),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      child: Container(
        height: kTitleBarHeight,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            // Draggable area (logo + title + page name)
            Expanded(
              child: DragToMoveArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _toggleMaximize,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.point_of_sale, size: 22, color: cs.primary),
                      const SizedBox(width: 10),
                      Text(
                        'EasyBill POS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      // "Admin Dashboard" / "Cashier Dashboard" badge (empty on login screen)
                      ValueListenableBuilder<String>(
                        valueListenable: AppSession.userRole,
                        builder: (context, role, _) {
                          if (role.isEmpty) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(left: 14),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$role Dashboard',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // User info (date, name, role)
            _buildUserInfo(cs),

            // Window buttons
            _TitleButton(
              icon: Icons.remove,
              onTap: () => windowManager.minimize(),
            ),
            _TitleButton(
              icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
              iconSize: _isMaximized ? 16 : 18,
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
    this.iconSize = 18,
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
          width: 58,
          height: kTitleBarHeight,
          color: bg,
          alignment: Alignment.center,
          child: Icon(widget.icon, size: widget.iconSize, color: fg),
        ),
      ),
    );
  }
}