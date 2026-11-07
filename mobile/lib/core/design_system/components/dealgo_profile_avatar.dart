import 'package:flutter/material.dart';

import '../icons/dealgo_icons.dart';
import '../tokens/dealgo_tokens.dart';
import 'dealgo_network_image.dart';

/// Circular identity avatar for the signed-in account.
///
/// Falls back to a tinted person icon both when [avatarUrl] is absent and when
/// the stored upload fails to load, so a broken file never leaves an empty
/// circle in headers or checkout.
class DealGoProfileAvatar extends StatelessWidget {
  const DealGoProfileAvatar({
    this.avatarUrl,
    this.size = 40,
    this.semanticLabel,
    super.key,
  });

  final String? avatarUrl;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    final iconSize = size * 0.5;
    final placeholder = SizedBox(
      width: iconSize,
      height: iconSize,
      child: Icon(
        DealGoIcons.user,
        color: DealGoColors.primary,
        size: iconSize,
      ),
    );
    return Semantics(
      image: url != null && url.isNotEmpty,
      label: semanticLabel,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: DealGoColors.subtlePurple,
          shape: BoxShape.circle,
        ),
        child: url == null || url.isEmpty
            ? placeholder
            : DealGoNetworkImage(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: placeholder,
                fallback: placeholder,
              ),
      ),
    );
  }
}
