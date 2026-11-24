import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design.dart';

class ExamShell extends StatelessWidget {
  const ExamShell({
    required this.destination,
    required this.onNavigate,
    required this.onChoose,
    required this.child,
    this.advisoryPilot = false,
    this.examTitle,
    this.examDetails,
    this.restoringSelection = false,
    this.canRefresh = false,
    this.onRefresh,
    this.onBack,
    super.key,
  });

  final bool advisoryPilot;
  List<String> get _titles => [
    'Results',
    if (advisoryPilot) 'Updates',
    'Bookmarks',
    'History',
    'Settings',
  ];
  List<DesignGlyph> get _glyphs => [
    DesignGlyph.results,
    if (advisoryPilot) DesignGlyph.updates,
    DesignGlyph.bookmark,
    DesignGlyph.history,
    DesignGlyph.settings,
  ];

  final int destination;
  final ValueChanged<int> onNavigate;
  final String? examTitle, examDetails;
  final bool restoringSelection, canRefresh;
  final VoidCallback onChoose;
  final VoidCallback? onRefresh;
  final VoidCallback? onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final header = headerColor(context);
      final surface = theme.colorScheme.surface;
      final scaler = MediaQuery.textScalerOf(context);
      final wide = constraints.maxWidth >= 600 && constraints.maxHeight >= 500;
      final compact =
          constraints.maxHeight < 500 ||
          scaler.scale(28) > 40 ||
          MediaQuery.viewInsetsOf(context).bottom > 0;
      final title = _titles[destination];
      final bookmarks = destination == (advisoryPilot ? 2 : 1);
      final inHistory = destination == (advisoryPilot ? 3 : 2);
      final settings = destination == _titles.length - 1;
      final settingsAction = IconButton(
        tooltip: 'Settings',
        color: Colors.white,
        onPressed: () => onNavigate(_titles.length - 1),
        icon: const DesignIcon(DesignGlyph.settings),
      );
      final back = BackButton(onPressed: onBack, color: Colors.white);
      final showContext =
          !settings && !bookmarks && !inHistory && !restoringSelection;
      final contextCard = ExamContextCard(
        title: examTitle,
        details: examDetails,
        onChoose: onChoose,
        description: destination == 0
            ? 'Choose an exam and sitting to view its results.'
            : 'Choose an exam and sitting to check for schedule changes.',
      );
      final refresh = IconButton(
        tooltip: 'Refresh available metadata',
        onPressed: onRefresh,
        color: Colors.white,
        disabledColor: headerSecondary,
        icon: const DesignIcon(DesignGlyph.refresh),
      );
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: designSystemBars(header, surface),
        child: PopScope(
          canPop: !settings,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && settings) onBack?.call();
          },
          child: Scaffold(
            appBar: compact
                ? AppBar(
                    title: Text(title),
                    leading: settings ? back : null,
                    toolbarHeight: math.max(56, scaler.scale(28) + 8),
                    actions: [
                      if (canRefresh) refresh,
                      if (!settings) settingsAction,
                    ],
                  )
                : null,
            body: ColoredBox(
              color: header,
              child: SafeArea(
                top: !compact,
                bottom: wide || settings,
                child: ColoredBox(
                  color: theme.scaffoldBackgroundColor,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (wide && !settings)
                        NavigationRail(
                          scrollable: true,
                          labelType: NavigationRailLabelType.all,
                          useIndicator: true,
                          selectedIndex: destination,
                          onDestinationSelected: onNavigate,
                          destinations: [
                            for (var i = 0; i < _titles.length - 1; i++)
                              NavigationRailDestination(
                                icon: DesignIcon(_glyphs[i]),
                                label: Text(_titles[i]),
                              ),
                          ],
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          key: ValueKey(destination),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!compact)
                                ColoredBox(
                                  color: header,
                                  child: Align(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: maxContentWidth,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          screenGutter,
                                          24,
                                          screenGutter,
                                          16,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'ResView',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: headerSecondary,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                if (settings) back,
                                                Expanded(
                                                  child: Semantics(
                                                    header: true,
                                                    child: Text(
                                                      title,
                                                      style: theme
                                                          .textTheme
                                                          .headlineMedium
                                                          ?.copyWith(
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                if (canRefresh) refresh,
                                                if (!settings) settingsAction,
                                              ],
                                            ),
                                            if (settings) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Privacy and preferences',
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                      color: headerSecondary,
                                                    ),
                                              ),
                                            ] else if (showContext &&
                                                examTitle != null) ...[
                                              const SizedBox(height: 16),
                                              contextCard,
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              DesignSheet(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (showContext &&
                                        (compact || examTitle == null)) ...[
                                      contextCard,
                                      const SizedBox(height: 16),
                                    ],
                                    child,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: wide || settings
                ? null
                : DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withValues(
                            alpha: 0.12,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: _buildNavigation(context, constraints.maxWidth),
                  ),
          ),
        ),
      );
    },
  );

  Widget _buildNavigation(BuildContext context, double width) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final labelStyle = designType(12, 16, FontWeight.w600);
    final navigationTitles = _titles.take(_titles.length - 1).toList();
    final wordWidths = navigationTitles.map((title) {
      final word = TextPainter(
        text: TextSpan(text: title, style: labelStyle),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      final minimum = word.minIntrinsicWidth.ceilToDouble() + 8;
      word.dispose();
      return minimum;
    }).toList();
    final available = width - MediaQuery.paddingOf(context).horizontal;
    if (scaler.scale(12) > 15.6 ||
        wordWidths.any(
          (minimum) => minimum > available / navigationTitles.length,
        )) {
      return _buildWrappingNavigation(context, available, wordWidths);
    }
    return NavigationBar(
      height: 80,
      animationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return designType(
          12,
          16,
          selected ? FontWeight.w600 : FontWeight.w500,
        ).copyWith(color: selected ? colors.primary : colors.onSurfaceVariant);
      }),
      selectedIndex: destination,
      onDestinationSelected: onNavigate,
      destinations: [
        for (var i = 0; i < navigationTitles.length; i++)
          NavigationDestination(
            icon: DesignIcon(
              _glyphs[i] == DesignGlyph.updates
                  ? DesignGlyph.megaphone
                  : _glyphs[i],
            ),
            label: _titles[i],
          ),
      ],
    );
  }

  Widget _buildWrappingNavigation(
    BuildContext context,
    double width,
    List<double> wordWidths,
  ) {
    final colors = Theme.of(context).colorScheme;
    final total = wordWidths.reduce((sum, value) => sum + value);
    final fits = total <= width;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.32,
          ),
          child: SingleChildScrollView(
            child: Wrap(
              children: [
                for (final (index, title)
                    in _titles.take(_titles.length - 1).indexed)
                  SizedBox(
                    width: fits
                        ? wordWidths[index] +
                              (width - total) / wordWidths.length
                        : width / 2,
                    child: Semantics(
                      button: true,
                      selected: destination == index,
                      inMutuallyExclusiveGroup: true,
                      child: InkWell(
                        onTap: () => onNavigate(index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: destination == index
                                      ? colors.primaryContainer
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: DesignIcon(
                                  _glyphs[index] == DesignGlyph.updates
                                      ? DesignGlyph.megaphone
                                      : _glyphs[index],
                                  color: destination == index
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style:
                                    designType(
                                      12,
                                      16,
                                      destination == index
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ).copyWith(
                                      color: destination == index
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExamContextCard extends StatelessWidget {
  const ExamContextCard({
    required this.onChoose,
    this.title,
    this.details,
    this.description,
    this.settings = false,
    super.key,
  });

  final String? title, details, description;
  final VoidCallback? onChoose;
  final bool settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = title != null;
    final label = selected ? 'Change' : 'Choose exam';
    final message = selected ? details : description;
    final content = Row(
      children: [
        DesignIconWell(DesignGlyph.exam, size: settings ? 40 : 44),
        SizedBox(width: settings ? 8 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? 'No exam selected',
                style: theme.textTheme.titleSmall,
              ),
              if (message != null) ...[
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final action = settings
        ? TextButton(
            onPressed: onChoose,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label)),
                const SizedBox(width: 4),
                const DesignIcon(DesignGlyph.next, size: 20),
              ],
            ),
          )
        : FilledButton(onPressed: onChoose, child: Text(label));
    return DesignCard(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaledLabel = MediaQuery.textScalerOf(context).scale(16);
          if (constraints.maxWidth < 272 || scaledLabel > 21) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [content, const SizedBox(height: 8), action],
            );
          }
          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 8),
              action,
            ],
          );
        },
      ),
    );
  }
}
