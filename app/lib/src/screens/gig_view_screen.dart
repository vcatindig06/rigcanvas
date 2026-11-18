import 'package:material_ui/material_ui.dart';

import '../models/rig_preset.dart';
import '../models/rig_setlist.dart';
import '../state/preset_controller.dart';
import '../state/setlist_controller.dart';

class GigViewScreen extends StatefulWidget {
  const GigViewScreen({
    required this.controller,
    required this.presetController,
    super.key,
  });

  final SetlistController controller;
  final PresetController presetController;

  @override
  State<GigViewScreen> createState() => _GigViewScreenState();
}

class _GigViewScreenState extends State<GigViewScreen> {
  SetlistController get controller => widget.controller;
  PresetController get presetController => widget.presetController;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createSetlist() async {
    final name = await _setlistNameDialog(
      title: 'Create setlist',
      initialValue: 'Sunday Service',
    );
    if (name == null) return;
    try {
      await controller.createSetlist(name);
    } catch (error) {
      _showMessage('Could not create setlist: $error');
    }
  }

  Future<void> _renameSetlist(RigSetlist setlist) async {
    final name = await _setlistNameDialog(
      title: 'Rename setlist',
      initialValue: setlist.name,
    );
    if (name == null) return;
    try {
      await controller.renameSetlist(setlist.id, name);
    } catch (error) {
      _showMessage('Could not rename setlist: $error');
    }
  }

  Future<String?> _setlistNameDialog({
    required String title,
    required String initialValue,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _SetlistNameDialog(
        title: title,
        initialValue: initialValue,
      ),
    );
  }

  Future<void> _deleteSetlist(RigSetlist setlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete setlist?'),
        content: Text('Delete "${setlist.name}" and its song order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.deleteSetlist(setlist.id);
    } catch (error) {
      _showMessage('Could not delete setlist: $error');
    }
  }

  Future<void> _editSong([RigSong? song]) async {
    final draft = await showDialog<_SongDraft>(
      context: context,
      builder: (context) => _SongEditorDialog(
        song: song,
        presets: presetController.presets,
      ),
    );
    if (draft == null) return;

    try {
      if (song == null) {
        await controller.addSong(
          title: draft.title,
          keySignature: draft.keySignature,
          bpm: draft.bpm,
          notes: draft.notes,
          presetId: draft.presetId,
          sceneId: draft.sceneId,
        );
      } else {
        await controller.updateSong(
          song.copyWith(
            title: draft.title,
            keySignature: draft.keySignature,
            bpm: draft.bpm,
            clearBpm: draft.bpm == null,
            notes: draft.notes,
            presetId: draft.presetId,
            clearPresetId: draft.presetId == null,
            sceneId: draft.sceneId,
            clearSceneId: draft.sceneId == null,
          ),
        );
      }
    } catch (error) {
      _showMessage('Could not save song: $error');
    }
  }

  Future<void> _deleteSong(RigSong song) async {
    try {
      await controller.deleteSong(song.id);
    } catch (error) {
      _showMessage('Could not remove song: $error');
    }
  }

  Future<void> _recallRig(RigSong song) async {
    final presetId = song.presetId;
    if (presetId == null) {
      _showMessage('No local preset is assigned to this song.');
      return;
    }
    RigPreset? preset;
    for (final candidate in presetController.presets) {
      if (candidate.id == presetId) {
        preset = candidate;
        break;
      }
    }
    if (preset == null) {
      _showMessage('The assigned local preset is no longer available.');
      return;
    }

    presetController.selectPreset(preset.id);
    final sceneId = song.sceneId;
    if (sceneId != null) {
      final hasScene = preset.scenes.any((scene) => scene.id == sceneId);
      if (!hasScene) {
        _showMessage('Preset loaded, but its assigned scene is unavailable.');
        return;
      }
      await presetController.applyScene(sceneId);
    }
    _showMessage(
      'Loaded "${preset.name}" into the local workspace. Hardware sync is not enabled.',
    );
  }

