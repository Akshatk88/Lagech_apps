import 'package:flutter/material.dart';

/// Owns a [TextEditingController] for exactly as long as the widget below it
/// exists, then disposes it.
///
/// Use it INSIDE a `showDialog` / `showModalBottomSheet` builder instead of making
/// the controller in the calling method and disposing it after `await show...`.
/// That `await` returns the moment the route is popped, while the dialog is still
/// on screen fading out. Disposing the controller then makes its TextField throw
/// "A TextEditingController was used after being disposed", which corrupts the
/// widget tree and ends in the red `_dependents.isEmpty` assertion screen.
class ControllerScope extends StatefulWidget {
  const ControllerScope({super.key, this.text, required this.builder});

  /// Initial text of the controller.
  final String? text;

  final Widget Function(BuildContext context, TextEditingController controller)
      builder;

  @override
  State<ControllerScope> createState() => _ControllerScopeState();
}

class _ControllerScopeState extends State<ControllerScope> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
