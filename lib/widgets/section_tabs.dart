import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';

/// A top tab bar for one bottom-navigation section. Every page stays alive
/// while hidden, so a generated plan or a half-filled form survives a swipe.
class SectionTabs extends StatefulWidget {
  const SectionTabs({
    super.key,
    required this.labels,
    required this.children,
    this.onChanged,
  }) : assert(labels.length == children.length);

  final List<String> labels;
  final List<Widget> children;

  /// Called with the new index whenever another tab is shown.
  final ValueChanged<int>? onChanged;

  @override
  State<SectionTabs> createState() => SectionTabsState();
}

class SectionTabsState extends State<SectionTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _controller =
      TabController(length: widget.children.length, vsync: this)
        ..addListener(_notify);
  int _lastIndex = 0;

  int get index => _controller.index;

  void show(int index) => _controller.animateTo(index);

  void _notify() {
    if (_controller.indexIsChanging || _controller.index == _lastIndex) return;
    _lastIndex = _controller.index;
    widget.onChanged?.call(_lastIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: CyberColors.background,
          child: TabBar(
            controller: _controller,
            labelColor: CyberColors.cyan,
            unselectedLabelColor: CyberColors.muted,
            indicatorColor: CyberColors.cyan,
            dividerColor: CyberColors.border,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: [for (final label in widget.labels) Tab(text: label)],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              for (final child in widget.children) _KeepAlive(child: child),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
