import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

const headerSecondary = Color(0xffe0efdf);
const screenGutter = 20.0;
const maxContentWidth = 720.0;
const controlRadius = BorderRadius.all(Radius.circular(8));
const cardRadius = BorderRadius.all(Radius.circular(12));
const sheetRadius = BorderRadius.vertical(top: Radius.circular(24));

TextStyle designType(double size, double lineHeight, FontWeight weight) =>
    TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      letterSpacing: 0,
    );

Color headerColor(BuildContext context) =>
    Theme.of(context).appBarTheme.backgroundColor ??
    Theme.of(context).colorScheme.primary;

SystemUiOverlayStyle designSystemBars(Color status, Color navigation) {
  final lightStatus =
      ThemeData.estimateBrightnessForColor(status) == Brightness.light;
  final lightNavigation =
      ThemeData.estimateBrightnessForColor(navigation) == Brightness.light;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: lightStatus ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: navigation,
    systemNavigationBarIconBrightness: lightNavigation
        ? Brightness.dark
        : Brightness.light,
  );
}

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final header = dark ? const Color(0xff163d27) : const Color(0xff28643e);
  final canvas = dark ? const Color(0xff111a14) : const Color(0xfff5f7f3);
  final primary = dark ? const Color(0xffa7d99c) : const Color(0xff28643e);
  final pressed = dark ? const Color(0xff90c585) : const Color(0xff1e4d30);
  final text = dark ? const Color(0xffedf5ec) : const Color(0xff17251b);
  final secondary = dark ? const Color(0xffbccabc) : const Color(0xff56645a);
  final surface = dark ? const Color(0xff1b271e) : Colors.white;
  final selected = dark ? const Color(0xff263d2b) : const Color(0xffeef6eb);
  final outline = dark ? const Color(0xff829985) : const Color(0xff7b8b7e);
  final divider = dark ? const Color(0xff344739) : const Color(0xffdfe7de);
  final warning = dark ? const Color(0xfff1d18a) : const Color(0xff805400);
  final warningSurface = dark
      ? const Color(0xff3c3018)
      : const Color(0xfffff3cf);
  final error = dark ? const Color(0xffffb4ab) : const Color(0xffb3261e);
  final errorSurface = dark ? const Color(0xff482723) : const Color(0xfffdeceb);
  final colors =
      ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
        primary: primary,
        onPrimary: dark ? const Color(0xff15351f) : Colors.white,
        primaryContainer: selected,
        onPrimaryContainer: primary,
        secondary: secondary,
        onSecondary: surface,
        secondaryContainer: selected,
        onSecondaryContainer: primary,
        surface: surface,
        onSurface: text,
        onSurfaceVariant: secondary,
        surfaceContainerLow: canvas,
        surfaceContainer: surface,
        surfaceContainerHigh: surface,
        outline: outline,
        outlineVariant: divider,
        tertiary: warning,
        tertiaryContainer: warningSurface,
        onTertiaryContainer: warning,
        error: error,
        errorContainer: errorSurface,
        onErrorContainer: error,
      );
  final base = ThemeData(
    colorScheme: colors,
    fontFamily: 'Inter',
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: canvas,
  );
  final textTheme = base.textTheme
      .copyWith(
        headlineMedium: designType(
          28,
          34,
          FontWeight.w600,
        ).copyWith(letterSpacing: -0.56),
        titleLarge: designType(22, 28, FontWeight.w600),
        titleMedium: designType(18, 24, FontWeight.w600),
        titleSmall: designType(16, 24, FontWeight.w600),
        bodyLarge: designType(16, 24, FontWeight.w400),
        bodyMedium: designType(16, 24, FontWeight.w400),
        bodySmall: designType(14, 20, FontWeight.w400),
        labelLarge: designType(16, 22, FontWeight.w500),
        labelMedium: designType(12, 18, FontWeight.w600),
        labelSmall: designType(12, 16, FontWeight.w500),
      )
      .apply(bodyColor: text, displayColor: text);

  final controlStyle = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: controlRadius),
    ),
    animationDuration: const Duration(milliseconds: 120),
  );
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderSide: BorderSide(color: color, width: width),
        borderRadius: controlRadius,
      );

  return base.copyWith(
    textTheme: textTheme,
    focusColor: text.withValues(alpha: 0.14),
    appBarTheme: AppBarThemeData(
      backgroundColor: header,
      foregroundColor: Colors.white,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: designSystemBars(header, surface),
    ),
    dividerTheme: DividerThemeData(color: divider, thickness: 1),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: inputBorder(outline),
      enabledBorder: inputBorder(outline),
      disabledBorder: inputBorder(outline),
      focusedBorder: inputBorder(text, 2),
      errorBorder: inputBorder(error),
      focusedErrorBorder: inputBorder(error, 2),
      labelStyle: textTheme.labelLarge?.copyWith(color: secondary),
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: controlStyle.copyWith(
        foregroundBuilder: (context, states, child) {
          final reduceMotion = MediaQuery.disableAnimationsOf(context);
          return AnimatedScale(
            scale: !reduceMotion && states.contains(WidgetState.pressed)
                ? 0.98
                : 1,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: child,
          );
        },
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? secondary
              : colors.onPrimary,
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return surface;
          if (states.contains(WidgetState.pressed)) return pressed;
          return primary;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: colors.onPrimary, width: 2);
          }
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: outline);
          }
          return BorderSide.none;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: controlStyle.copyWith(
        backgroundColor: WidgetStatePropertyAll(surface),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? secondary : text,
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: text, width: 2);
          }
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: divider);
          }
          return BorderSide(color: outline);
        }),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: controlStyle),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0,
      indicatorColor: selected,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? primary : secondary,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      indicatorColor: selected,
      selectedIconTheme: IconThemeData(color: primary),
      unselectedIconTheme: IconThemeData(color: secondary),
      selectedLabelTextStyle: textTheme.labelSmall?.copyWith(color: primary),
      unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
        color: secondary,
      ),
    ),
  );
}

