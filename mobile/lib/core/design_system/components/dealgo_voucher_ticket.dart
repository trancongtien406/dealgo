import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../icons/dealgo_icons.dart';
import '../tokens/dealgo_tokens.dart';

/// Width of the coloured stub that carries the discount headline.
const double kDealGoTicketStubWidth = 92;

/// Radius of the half-circle notches cut into the top and bottom edges
/// where the stub meets the body.
const double _notchRadius = 8;

/// Voucher ticket (ShopeeFood / GrabFood style): a coloured stub with the
/// headline ("Giảm 20%"), notches and a dashed tear line, then the offer
/// name and every condition in full — nothing is ellipsized. One look for
/// store offers, the checkout voucher list and the merchant's own offers.
class DealGoVoucherTicket extends StatelessWidget {
  const DealGoVoucherTicket({
    required this.headline,
    required this.title,
    this.caption,
    this.conditions = const [],
    this.footer,
    this.action,
    this.accent = DealGoColors.danger,
    this.dimmed = false,
    this.highlighted = false,
    this.onTap,
    this.tapKey,
    super.key,
  });

  /// Discount, e.g. "Giảm 20%" — wraps inside the stub, never clipped.
  final String headline;

  /// Small line under the headline (the code), only when there is one.
  final String? caption;

  /// Offer name.
  final String title;

  /// Full conditions (minimum order, cap, expiry, uses left), one per line.
  final List<String> conditions;

  /// Extra content under the conditions (saving, shortfall, status, usage).
  final Widget? footer;

  /// Trailing action, usually [DealGoTicketButton].
  final Widget? action;

  final Color accent;

  /// Not usable right now (minimum not met, ended): faded.
  final bool dimmed;

  /// Picked / best choice: accent outline.
  final bool highlighted;

  final VoidCallback? onTap;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final outline = highlighted ? accent : DealGoColors.border;
    final body = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: kDealGoTicketStubWidth,
            color: accent,
            padding: const EdgeInsets.symmetric(
              horizontal: DealGoSpacing.s8,
              vertical: DealGoSpacing.s12,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: DealGoSpacing.s4),
                  // Codes stay on one line and shrink to fit, never cut.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      caption!,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          CustomPaint(
            size: const Size(1, 0),
            painter: _DashedLinePainter(color: accent.withValues(alpha: 0.55)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoSpacing.s12,
                DealGoSpacing.s12,
                DealGoSpacing.s12,
                DealGoSpacing.s12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  for (final line in conditions) ...[
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: textTheme.labelSmall?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                    ),
                  ],
                  if (footer != null) ...[
                    const SizedBox(height: DealGoSpacing.s6),
                    footer!,
                  ],
                  if (action != null) ...[
                    const Spacer(),
                    const SizedBox(height: DealGoSpacing.s8),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: DealGoTicketBorder(side: BorderSide.none),
          shadows: DealGoShadows.card,
        ),
        child: Material(
          color: DealGoColors.card,
          shape: DealGoTicketBorder(
            side: BorderSide(color: outline, width: highlighted ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(key: tapKey, onTap: onTap, child: body),
        ),
      ),
    );
  }
}

/// Pill action on a ticket: filled "Dùng", or the quiet "Đã dùng" state.
class DealGoTicketButton extends StatelessWidget {
  const DealGoTicketButton({
    required this.label,
    required this.accent,
    this.onPressed,
    this.done = false,
    super.key,
  });

  final String label;
  final Color accent;
  final VoidCallback? onPressed;

  /// Already applied: outlined with a check, not tappable.
  final bool done;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge
        ?.copyWith(fontWeight: FontWeight.w800);
    if (done) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(DealGoRadius.pill),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s12,
            vertical: DealGoSpacing.s6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(DealGoIcons.success, size: 16, color: accent),
              const SizedBox(width: DealGoSpacing.s4),
              Text(label, style: style?.copyWith(color: accent)),
            ],
          ),
        ),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 36),
        padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s16),
        shape: const StadiumBorder(),
        textStyle: style,
      ),
      child: Text(label),
    );
  }
}

/// Rounded rectangle with half-circle notches on the top and bottom edges
/// at [notchX] (the stub / body seam).
class DealGoTicketBorder extends OutlinedBorder {
  const DealGoTicketBorder({
    super.side,
    this.radius = 14,
    this.notchX = kDealGoTicketStubWidth,
  });

  final double radius;
  final double notchX;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect rect) {
    final card = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final x = rect.left + notchX;
    final notches = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(x, rect.top), radius: _notchRadius),
      )
      ..addOval(
        Rect.fromCircle(center: Offset(x, rect.bottom), radius: _notchRadius),
      );
    return Path.combine(PathOperation.difference, card, notches);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => DealGoTicketBorder(
    side: side.scale(t),
    radius: radius * t,
    notchX: notchX * t,
  );

  @override
  DealGoTicketBorder copyWith({BorderSide? side}) => DealGoTicketBorder(
    side: side ?? this.side,
    radius: radius,
    notchX: notchX,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is DealGoTicketBorder) {
      return DealGoTicketBorder(
        side: BorderSide.lerp(a.side, side, t),
        radius: lerpDouble(a.radius, radius, t)!,
        notchX: lerpDouble(a.notchX, notchX, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  bool operator ==(Object other) =>
      other is DealGoTicketBorder &&
      other.side == side &&
      other.radius == radius &&
      other.notchX == notchX;

  @override
  int get hashCode => Object.hash(side, radius, notchX);
}

/// Vertical dashed tear line between the stub and the body; leaves room
/// for the notches at both ends.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    var y = _notchRadius + 2;
    while (y < size.height - _notchRadius - 2) {
      final end = (y + dash).clamp(0.0, size.height - _notchRadius - 2);
      canvas.drawLine(Offset(0.5, y), Offset(0.5, end), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
