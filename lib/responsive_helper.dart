import 'package:flutter/material.dart';

class ResponsiveHelper {
  // Extra Small - <576px
  static bool isExtraSmall(BuildContext context) {
    return MediaQuery.of(context).size.width < 576;
  }

  // Small - 576px—767px
  static bool isSmall(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return width >= 576 && width <= 767;
  }

  // Medium - 768px—991px
  static bool isMedium(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return width >= 768 && width <= 991;
  }

  // Large - 992px—1199px
  static bool isLarge(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return width >= 992 && width <= 1199;
  }

  // Extra Large - ≥1200px
  static bool isExtraLarge(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  // Helper method for getting a responsive value
  static T getValue<T>(
    BuildContext context, {
    required T defaultVal,
    T? extraSmall,
    T? small,
    T? medium,
    T? large,
    T? extraLarge,
  }) {
    double width = MediaQuery.of(context).size.width;

    if (width >= 1200 && extraLarge != null) return extraLarge;
    if (width >= 992 && large != null) return large;
    if (width >= 768 && medium != null) return medium;
    if (width >= 576 && small != null) return small;
    if (width < 576 && extraSmall != null) return extraSmall;

    return defaultVal;
  }
}
