import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';
import 'palette.dart';

/// The fixed colors. Trip colors come from [TripPalette].
abstract final class C {
  static const ivory = Color(0xFFF4F1EA);
  static const navy = Color(0xFF16213A);
  static const sub = Color(0xFF4E4A42);
  static const line = Color(0x2616213A);
  static const tape = Color(0xF0F6EFDE);
  static const photoDark = Color(0xFF2E211A);
}

/// Titles, big numbers and item names.
TextStyle serif(double size,
        {FontWeight weight = FontWeight.w500,
        Color? color,
        double height = 1.25}) =>
    GoogleFonts.notoSerifKr(
      fontSize: size,
      fontWeight: weight,
      color: color ?? C.navy,
      height: height,
      letterSpacing: size >= 28 ? -1 : -0.3,
    );

/// Times, dates and amounts in small print.
TextStyle mono(double size, {Color? color}) =>
    GoogleFonts.ibmPlexMono(fontSize: size, color: color ?? C.sub);

TextStyle body(double size,
        {FontWeight weight = FontWeight.w400,
        Color? color,
        double height = 1.45}) =>
    GoogleFonts.ibmPlexSansKr(
        fontSize: size,
        fontWeight: weight,
        color: color ?? C.navy,
        height: height);

Color textOn(Color background) => isDark(background) ? C.ivory : C.navy;

extension TripColors on Trip {
  Color get light1 => Color(palette.light1);
  Color get light2 => Color(palette.light2);
  Color get dark1 => Color(palette.dark1);
  Color get dark2 => Color(palette.dark2);
}

/// Header row: a back arrow (or nothing) on the left, actions on the right.
class TopBar extends StatelessWidget {
  final Widget? leading;
  final List<Widget> actions;
  const TopBar({super.key, this.leading, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          leading ?? const SizedBox(width: 12),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

class BackArrow extends StatelessWidget {
  final VoidCallback? onTap;
  const BackArrow({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '뒤로',
      onPressed: onTap ?? () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.arrow_back, color: C.navy, weight: 300),
    );
  }
}

/// Full-width band under the header: where and when we are.
class ContextBand extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final Color color;
  final VoidCallback? onTap;
  const ContextBand(
      {super.key,
      required this.label,
      required this.color,
      this.trailing,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = textOn(color);
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                    child: Text(label,
                        style: body(13, weight: FontWeight.w500, color: fg))),
                if (trailing != null)
                  DefaultTextStyle.merge(
                      style: TextStyle(color: fg), child: trailing!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A big full-width action at the bottom of a screen.
class ActionBand extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final bool arrow;
  final bool centered;
  const ActionBand({
    super.key,
    required this.label,
    required this.onTap,
    required this.color,
    this.icon,
    this.arrow = true,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textOn(color);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: onTap == null ? color.withValues(alpha: 0.5) : color,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 72 + bottom,
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottom),
          child: Row(
            mainAxisAlignment: centered
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: 22),
                const SizedBox(width: 10)
              ],
              Text(label, style: body(15, weight: FontWeight.w500, color: fg)),
              if (arrow && !centered) ...[
                const Spacer(),
                Icon(Icons.arrow_forward, color: fg, size: 20)
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A plain full-bleed row with a thin line under it.
class BandRow extends StatelessWidget {
  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final double minHeight;
  final EdgeInsets padding;
  const BandRow({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.minHeight = 56,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: padding,
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: C.line))),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }
}

/// A row that leads somewhere, with an arrow at the end.
class LinkBand extends StatelessWidget {
  final String label;
  final String? sub;
  final Color color;
  final VoidCallback onTap;
  const LinkBand(
      {super.key,
      required this.label,
      required this.color,
      required this.onTap,
      this.sub});

  @override
  Widget build(BuildContext context) {
    final fg = textOn(color);
    return BandRow(
      color: color,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: body(14, color: fg)),
                if (sub != null)
                  Text(sub!,
                      style: body(12, color: fg.withValues(alpha: 0.75))),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, size: 18, color: fg),
        ],
      ),
    );
  }
}

class SerifTitle extends StatelessWidget {
  final String text;
  final double size;
  const SerifTitle(this.text, {super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Text(text, style: serif(size)),
    );
  }
}

/// A square speaker cell attached to the right of a row.
class ListenCell extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;
  const ListenCell({super.key, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      decoration:
          const BoxDecoration(border: Border(left: BorderSide(color: C.line))),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: const Icon(Icons.volume_up_outlined, color: C.navy, size: 20),
      ),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: body(14, color: C.ivory)),
    backgroundColor: C.navy,
    behavior: SnackBarBehavior.floating,
    shape: const RoundedRectangleBorder(),
  ));
}

String hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
String md(DateTime t) => '${t.month}.${t.day}';

/// The CamTrip wordmark: four bands in the trip's colors with "Cam" on the
/// light half and "Trip" on the dark half. It changes with every trip.
class LogoBand extends StatelessWidget {
  final TripPalette palette;
  final double height;
  const LogoBand(
      {super.key, this.palette = TripPalette.fallback, this.height = 30});

  @override
  Widget build(BuildContext context) {
    final size = height * 0.52;
    return Semantics(
      label: 'CamTrip',
      child: SizedBox(
        width: height * 4.6,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in [
                    palette.light1,
                    palette.light2,
                    palette.dark1,
                    palette.dark2
                  ])
                    Expanded(child: ColoredBox(color: Color(c))),
                ],
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                      child: Center(
                          child: Text('Cam',
                              style: serif(size,
                                  weight: FontWeight.w600, height: 1)))),
                  Expanded(
                    child: Center(
                      child: Text('Trip',
                          style: serif(size,
                              weight: FontWeight.w600,
                              color: C.ivory,
                              height: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
