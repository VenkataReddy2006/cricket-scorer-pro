import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double borderOpacity;
  final double backgroundOpacity;
  final Color? borderColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.blur = 16.0,
    this.borderOpacity = 0.15,
    this.backgroundOpacity = 0.06,
    this.borderColor,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.shadows,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final finalBorderColor = (borderColor ?? Colors.white).withOpacity(borderOpacity);
    final finalBgColor = (backgroundColor ?? Colors.white).withOpacity(backgroundOpacity);

    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: finalBorderColor,
                width: 1.5,
              ),
              gradient: gradient ?? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  finalBgColor,
                  finalBgColor.withOpacity(backgroundOpacity * 0.5),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
