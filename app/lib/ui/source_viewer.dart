import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design.dart';

Uri? sourceViewerUrl(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443 ||
      uri.fragment.isNotEmpty) {
    return null;
  }
  if (uri.host == 'www.prc.gov.ph' || uri.host == 'prc.gov.ph') {
    return uri.path.toLowerCase().endsWith('.pdf') ? null : uri;
  }
  if (uri.host != 'drive.google.com') return null;
  final match = RegExp(r'^/file/d/([A-Za-z0-9_-]{10,200})/(view|preview)/?$')
      .firstMatch(uri.path);
  return match == null
      ? null
      : Uri.https('drive.google.com', '/file/d/${match[1]}/preview', {
          'hl': 'en',
        });
}

class SourceViewer extends StatefulWidget {
  const SourceViewer({
    required this.uri,
    required this.openExternal,
    super.key,
  });
  final Uri uri;
  final Future<void> Function(Uri) openExternal;
  @override
  State<SourceViewer> createState() => _SourceViewerState();
}

class _SourceViewerState extends State<SourceViewer> {
  final _query = TextEditingController();
  late final Timer _noticeTimer;
  bool _noticeVisible = true;
  MethodChannel? _channel;
  late Uri _uri = widget.uri;
  Uri? _blocked;
  String? _error, _searchStatus;
  bool _loading = true, _finding = false, _hasMatches = false;
  int _generation = 0;
  bool get _drive => _uri.host == 'drive.google.com';

  @override
  void initState() {
    super.initState();
    _noticeTimer = Timer(const Duration(seconds: 3), _dismissNotice);
  }

  void _dismissNotice() {
    _noticeTimer.cancel();
    setState(() => _noticeVisible = false);
  }

  Future<void> _event(MethodCall call) async {
    if (!mounted) return;
    final data = Map<String, dynamic>.from(call.arguments as Map);
    setState(() {
      switch (call.method) {
        case 'loading':
          _uri = Uri.parse(data['url'] as String);
          _loading = true;
          _error = _searchStatus = null;
          _blocked = null;
          _hasMatches = false;
          _query.clear();
        case 'loaded':
          _loading = false;
        case 'failed':
          _loading = false;
          _error = 'The official source could not be loaded. Check your connection and retry, or open it in your browser.';
        case 'blocked':
          _blocked = Uri.tryParse(data['url'] as String);
      }
    });
  }

  void _created(int id) {
    _channel = MethodChannel('org.resview/source_view/$id')
      ..setMethodCallHandler(_event);
  }

  Future<void> _find([int direction = 0]) async {
    if (_finding || _query.text.trim().isEmpty || _channel == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _finding = true;
      _searchStatus = null;
      _hasMatches = false;
    });
    final generation = _generation;
    final uri = _uri;
    try {
      final result = await _channel!
          .invokeMapMethod<String, dynamic>('find', {
            'query': _query.text.trim(),
            'direction': direction,
          })
          .timeout(const Duration(seconds: 15));
      if (!mounted || generation != _generation || uri != _uri) return;
      final total = result!['total'] as int;
      final current = result['current'] as int;
      setState(() {
        _hasMatches = total > 0;
        _searchStatus = total == 0
            ? 'No text matches. This is not an exam outcome.'
            : '$current of $total text matches';
      });
    } catch (error) {
      if (mounted && generation == _generation && uri == _uri) {
        final detail = error is PlatformException ? error.message : null;
        setState(
          () => _searchStatus =
              '${detail ?? 'Document search is unavailable'}. Retry or open this source in your browser.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _finding = false);
      }
    }
  }

