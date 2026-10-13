import 'package:flutter/widgets.dart';

/// A tiny stateful host so controlled widgets can be driven the way an app would.
class Host<T> extends StatefulWidget {
  const Host({super.key, required this.initial, required this.builder});
  final T initial;
  final Widget Function(T value, ValueChanged<T> set) builder;
  @override
  State<Host<T>> createState() => _HostState<T>();
}

class _HostState<T> extends State<Host<T>> {
  late T v = widget.initial;
  @override
  Widget build(BuildContext context) => widget.builder(v, (n) => setState(() => v = n));
}
