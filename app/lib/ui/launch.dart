import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'design.dart';

const _subtitle = 'PRC exam results';
const _disclosure = 'Independent app. Not affiliated with PRC.';
const _introGutter = 24.0;

class _Logo extends StatelessWidget {
  const _Logo(this.size);
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/resview-logo.png',
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
  );
}

class LaunchScreen extends StatelessWidget {
  const LaunchScreen({required this.showProgress, super.key});
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canvas = theme.scaffoldBackgroundColor;
    final secondary = theme.colorScheme.onSurfaceVariant;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: designSystemBars(canvas, canvas),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(_introGutter),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _Logo(120),
                                const SizedBox(height: 12),
                                Text(
                                  'ResView',
                                  style: designType(32, 40, FontWeight.w600)
                                      .copyWith(
                                        color: theme.colorScheme.onSurface,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _subtitle,
                                  style: TextStyle(color: secondary),
                                ),
                                if (showProgress) ...[
                                  const SizedBox(height: 40),
                                  if (!MediaQuery.disableAnimationsOf(context))
                                    const ExcludeSemantics(
                                      child: SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      'Opening ResView…',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: secondary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _Disclosure(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onChoose,
    this.advisoryPilot = false,
    required this.onSkip,
    required this.busy,
    this.error,
    super.key,
  });

  final VoidCallback onChoose, onSkip;
  final bool busy, advisoryPilot;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final header = headerColor(context);
    final compact =
        MediaQuery.sizeOf(context).height < 500 ||
        MediaQuery.textScalerOf(context).scale(28) > 40;
    final introSteps = [
      (
        DesignGlyph.exam,
        '1. Choose your exam',
        'Select your exam, sitting and category. Domestic, special and overseas sittings are listed separately.',
      ),
      (
        DesignGlyph.results,
        '2. Check Results',
        advisoryPilot
            ? 'Check Results for official releases. Updates shows PRC announcements for your exam from 2026 onward.'
            : 'See whether PRC has released results for your sitting. Open a publication to read the official announcement.',
      ),
      (
        DesignGlyph.externalLink,
        '3. Read the official list',
        'Open the successful-examinee list from PRC. Use Find text in document to search supported Google Drive lists.',
      ),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: designSystemBars(header, theme.scaffoldBackgroundColor),
      child: Scaffold(
        body: ColoredBox(
          color: header,
          child: SafeArea(
            bottom: false,
            child: ColoredBox(
              color: theme.scaffoldBackgroundColor,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ColoredBox(
                      color: header,
                      child: Align(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              _introGutter,
                              compact ? 12 : 32,
                              _introGutter,
                              24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const _Logo(62),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ResView',
                                            style: designType(
                                              26,
                                              32,
                                              FontWeight.w600,
                                            ).copyWith(color: Colors.white),
                                          ),
                                          Text(
                                            _subtitle,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: headerSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: compact ? 12 : 24),
                                Semantics(
                                  header: true,
                                  child: Text(
                                    'Your exam,\none step at a time.',
                                    style: designType(
                                      28,
                                      35,
                                      FontWeight.w600,
                                    ).copyWith(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    DesignSheet(
                      gutter: _introGutter,
                      child: SafeArea(
                        top: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'How ResView works',
                                style: designType(20, 26, FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Browse without signing up.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final (index, step) in introSteps.indexed) ...[
                              if (index > 0)
                                const Divider(height: 1, indent: 56),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: _Instruction(step.$1, step.$2, step.$3),
                              ),
                            ],
                            const SizedBox(height: 12),
                            DesignCard(
                              color: colors.primaryContainer,
                              padding: const EdgeInsets.all(12),
                              child: const _Instruction(
                                DesignGlyph.pushAlerts,
                                'Alerts are optional.',
                                'Enable push or email in Settings.',
                                useWell: false,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const _Disclosure(),
                            if (error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    error!,
                                    style: TextStyle(color: colors.error),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: busy ? null : onChoose,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 50),
                              ),
                              child: const Text('Choose my exam'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: busy ? null : onSkip,
                              child: const Text('Skip introduction'),
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
        ),
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction(
    this.glyph,
    this.title,
    this.message, {
    this.useWell = true,
  });
  final DesignGlyph glyph;
  final String title, message;
  final bool useWell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: useWell
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (useWell)
          DesignIconWell(glyph, rounded: true)
        else
          DesignIcon(glyph, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Disclosure extends StatelessWidget {
  const _Disclosure();

  @override
  Widget build(BuildContext context) => Text(
    _disclosure,
    textAlign: TextAlign.center,
    style: designType(
      12,
      18,
      FontWeight.w400,
    ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}
