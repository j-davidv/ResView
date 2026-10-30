import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/matching_worker.dart';
import '../storage/private_store.dart';
import '../storage/list_store.dart';
import 'shared.dart';

class CheckNameScreen extends StatefulWidget {
  const CheckNameScreen({
    required this.version,
    required this.store,
    required this.lists,
    this.contextDescription,
    this.initialDraft,
    this.onDraftChanged,
    this.hasSelection = false,
    this.onChooseExam,
    this.onViewResults,
    this.publications = const [],
    super.key,
  });
  final ResultVersion? version;
  final List<Publication> publications;
  final PrivateStore store;
  final ListStore lists;
  final String? contextDescription;
  final NameInput? initialDraft;
  final ValueChanged<NameInput>? onDraftChanged;
  final bool hasSelection;
  final VoidCallback? onChooseExam, onViewResults;
  @override
  State<CheckNameScreen> createState() => _CheckNameState();
}

class _CheckNameState extends State<CheckNameScreen> {
  final _form = GlobalKey<FormState>();
  final _feedbackKey = GlobalKey();
  final _fields = List.generate(4, (_) => TextEditingController());
  bool _save = false, _busy = false, _verified = false;
  double? _progress;
  String? _message, _error;
  List<NameEntry> _matches = [];
  CheckedList? _checked;

  CancelToken? _cancel;
  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    try {
      final name = widget.initialDraft ?? await widget.store.readName();
      if (name != null && mounted) {
        setState(() {
          final values = [
            name.surname,
            name.givenNames,
            name.middleName,
            name.suffix,
          ];
          for (var i = 0; i < 4; i++) {
            _fields[i].text = values[i];
          }
          _save = widget.initialDraft == null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Saved name could not be read. Re-enter it or delete it in Settings.',
        );
      }
    }
  }

