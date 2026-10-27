import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design_system/icons/dealgo_icons.dart';
import '../design_system/tokens/dealgo_tokens.dart';
import 'map_port.dart';
import 'map_style.dart';
import 'tile_map_port.dart';

/// Round floating map control (back, recenter, layers): one look everywhere.
class MapRoundButton extends StatelessWidget {
  const MapRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = DealGoColors.text,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  final bool selected;

  static const size = 44.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? DealGoColors.subtlePurple
          : DealGoColors.card.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: const Color(0x33171B2C),
      child: SizedBox.square(
        dimension: size,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

/// Back control drawn over a full-bleed map; [onPressed] defaults to
/// `maybePop`, so it behaves like the system back.
class MapBackButton extends StatelessWidget {
  const MapBackButton({this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MapRoundButton(
      icon: DealGoIcons.arrowLeft,
      tooltip: AppLocalizations.of(context).actionBack,
      onPressed: onPressed ?? () => Navigator.maybePop(context),
    );
  }
}

/// True when the live map can switch looks (Mapbox style tiles).
bool mapStylesAvailable(MapPort port) =>
    port is TileMapPort && mapStylesSupported(port.urlTemplate);

/// Layers button that slides out the standard / satellite / dark choice to its
/// left. Hidden when the tile source has a single look.
class MapStyleSwitcher extends StatefulWidget {
  const MapStyleSwitcher({
    required this.available,
    this.initiallyOpen = false,
    super.key,
  });

  final bool available;
  final bool initiallyOpen;

  @override
  State<MapStyleSwitcher> createState() => _MapStyleSwitcherState();
}

class _MapStyleSwitcherState extends State<MapStyleSwitcher> {
  late var _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    if (!widget.available) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<DealGoMapStyle>(
      valueListenable: mapStyle,
      builder: (context, current, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.centerRight,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.only(right: DealGoSpacing.s8),
                      child: _StylePanel(
                        current: current,
                        onSelect: (style) {
                          mapStyle.select(style);
                          setState(() => _open = false);
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            MapRoundButton(
              key: const Key('map-style-button'),
              icon: DealGoIcons.layers,
              tooltip: l10n.mapStyleTitle,
              selected: _open,
              color: _open ? DealGoColors.primary : DealGoColors.text,
              onPressed: () => setState(() => _open = !_open),
            ),
          ],
        );
      },
    );
  }
}

class _StylePanel extends StatelessWidget {
  const _StylePanel({required this.current, required this.onSelect});

  final DealGoMapStyle current;
  final ValueChanged<DealGoMapStyle> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      key: const Key('map-style-panel'),
      color: DealGoColors.card,
      elevation: 3,
      shadowColor: const Color(0x33171B2C),
      borderRadius: BorderRadius.circular(DealGoRadius.button),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final style in DealGoMapStyle.values)
              _StyleChip(
                style: style,
                label: switch (style) {
                  DealGoMapStyle.standard => l10n.mapStyleStandard,
                  DealGoMapStyle.satellite => l10n.mapStyleSatellite,
                  DealGoMapStyle.dark => l10n.mapStyleDark,
                },
                selected: style == current,
                onTap: () => onSelect(style),
              ),
          ],
        ),
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.style,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final DealGoMapStyle style;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  // Painted swatches: no tile request just to preview a look.
  static const _swatch = <DealGoMapStyle, (Color, Color, IconData)>{
    DealGoMapStyle.standard: (
      Color(0xFFE7EEF5),
      Color(0xFF4B5563),
      DealGoIcons.map,
    ),
    DealGoMapStyle.satellite: (
      Color(0xFF3F5A3A),
      Color(0xFFFFFFFF),
      DealGoIcons.earth,
    ),
    DealGoMapStyle.dark: (
      Color(0xFF1F2430),
      Color(0xFFE5E7EB),
      DealGoIcons.moon,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = _swatch[style]!;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        key: Key('map-style-${style.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s4,
            vertical: 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 32,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? DealGoColors.primary
                        : DealGoColors.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Icon(icon, size: 16, color: fg),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? DealGoColors.primary
                      : DealGoColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Right-hand map controls in one fixed order on every map: style (layers) on
/// top, my-location below.
class MapSideControls extends StatelessWidget {
  const MapSideControls({
    super.key,
    required this.stylesAvailable,
    required this.onLocate,
    this.locateKey = const Key('map-locate'),
  });

  final bool stylesAvailable;

  /// Null while a fix is being taken (button disabled).
  final VoidCallback? onLocate;
  final Key locateKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (stylesAvailable) ...[
          MapStyleSwitcher(available: stylesAvailable),
          const SizedBox(height: DealGoSpacing.s8),
        ],
        MapRoundButton(
          key: locateKey,
          icon: DealGoIcons.myLocation,
          tooltip: AppLocalizations.of(context).mapRecenter,
          color: DealGoColors.primary,
          onPressed: onLocate,
        ),
      ],
    );
  }
}
