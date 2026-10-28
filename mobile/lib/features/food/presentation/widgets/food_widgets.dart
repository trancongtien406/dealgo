import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'food_category_tile.dart';
import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/food_money.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';

String? currentAccessToken(BuildContext context) {
  final auth = context.read<AuthCubit>().state;
  if (auth is! AuthSignedIn) {
    return null;
  }
  return auth.tokens.accessToken;
}

class FoodPanel extends StatelessWidget {
  const FoodPanel({
    required this.child,
    this.color = DealGoColors.card,
    this.padding = const EdgeInsets.all(DealGoSpacing.s16),
    this.elevated = false,
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  /// Soft purple shadow for menu/store cards (C022/C025).
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DealGoRadius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(
          color: color == DealGoColors.card
              ? DealGoColors.border
              : Colors.transparent,
        ),
        boxShadow: elevated ? DealGoShadows.card : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Wide hero / cover image with solid placeholder (no gradients).
class FoodCoverImage extends StatelessWidget {
  const FoodCoverImage({
    this.imageUrl,
    this.height = 180,
    this.aspectRatio,
    this.badge,
    this.placeholderAsset = foodPlaceholderImage,
    super.key,
  });

  final String? imageUrl;
  final double height;

  /// Width / height of the frame. When set it wins over [height], so the
  /// photo keeps the same shape on every screen width.
  final double? aspectRatio;
  final Widget? badge;
  final String placeholderAsset;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(imageUrl);
    final radius = BorderRadius.circular(DealGoRadius.card);
    final double? h = aspectRatio == null ? height : null;
    final placeholder = Image.asset(
      placeholderAsset,
      height: h ?? double.infinity,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => ColoredBox(
        color: DealGoColors.amberSurface,
        child: SizedBox(height: h, width: double.infinity),
      ),
    );
    final image = resolved == null || resolved.isEmpty
        ? placeholder
        : DealGoNetworkImage(
            resolved,
            height: h ?? double.infinity,
            width: double.infinity,
            fit: BoxFit.cover,
            fallback: placeholder,
          );
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          if (aspectRatio != null)
            AspectRatio(aspectRatio: aspectRatio!, child: image)
          else
            SizedBox(height: height, width: double.infinity, child: image),
          if (badge != null)
            Positioned(
              right: DealGoSpacing.s12,
              bottom: DealGoSpacing.s12,
              child: badge!,
            ),
        ],
      ),
    );
  }
}

/// Outlined or filled meta chip used on store headings (prep / distance).
class FoodInfoChip extends StatelessWidget {
  const FoodInfoChip({
    required this.label,
    this.icon,
    this.filled = false,
    this.iconColor,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool filled;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final foreground = filled
        ? DealGoColors.primary
        : DealGoColors.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? DealGoColors.subtlePurple : DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.pill),
        border: filled ? null : Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: iconColor ?? foreground),
              const SizedBox(width: DealGoSpacing.s4),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class FoodMoneyRow extends StatelessWidget {
  const FoodMoneyRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
    super.key,
  });

  final String label;
  final String amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = emphasize
        ? textTheme.titleMedium?.copyWith(
            color: DealGoColors.primary,
            fontWeight: FontWeight.w800,
          )
        : textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: emphasize ? textTheme.titleMedium : textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: DealGoSpacing.s8),
          Expanded(
            flex: 2,
            child: Text(amount, style: valueStyle, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class FoodNote extends StatelessWidget {
  const FoodNote({required this.message, required this.tone, super.key});

  final String message;
  final FoodNoteTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      FoodNoteTone.green => (
        DealGoColors.greenSurface,
        DealGoColors.brandGreen,
      ),
      FoodNoteTone.amber => (DealGoColors.warningSurface, DealGoColors.warning),
      FoodNoteTone.danger => (DealGoColors.dangerSurface, DealGoColors.danger),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

enum FoodNoteTone { green, amber, danger }

enum FoodChipTone { neutral, green, warning, purple, danger }

class FoodStatusChip extends StatelessWidget {
  const FoodStatusChip({required this.label, required this.tone, super.key});

  final String label;
  final FoodChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      FoodChipTone.neutral => (DealGoColors.canvas, DealGoColors.textSecondary),
      FoodChipTone.green => (
        DealGoColors.greenSurface,
        DealGoColors.brandGreen,
      ),
      FoodChipTone.warning => (DealGoColors.amberSurface, DealGoColors.amber),
      FoodChipTone.purple => (DealGoColors.subtlePurple, DealGoColors.primary),
      FoodChipTone.danger => (DealGoColors.dangerSurface, DealGoColors.danger),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s8,
          vertical: DealGoSpacing.s4,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Hero tag shared by a menu row's photo and the item options cover.
String foodItemHeroTag(String itemId) => 'food-item-photo-$itemId';

class FoodThumb extends StatelessWidget {
  const FoodThumb({
    this.size = 56,
    this.imageUrl,
    this.placeholderAsset = foodPlaceholderImage,
    super.key,
  });

  final double size;
  final String? imageUrl;

  /// Bundled photo while the dish has no picture (e.g. its category photo).
  final String placeholderAsset;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(imageUrl);
    final radius = BorderRadius.circular(DealGoRadius.input);
    final placeholder = ClipRRect(
      borderRadius: radius,
      child: Image.asset(
        placeholderAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => ColoredBox(
          color: DealGoColors.amberSurface,
          child: SizedBox(width: size, height: size),
        ),
      ),
    );
    if (resolved == null || resolved.isEmpty) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: radius,
      child: DealGoNetworkImage(
        resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallback: placeholder,
      ),
    );
  }
}

class FoodLineSummary extends StatelessWidget {
  const FoodLineSummary({
    required this.name,
    required this.quantity,
    required this.unitPriceVnd,
    required this.lineTotalVnd,
    this.options = '',
    this.imageUrl,
    super.key,
  });

  final String name;
  final int quantity;
  final int unitPriceVnd;
  final int lineTotalVnd;

  /// Chosen options from the placed order (DEC-PROD-033); empty = none.
  final String options;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FoodThumb(size: 44, imageUrl: imageUrl),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DealGoColors.text,
                  ),
                ),
                if (options.isNotEmpty)
                  Text(
                    options,
                    style: textTheme.bodySmall?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                  ),
                Text(
                  AppLocalizations.of(context)
                      .foodLineQtyPrice(quantity, formatVnd(unitPriceVnd)),
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: DealGoSpacing.s8),
          Text(
            formatVnd(lineTotalVnd),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class FoodStateIcon extends StatelessWidget {
  const FoodStateIcon({
    required this.icon,
    required this.background,
    required this.foreground,
    super.key,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Icon(icon, color: foreground, size: 28),
      ),
    );
  }
}