  NameInput get _input => NameInput(
    _fields[0].text.trim(),
    _fields[1].text.trim(),
    _fields[2].text.trim(),
    _fields[3].text.trim(),
  );
  @override
  void dispose() {
    _cancel?.cancel();
    _checked?.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _clearOutcome() {
    widget.onDraftChanged?.call(_input);
    _cancel?.cancel();
    setState(() {
      _message = null;
      _matches = [];
    });
  }

  void _revealFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _feedbackKey.currentContext;
      if (!mounted || target == null || (_error == null && _message == null)) {
        return;
      }
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
      );
    });
  }

  Future<void> _saveName() async {
    if (!_form.currentState!.validate()) return;
    try {
      await widget.store.saveName(_input);
      if (mounted) {
        setState(() => _save = true);
        feedback(context, 'Name saved on this device.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your name. Try again.');
      }
    }
  }

  Future<void> _check() async {
    if (!_form.currentState!.validate() || widget.version == null) return;
    FocusScope.of(context).unfocus();
    final token = CancelToken();
    _cancel = token;
    setState(() {
      _busy = true;
      _verified = false;
      _error = null;
      _message = null;
      _matches = [];
      _progress = 0;
    });
    CheckedList? checked;
    try {
      if (_save) await widget.store.saveName(_input);
      await _checked?.dispose();
      _checked = null;
      checked = await widget.lists.prepare(
        widget.version!,
        cancellation: token,
        onProgress: (value) {
          if (mounted && !token.cancelled) setState(() => _progress = value);
        },
      );
      token.check();
      checked.contextDescription = widget.contextDescription;
      if (mounted) {
        setState(() {
          _verified = true;
          _progress = null;
        });
      }
      final exact = await matchOnDevice(
        checked.document,
        _input,
        possible: false,
        registerCancellation: (cancel) {
          token.onCancel = cancel;
          if (token.cancelled) cancel();
        },
      );
      token.check();
      if (!mounted) {
        await checked.dispose();
        return;
      }
      setState(() {
        _checked = checked;

        _matches = exact;
        _message = exact.isEmpty
            ? 'No exact match found. Check your entered name and the official PRC list.'
            : "A matching name appears in PRC's published list.";
      });
    } catch (error) {
      await checked?.dispose();
      if (mounted) {
        setState(() {
          _error = error is ListFailure ? error.message : 'Automatic name checking unavailable. Try again or open the official list.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _revealFeedback();
    }
  }

  Future<void> _showPossible() async {
    final checked = _checked;
    if (checked == null || _busy) return;
    final token = CancelToken();
    _cancel = token;
    setState(() {
      _busy = true;
      _verified = true;
      _progress = null;
      _error = null;
    });
    try {
      final possible = await matchOnDevice(
        checked.document,
        _input,
        possible: true,
        registerCancellation: (cancel) {
          token.onCancel = cancel;
          if (token.cancelled) cancel();
        },
      );
      token.check();
      if (mounted) {
        setState(() {
          _matches = possible;
          _message = possible.isEmpty
              ? 'No possible matches found. Check the official PRC list.'
              : 'Possible match — confirm the published details.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ListFailure
              ? error.message
              : 'Possible matching unavailable. Inspect the official list.',
        );
      }
    } finally {
      token.onCancel = null;
      if (mounted) setState(() => _busy = false);
      _revealFeedback();
    }
  }

  Future<void> _saveList() async {
    try {
      final result = await widget.lists.saveOffline(_checked!);
      if (mounted) {
        setState(() {});
        feedback(
          context,
          result == SaveResult.saved ? 'List saved offline.' : 'Saving would exceed 50 MiB. Delete a saved list in Settings, then retry.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save the offline list. Check device storage and retry.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.version;
    final allowed = v?.state == PublicationState.checkingAvailable;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!allowed)
            Notice(
              !widget.hasSelection
                  ? 'Choose an exam to check a name'
                  : 'Automatic name checking unavailable.',
              !widget.hasSelection
                  ? 'Select an exam, sitting and category first. You can still save a name on this device.'
                  : v?.state == PublicationState.superseded
                  ? 'This version is outdated. Use the latest publication.'
                  : 'A validated list for this sitting is required. You can still save a name on this device.',
              action: !widget.hasSelection
                  ? OutlinedButton(
                      onPressed: widget.onChooseExam,
                      child: const Text('Choose exam'),
                    )
                  : OutlinedButton(
                      onPressed: widget.onViewResults,
                      child: const Text('View results'),
                    ),
            ),
          const Heading('Your name'),
          const Text(
            'Your name stays on this device. Enter it as recorded in your PRC application.',
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: _fields[i],
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: i == 3
                    ? TextInputAction.done
                    : TextInputAction.next,
                maxLines: null,
                decoration: InputDecoration(
                  labelText: [
                    'Surname',
                    'Given names',
                    'Middle name',
                    'Suffix',
                  ][i],
                  helperText: i >= 2 ? 'Optional' : null,
                ),
                validator: i < 2
                    ? (value) => value == null || value.trim().isEmpty
                          ? 'Enter ${i == 0 ? 'your surname' : 'your given names'}.'
                          : null
                    : null,
                onChanged: (_) => _clearOutcome(),
              ),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Save when I check'),
            subtitle: const Text(
              'Unchecking does not delete a previously saved name. Delete it in Settings.',
            ),
            value: _save,
            onChanged: _busy ? null : (value) => setState(() => _save = value!),
          ),
          TextButton(
            onPressed: _busy ? null : _saveName,
            child: const Text('Save name now'),
          ),
          if (v != null) ...[
            FreshnessSection(v),
            if (v.freshness != SourceFreshness.fresh)
              const Text(
                'If you use a saved list offline, it may not include corrections that this device has not seen.',
              ),
            const Heading('List download'),
            Text(
              v.namesBytes == null
                  ? 'Download size not yet confirmed.'
                  : '${(v.namesBytes! / (1024 * 1024)).toStringAsFixed(2)} MiB · Temporary unless you save it offline.',
            ),
            Text('Document version: ${v.documentVersion}'),
          ],
          const SizedBox(height: 16),
          if (_busy) ...[
            LinearProgressIndicator(
              value: _progress,
              semanticsLabel: _verified ? 'Checking name' : 'Downloading list',
            ),
            const SizedBox(height: 8),
            Text(
              _verified
                  ? 'Checking name on this device'
                  : 'Downloading and verifying list',
            ),
            const Text(
              'Leaving this screen cancels checking. Your unsaved name stays in memory for this session.',
            ),
            OutlinedButton(
              onPressed: () => _cancel?.cancel(),
              child: const Text('Cancel'),
            ),
          ] else
            FilledButton(
              onPressed: allowed && v?.namesBytes != null ? _check : null,
              child: const Text('Check name'),
            ),
          Column(
            key: _feedbackKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Notice('Checking status', _error!, warning: true),
              if (_message != null) ...[
                const Heading('Personal name-check outcome'),
                Notice(
                  _message!,
                  'A matching published name does not confirm your identity. An absent name does not mean you failed the exam.',
                ),
                for (final e in _matches) ...[
                  SelectableText(
                    e.publishedName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Entry ${e.sequence} · Section ${e.sectionId} · PDF page ${e.physicalPage}',
                  ),
                  if (_message ==
                          'Possible match — confirm the published details.' &&
                      e.components != null)
                    Text(
                      'Published middle name: ${e.components!.middleName}\nPublished suffix: ${e.components!.suffix}',
                    ),
                  const Divider(),
                ],
                if (_checked?.document.componentsReliable == true)
                  OutlinedButton(
                    onPressed: _busy ? null : _showPossible,
                    child: const Text('Show possible matches'),
                  )
                else
                  const Text(
                    'Possible matching is not supported for this list format. Inspect the official list.',
                  ),
                if (_checked != null)
                  OutlinedButton(
                    onPressed: _checked!.alreadySaved ? null : _saveList,
                    child: Text(
                      _checked!.alreadySaved
                          ? 'List saved offline'
                          : 'Save list offline',
                    ),
                  ),
              ],
            ],
          ),
          if (v != null) SourceLinks(v, publications: widget.publications),
        ],
      ),
    );
  }
}