enum DesignGlyph {
  updates('article-outline'),
  megaphone('campaign-outline'),
  results('assignment-outline'),
  settings('settings-outline'),
  exam('school-outline'),
  pushAlerts('notifications-outline'),
  email('mail-outline'),
  privacy('shield-outline'),
  delete('delete-outline'),
  info('info-outline'),
  freshness('schedule'),
  warning('warning-outline'),
  unreachable('cloud-off-outline'),
  refresh('refresh'),
  search('search'),
  next('chevron-right', directional: true),
  back('arrow-back', directional: true),
  externalLink('open-in-new'),
  document('document-outline'),
  listChecks('list-checks'),
  copyLink('content-copy'),
  saveName('save-outline'),
  bookmark('bookmark-outline'),
  bookmarked('bookmark-filled'),
  close('close'),
  sitting('calendar-month-outline'),
  history('schedule');

  const DesignGlyph(this.asset, {this.directional = false});
  final String asset;
  final bool directional;
}

class DesignIcon extends StatelessWidget {
  const DesignIcon(this.glyph, {this.color, this.size = 24, super.key});
  final DesignGlyph glyph;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/${glyph.asset}.svg',
    width: size,
    height: size,
    matchTextDirection: glyph.directional,
    excludeFromSemantics: true,
    colorFilter: ColorFilter.mode(
      color ??
          IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurfaceVariant,
      BlendMode.srcIn,
    ),
  );
}

class DesignBackButton extends StatelessWidget {
  const DesignBackButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: () => Navigator.maybePop(context),
    icon: const DesignIcon(DesignGlyph.back),
  );
}

class DesignIconWell extends StatelessWidget {
  const DesignIconWell(
    this.glyph, {
    this.color,
    this.background,
    this.size = 44,
    this.glyphSize = 24,
    this.rounded = false,
    super.key,
  });

  final DesignGlyph glyph;
  final Color? color, background;
  final double size, glyphSize;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? colors.primaryContainer,
        borderRadius: rounded ? cardRadius : null,
        shape: rounded ? BoxShape.rectangle : BoxShape.circle,
      ),
      child: DesignIcon(glyph, color: color ?? colors.primary, size: glyphSize),
    );
  }
}

class DesignCard extends StatelessWidget {
  const DesignCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: color ?? colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: cardRadius,
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class DesignSheet extends StatelessWidget {
  const DesignSheet({
    required this.child,
    this.gutter = screenGutter,
    super.key,
  });
  final Widget child;
  final double gutter;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 24,
        child: ColoredBox(color: headerColor(context)),
      ),
      Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: sheetRadius,
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: child,
            ),
          ),
        ),
      ),
    ],
  );
}
