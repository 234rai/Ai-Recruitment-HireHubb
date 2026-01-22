// lib/utils/responsive_helper.dart
// A utility class for responsive UI sizing across different mobile screen sizes

import 'package:flutter/material.dart';

/// ResponsiveHelper provides proportional sizing methods based on screen dimensions.
/// Similar to media queries in web development, this helps prevent pixel overflow
/// issues across different mobile screen sizes.
///
/// Usage:
/// ```dart
/// // Initialize at the top of your build method
/// final responsive = ResponsiveHelper(context);
///
/// // Use responsive values
/// Text('Hello', style: TextStyle(fontSize: responsive.fontSize(16)))
/// Padding(padding: EdgeInsets.all(responsive.padding(16)))
/// Icon(Icons.home, size: responsive.iconSize(24))
/// ```
class ResponsiveHelper {
  final BuildContext context;
  late final double screenWidth;
  late final double screenHeight;
  late final double textScaleFactor;

  // Base design dimensions (iPhone 14 Pro as reference)
  static const double _baseWidth = 393.0;
  static const double _baseHeight = 852.0;

  // Screen size breakpoints
  static const double smallScreenMaxWidth = 360.0;
  static const double mediumScreenMaxWidth = 400.0;
  static const double largeScreenMaxWidth = 500.0;

  ResponsiveHelper(this.context) {
    final mediaQuery = MediaQuery.of(context);
    screenWidth = mediaQuery.size.width;
    screenHeight = mediaQuery.size.height;
    // Use textScaler for Flutter 3.16+ compatibility
    textScaleFactor = mediaQuery.textScaler.scale(1.0).clamp(0.8, 1.3);
  }

  // ============================================================================
  // Screen Size Detection
  // ============================================================================

  /// Returns true if screen width is less than 360dp (small phones)
  bool get isSmallScreen => screenWidth < smallScreenMaxWidth;

  /// Returns true if screen width is between 360dp and 400dp (medium phones)
  bool get isMediumScreen =>
      screenWidth >= smallScreenMaxWidth && screenWidth < mediumScreenMaxWidth;

  /// Returns true if screen width is 400dp or more (large phones/tablets)
  bool get isLargeScreen => screenWidth >= mediumScreenMaxWidth;

  /// Returns true if screen height is less than 700dp (short screens)
  bool get isShortScreen => screenHeight < 700;

  // ============================================================================
  // Proportional Sizing Methods
  // ============================================================================

  /// Returns proportional width based on base design width
  double wp(double percentage) {
    return screenWidth * (percentage / 100);
  }

  /// Returns proportional height based on base design height
  double hp(double percentage) {
    return screenHeight * (percentage / 100);
  }

  /// Returns proportional font size that scales with screen width
  /// Clamps between 0.8x and 1.2x of base size to prevent extreme scaling
  double fontSize(double baseSize) {
    final scaleFactor = (screenWidth / _baseWidth).clamp(0.8, 1.2);
    return (baseSize * scaleFactor * textScaleFactor).clamp(baseSize * 0.7, baseSize * 1.3);
  }

  /// Returns proportional padding/margin that scales with screen width
  double padding(double baseSize) {
    final scaleFactor = (screenWidth / _baseWidth).clamp(0.8, 1.15);
    return baseSize * scaleFactor;
  }

  /// Returns proportional spacing that scales with screen width
  double spacing(double baseSize) {
    return padding(baseSize);
  }

  /// Returns proportional icon size that scales with screen width
  double iconSize(double baseSize) {
    final scaleFactor = (screenWidth / _baseWidth).clamp(0.85, 1.15);
    return baseSize * scaleFactor;
  }

  /// Returns proportional radius for rounded corners
  double radius(double baseSize) {
    final scaleFactor = (screenWidth / _baseWidth).clamp(0.9, 1.1);
    return baseSize * scaleFactor;
  }

  /// Returns proportional height for containers/cards
  double height(double baseSize) {
    final scaleFactor = (screenHeight / _baseHeight).clamp(0.85, 1.15);
    return baseSize * scaleFactor;
  }

  /// Returns proportional width for containers/buttons
  double width(double baseSize) {
    final scaleFactor = (screenWidth / _baseWidth).clamp(0.85, 1.15);
    return baseSize * scaleFactor;
  }

  // ============================================================================
  // Responsive Value Helpers
  // ============================================================================

  /// Returns different values based on screen size
  T valueByScreen<T>({
    required T small,
    required T medium,
    required T large,
  }) {
    if (isSmallScreen) return small;
    if (isMediumScreen) return medium;
    return large;
  }

  /// Returns EdgeInsets with proportional padding
  EdgeInsets paddingAll(double baseSize) {
    return EdgeInsets.all(padding(baseSize));
  }

  /// Returns symmetric EdgeInsets with proportional padding
  EdgeInsets paddingSymmetric({double horizontal = 0, double vertical = 0}) {
    return EdgeInsets.symmetric(
      horizontal: padding(horizontal),
      vertical: padding(vertical),
    );
  }

  /// Returns EdgeInsets with proportional LTRB padding
  EdgeInsets paddingOnly({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(
      left: padding(left),
      top: padding(top),
      right: padding(right),
      bottom: padding(bottom),
    );
  }

  // ============================================================================
  // Common UI Sizes
  // ============================================================================

  /// Standard small text size (12-14sp)
  double get smallText => fontSize(12);

  /// Standard body text size (14-16sp)
  double get bodyText => fontSize(14);

  /// Standard subtitle text size (16-18sp)
  double get subtitleText => fontSize(16);

  /// Standard title text size (18-22sp)
  double get titleText => fontSize(20);

  /// Standard heading text size (24-28sp)
  double get headingText => fontSize(24);

  /// Standard large heading text size (28-32sp)
  double get largeHeadingText => fontSize(28);

  /// Standard small icon size
  double get smallIcon => iconSize(16);

  /// Standard medium icon size
  double get mediumIcon => iconSize(24);

  /// Standard large icon size
  double get largeIcon => iconSize(32);

  /// Standard horizontal padding
  double get horizontalPadding => padding(16);

  /// Standard vertical padding
  double get verticalPadding => padding(12);

  /// Standard card padding
  double get cardPadding => padding(16);

  /// Standard button height
  double get buttonHeight => height(48);

  /// Standard input field height
  double get inputHeight => height(52);

  /// Standard card border radius
  double get cardRadius => radius(12);

  /// Standard button border radius
  double get buttonRadius => radius(8);

  // ============================================================================
  // Safe Area Helpers
  // ============================================================================

  /// Returns the top safe area padding (for notches)
  double get safeAreaTop => MediaQuery.of(context).padding.top;

  /// Returns the bottom safe area padding (for home indicator)
  double get safeAreaBottom => MediaQuery.of(context).padding.bottom;

  /// Returns the keyboard height when visible
  double get keyboardHeight => MediaQuery.of(context).viewInsets.bottom;

  /// Returns true if keyboard is visible
  bool get isKeyboardVisible => keyboardHeight > 0;
}

/// Extension on BuildContext for easy access to ResponsiveHelper
extension ResponsiveExtension on BuildContext {
  ResponsiveHelper get responsive => ResponsiveHelper(this);
}
