import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens/dealgo_tokens.dart';

class DealGoIllustration extends StatelessWidget {
  const DealGoIllustration(this.asset, {this.width, this.height, super.key});

  final String asset;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.two_wheeler,
          size: (height ?? width ?? 48) * 0.55,
          color: DealGoColors.primary,
        );
      },
    );
  }
}
