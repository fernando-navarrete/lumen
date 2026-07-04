import 'package:flutter/material.dart';

/// Text that auto-scrolls back and forth (bounce, not loop) when it
/// overflows the available width, with a fade at both edges.
///
/// Must be given a bounded width by its parent (e.g. wrap in a
/// `SizedBox`, `Expanded`, or a `Row` where this is the flexible child).
class BounceMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pause;
  final Duration scrollDuration;
  final Curve curve;

  const BounceMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pause = const Duration(seconds: 1),
    this.scrollDuration = const Duration(seconds: 3),
    this.curve = Curves.easeInOut,
  });

  @override
  State<BounceMarqueeText> createState() => _BounceMarqueeTextState();
}

class _BounceMarqueeTextState extends State<BounceMarqueeText> {
  final ScrollController _scrollController = ScrollController();
  bool _started = false;
  bool _running = false;

  void _maybeStart(double maxWidth) {
    if (_started) return;
    _started = true;

    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    if (painter.width > maxWidth) {
      final maxScroll = painter.width - maxWidth + 4; // small buffer
      _running = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loop(maxScroll));
    }
  }

  Future<void> _loop(double maxScroll) async {
    while (mounted && _running) {
      await Future.delayed(widget.pause);
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.animateTo(
        maxScroll,
        duration: widget.scrollDuration,
        curve: widget.curve,
      );

      await Future.delayed(widget.pause);
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.animateTo(
        0,
        duration: widget.scrollDuration,
        curve: widget.curve,
      );
    }
  }

  @override
  void didUpdateWidget(covariant BounceMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // Text changed: reset and re-measure on next build.
      _running = false;
      _started = false;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _running = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _maybeStart(constraints.maxWidth);

        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.08, 0.92, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              widget.text,
              maxLines: 1,
              softWrap: false,
              style: widget.style,
            ),
          ),
        );
      },
    );
  }
}

/// Measures [text] against the available width and renders a plain,
/// ellipsized [Text] if it fits, or a [BounceMarqueeText] if it doesn't.
///
/// This avoids paying for the scroll/fade wrapper at all when it isn't
/// needed, so short text never gets an unwanted edge fade.
class AutoMarqueeText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Duration pause;
  final Duration scrollDuration;
  final Curve curve;

  const AutoMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pause = const Duration(seconds: 1),
    this.scrollDuration = const Duration(seconds: 3),
    this.curve = Curves.easeInOut,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final overflows = painter.width > constraints.maxWidth;

        if (!overflows) {
          return Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        }

        return BounceMarqueeText(
          text: text,
          style: style,
          pause: pause,
          scrollDuration: scrollDuration,
          curve: curve,
        );
      },
    );
  }
}