  String _songSubtitle(RigSong song) {
    final parts = <String>[
      'Key ${song.keySignature}',
      if (song.bpm != null) '${song.bpm} BPM',
    ];
    if (song.presetId != null) {
      final preset = _presetFor(song.presetId);
      parts.add(preset == null ? 'Preset unavailable' : preset.name);
      if (song.sceneId != null) {
        final scene = preset?.scenes.where((item) => item.id == song.sceneId);
        parts.add(
          scene != null && scene.isNotEmpty
              ? scene.first.name
              : 'Scene unavailable',
        );
      }
    } else {
      parts.add('No rig assigned');
    }
    return parts.join('  ·  ');
  }

  RigPreset? _presetFor(String? id) {
    if (id == null) return null;
    for (final preset in presetController.presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final setlist = controller.activeSetlist;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gig View',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Stage-ready setlists and local rig assignments.',
                        style: TextStyle(color: Color(0xFF9AA4B2)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  _MetricPill(label: '${controller.setlists.length} SETLISTS'),
                  _SimulationPill(),
                  OutlinedButton.icon(
                    onPressed: _createSetlist,
                    icon: const Icon(Icons.add),
                    label: const Text('New setlist'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SafetyNotice(),
              const SizedBox(height: 18),
              if (controller.errorMessage != null) ...[
                _ErrorBanner(message: controller.errorMessage!),
                const SizedBox(height: 12),
              ],
              if (setlist == null)
                Expanded(
                  child: _EmptyGigState(onCreate: _createSetlist),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(setlist.id),
                        initialValue: setlist.id,
                        decoration: const InputDecoration(
                          labelText: 'Current setlist',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: controller.setlists
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(
                                  item.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) controller.selectSetlist(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: '',
                      onSelected: (action) {
                        if (action == 'rename') _renameSetlist(setlist);
                        if (action == 'delete') _deleteSetlist(setlist);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename setlist'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete setlist'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '${setlist.songs.length} SONGS',
                      style: const TextStyle(
                        color: Color(0xFF9AA4B2),
                        fontSize: 11,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => _editSong(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add song'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: setlist.songs.isEmpty
                      ? _EmptySongState(onAdd: () => _editSong())
                      : ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: setlist.songs.length,
                          onReorderItem: (oldIndex, newIndex) {
                            controller.reorderSongs(oldIndex, newIndex);
                          },
                          itemBuilder: (context, index) {
                            final song = setlist.songs[index];
                            final preset = _presetFor(song.presetId);
                            return Padding(
                              key: ValueKey(song.id),
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Card(
                                child: ListTile(
                                  onTap: () => _editSong(song),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF39231F),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Color(0xFFFFB29D),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    song.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _songSubtitle(song),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF9AA4B2),
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: '',
                                        onPressed: preset == null
                                            ? null
                                            : () => _recallRig(song),
                                        icon: const Icon(Icons.play_arrow),
                                      ),
                                      PopupMenuButton<String>(
                                        tooltip: '',
                                        onSelected: (action) {
                                          if (action == 'edit') _editSong(song);
                                          if (action == 'remove') _deleteSong(song);
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit song'),
                                          ),
                                          PopupMenuItem(
                                            value: 'remove',
                                            child: Text('Remove song'),
                                          ),
                                        ],
                                      ),
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.drag_indicator,
                                            color: Color(0xFF8993A1),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  setlist.description.isEmpty
                      ? 'Local setlist · Song order and rig assignments are saved on this device.'
                      : setlist.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF788391),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SetlistNameDialog extends StatefulWidget {
  const _SetlistNameDialog({
    required this.title,
    required this.initialValue,
  });

  final String title;
  final String initialValue;

  @override
  State<_SetlistNameDialog> createState() => _SetlistNameDialogState();
}

class _SetlistNameDialogState extends State<_SetlistNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(
          labelText: 'Setlist name',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SongDraft {
  const _SongDraft({
    required this.title,
    required this.keySignature,
    required this.notes,
    this.bpm,
    this.presetId,
    this.sceneId,
  });

  final String title;
  final String keySignature;
  final String notes;
  final int? bpm;
  final String? presetId;
  final String? sceneId;
}

class _SongEditorDialog extends StatefulWidget {
  const _SongEditorDialog({
    required this.song,
    required this.presets,
  });

  final RigSong? song;
  final List<RigPreset> presets;

  @override
  State<_SongEditorDialog> createState() => _SongEditorDialogState();
}

class _SongEditorDialogState extends State<_SongEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _keyController;
  late final TextEditingController _bpmController;
  late final TextEditingController _notesController;
  late String _presetId;
  late String _sceneId;

  RigPreset? get _selectedPreset {
    for (final preset in widget.presets) {
      if (preset.id == _presetId) return preset;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final song = widget.song;
    _titleController = TextEditingController(text: song?.title ?? '');
    _keyController = TextEditingController(
      text: song?.keySignature ?? 'E',
    );
    _bpmController = TextEditingController(
      text: song?.bpm?.toString() ?? '',
    );
    _notesController = TextEditingController(text: song?.notes ?? '');
    _presetId = song?.presetId ?? '';
    _sceneId = song?.sceneId ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _keyController.dispose();
    _bpmController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final bpmText = _bpmController.text.trim();
    Navigator.of(context).pop(
      _SongDraft(
        title: _titleController.text.trim(),
        keySignature: _keyController.text.trim(),
        bpm: bpmText.isEmpty ? null : int.parse(bpmText),
        notes: _notesController.text.trim(),
        presetId: _presetId.isEmpty ? null : _presetId,
        sceneId: _sceneId.isEmpty ? null : _sceneId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenes = _selectedPreset?.scenes ?? const <RigScene>[];
    final validSceneId = scenes.any((scene) => scene.id == _sceneId)
        ? _sceneId
        : '';

    return AlertDialog(
      title: Text(widget.song == null ? 'Add song' : 'Edit song'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Song title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a song title.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _keyController,
                        maxLength: 8,
                        decoration: const InputDecoration(
                          labelText: 'Key',
                          hintText: 'E, Bb, F#m',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a key.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _bpmController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tempo (BPM)',
                          hintText: 'Optional',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final input = value?.trim() ?? '';
                          if (input.isEmpty) return null;
                          final bpm = int.tryParse(input);
                          if (bpm == null || bpm < 40 || bpm > 300) {
                            return 'Use 40–300 BPM.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _presetId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Local preset',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('No preset assigned'),
                    ),
                    ...widget.presets.map(
                      (preset) => DropdownMenuItem(
                        value: preset.id,
                        child: Text(
                          preset.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _presetId = value ?? '';
                      _sceneId = '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: validSceneId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Scene (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Use preset default'),
                    ),
                    ...scenes.map(
                      (scene) => DropdownMenuItem(
                        value: scene.id,
                        child: Text(
                          scene.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: _presetId.isEmpty
                      ? null
                      : (value) => setState(() => _sceneId = value ?? ''),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Stage notes',
                    hintText: 'Arrangement, cues, transitions...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.song == null ? 'Save song' : 'Save changes'),
        ),
      ],
    );
  }
}

class _EmptyGigState extends StatelessWidget {
  const _EmptyGigState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.queue_music,
              size: 46,
              color: Color(0xFFFF987B),
            ),
            const SizedBox(height: 14),
            const Text(
              'No setlists yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create a setlist for your next rehearsal or service.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9AA4B2)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('create-setlist-empty'),
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create setlist'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySongState extends StatelessWidget {
  const _EmptySongState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.music_note,
              size: 40,
              color: Color(0xFFFF987B),
            ),
            const SizedBox(height: 10),
            const Text(
              'This setlist is empty',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add songs, set keys and tempos, then attach a local rig.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add first song'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF171C23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF303844)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.8,
          color: Color(0xFFADB6C2),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SimulationPill extends StatelessWidget {
  const _SimulationPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF202B25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF385844)),
      ),
      child: const Text(
        'LOCAL',
        style: TextStyle(
          color: Color(0xFF9BDBAC),
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF211B18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF5B3B30)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFFFA083), size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gig View is a local performance organizer. Recalling a song loads a RigCanvas preset or scene into the local workspace only; the KPT Pro is not being controlled.',
              style: TextStyle(
                color: Color(0xFFE3B8A9),
                height: 1.4,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF311E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF75403A)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFFFB3A6), fontSize: 12),
      ),
    );
  }
}
