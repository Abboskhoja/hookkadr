import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import 'contextual_toolbar.dart';

/// Layout only: project mutations remain in EditorScreen/PlanOps.
/// Each pane is constrained so additional tracks never consume the preview.
class EditorWorkspace extends StatefulWidget {
  const EditorWorkspace({
    super.key,
    required this.header,
    required this.preview,
    required this.transport,
    required this.timeline,
    required this.inspector,
    required this.shotTools,
    required this.assistant,
    required this.tools,
    this.hasSelection = false,
    this.onClearSelection,
  });

  final bool hasSelection;
  final VoidCallback? onClearSelection;

  final Widget header,
      preview,
      transport,
      timeline,
      inspector,
      shotTools,
      assistant,
      tools;

  @override
  State<EditorWorkspace> createState() => _EditorWorkspaceState();
}

enum _TimelineSize { compact, standard, expanded, focus }

class _EditorWorkspaceState extends State<EditorWorkspace> {
  _TimelineSize _size = _TimelineSize.standard;
  bool _fullscreen = false;

  Widget _controls() => Row(
    children: [
      if (!_fullscreen)
        Expanded(
          child: PopupMenuButton<_TimelineSize>(
            tooltip: 'Timeline maydoni',
            initialValue: _size,
            onSelected: (value) => setState(() => _size = value),
            itemBuilder: (_) => [
              for (final entry in const {
                _TimelineSize.compact: 'Ixcham',
                _TimelineSize.standard: 'Standart',
                _TimelineSize.expanded: 'Kengaytirilgan',
                _TimelineSize.focus: 'Timeline fokus',
              }.entries)
                PopupMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.layers,
                    size: 18,
                    color: context.palette.accent,
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text('Timeline', overflow: TextOverflow.ellipsis),
                  ),
                  const Icon(LucideIcons.chevronDown, size: 16),
                ],
              ),
            ),
          ),
        )
      else
        const Spacer(),
      IconButton(
        tooltip: _fullscreen ? 'Montajga qaytish' : 'To‘liq preview',
        onPressed: () => setState(() => _fullscreen = !_fullscreen),
        icon: Icon(_fullscreen ? LucideIcons.minimize : LucideIcons.maximize),
      ),
    ],
  );

  Widget _editing() => SingleChildScrollView(
    key: const PageStorageKey('editor-inspector-scroll'),
    child: Column(children: [widget.timeline, widget.inspector]),
  );

  Widget _toolbar() => ContextualToolbar(
    selected: widget.hasSelection,
    onDismiss: widget.onClearSelection ?? () {},
    generalTools: widget.tools,
    clipTools: widget.shotTools,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth > box.maxHeight && box.maxWidth >= 700;
      final panelFraction = switch (_size) {
        _TimelineSize.compact => 0.20,
        _TimelineSize.standard => 0.32,
        _TimelineSize.expanded => 0.45,
        _TimelineSize.focus => 0.56,
      };
      if (_fullscreen) {
        return Column(
          children: [
            widget.header,
            _controls(),
            Expanded(child: widget.preview),
            widget.transport,
          ],
        );
      }
      if (wide) {
        return Column(
          children: [
            widget.header,
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: _size == _TimelineSize.focus ? 1 : 2,
                    child: Column(
                      children: [
                        Expanded(child: widget.preview),
                        widget.transport,
                      ],
                    ),
                  ),
                  Expanded(
                    flex: _size == _TimelineSize.compact ? 1 : 2,
                    child: Column(
                      children: [
                        _controls(),
                        Expanded(child: _editing()),
                        widget.assistant,
                        _toolbar(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }
      // Keep the timeline reachable even with large accessibility text sizes.
      final panelHeight =
          (box.maxHeight * panelFraction * (box.maxHeight < 650 ? 0.65 : 1))
              .clamp(100.0, box.maxHeight * 0.48);
      return Column(
        children: [
          widget.header,
          Expanded(child: widget.preview),
          widget.transport,
          _controls(),
          SizedBox(height: panelHeight, child: _editing()),
          widget.assistant,
          _toolbar(),
        ],
      );
    },
  );
}