  Future<void> _back() async {
    try {
      if (await _channel?.invokeMethod<bool>('back') == true) return;
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  void _retry() {
    _channel?.setMethodCallHandler(null);
    setState(() {
      _channel = null;
      _generation++;
      _error = _searchStatus = null;
      _blocked = null;
      _loading = true;
      _finding = _hasMatches = false;
    });
  }

  @override
  void dispose() {
    _noticeTimer.cancel();
    _channel?.setMethodCallHandler(null);
    _query.clear();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supported =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const DesignIcon(DesignGlyph.back),
            onPressed: _back,
          ),
          title: const Text('Source'),
          actions: [
            IconButton(
              tooltip: 'Reload source',
              icon: const DesignIcon(DesignGlyph.refresh),
              onPressed: _retry,
            ),
            IconButton(
              tooltip: 'Open in browser',
              icon: const DesignIcon(DesignGlyph.externalLink),
              onPressed: () => widget.openExternal(_uri),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, size) => Column(
              children: [
                if (_drive || _blocked != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: size.maxHeight * .55,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(screenGutter),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _uri.host,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (_drive)
                            const Text(
                              'Search uses Google Drive. ResView does not save this search text.',
                            ),
                          if (_drive && supported) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _query,
                              enabled: !_finding,
                              maxLength: 200,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.search,
                              decoration: const InputDecoration(
                                labelText: 'Find text in document',
                                counterText: '',
                              ),
                              onChanged: (_) => setState(() {
                                _hasMatches = false;
                                _searchStatus = null;
                              }),
                              onSubmitted: (_) => _find(),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton(
                                  onPressed:
                                      _loading ||
                                          _finding ||
                                          _query.text.trim().isEmpty
                                      ? null
                                      : () => _find(),
                                  child: const Text('Find'),
                                ),
                                OutlinedButton(
                                  onPressed: _hasMatches && !_finding
                                      ? () => _find(-1)
                                      : null,
                                  child: const Text('Previous'),
                                ),
                                OutlinedButton(
                                  onPressed: _hasMatches && !_finding
                                      ? () => _find(1)
                                      : null,
                                  child: const Text('Next'),
                                ),
                              ],
                            ),
                            if (_finding) const Text('Searching document…'),
                            if (_searchStatus != null)
                              Semantics(
                                liveRegion: true,
                                child: Text(_searchStatus!),
                              ),
                          ],
                          if (_blocked != null) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'This link opens outside the official viewer.',
                            ),
                            TextButton(
                              onPressed: () => widget.openExternal(_blocked!),
                              child: const Text('Open link in browser'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (_loading && supported && _error == null)
                  const LinearProgressIndicator(),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      !supported || _error != null
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    _error ?? 'In-app viewing is available on Android. Open this source in your browser.',
                                  ),
                                  TextButton(
                                    onPressed: _retry,
                                    child: const Text('Retry'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => widget.openExternal(_uri),
                                    child: const Text('Open in browser'),
                                  ),
                                ],
                              ),
                            )
                          : AndroidView(
                              key: ValueKey(_generation),
                              viewType: 'org.resview/source_view',
                              creationParams: {'url': _uri.toString()},
                              creationParamsCodec: const StandardMessageCodec(),
                              onPlatformViewCreated: _created,
                              gestureRecognizers: {
                                Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer(),
                                ),
                              },
                            ),
                      if (!_drive && _noticeVisible && _error == null)
                        Positioned(
                          top: screenGutter,
                          left: screenGutter,
                          right: screenGutter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: size.maxHeight * .55,
                            ),
                            child: Material(
                              elevation: 4,
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: cardRadius,
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _uri.host,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Close notice',
                                                icon: const DesignIcon(
                                                  DesignGlyph.close,
                                                ),
                                                onPressed: _dismissNotice,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'You are viewing PRC online. Open the passing-list link in this announcement to search its document.',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 1, end: 0),
                                    duration: const Duration(seconds: 3),
                                    builder: (context, remaining, child) =>
                                        LinearProgressIndicator(
                                          value: remaining,
                                          minHeight: 3,
                                          semanticsLabel:
                                              'Time until notice closes',
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
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
