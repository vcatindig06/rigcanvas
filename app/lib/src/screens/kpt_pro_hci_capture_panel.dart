import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../device/btsnoop_capture.dart';

class KptProHciCapturePanel extends StatefulWidget {
  const KptProHciCapturePanel({super.key});

  @override
  State<KptProHciCapturePanel> createState() => _KptProHciCapturePanelState();
}

class _KptProHciCapturePanelState extends State<KptProHciCapturePanel> {
  static const int _maximumFileBytes = 128 * 1024 * 1024;

  KptProHciCapture? _capture;
  int? _selectedSessionId;
  String? _filename;
  String? _error;
  bool _busy = false;
  bool _includePayload = false;

  Future<void> _importCapture() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final selected = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['log', 'snoop', 'btsnoop'],
      );
      if (selected == null) return;
      final path = selected.path;
      if (path == null) {
        throw const FormatException(
          'The selected file provider did not expose a local path. Copy btsnoop_hci.log to Downloads and select it again.',
        );
      }
      final file = File(path);
      final size = await file.length();
      if (size > _maximumFileBytes) {
        throw const FormatException(
          'The capture is larger than 128 MB. Use a shorter capture or trim the log before importing.',
        );
      }
      final bytes = await file.readAsBytes();
      final parsed = BtsnoopCaptureParser.parse(bytes);
      int? suggested = parsed.suggestedKptProSessionId();
      if (suggested == null && parsed.connectionSessions.length == 1) {
        suggested = parsed.connectionSessions.single.id;
      }
      if (!mounted) return;
      setState(() {
        _capture = parsed;
        _selectedSessionId = suggested;
        _filename = selected.name;
        _includePayload = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('FormatException: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyFilteredReport() async {
    final capture = _capture;
    final selectedId = _selectedSessionId;
    if (capture == null || selectedId == null) return;
    final json = const JsonEncoder.withIndent('  ').convert(
      capture.toJson(
        sessionId: selectedId,
        includePayload: _includePayload,
      ),
    );
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Filtered KPT Pro ATT report copied.')),
    );
  }

  String _sessionLabel(KptBleConnectionSession session) {
    final label = session.deviceName ?? 'Unknown BLE device';
    final suffix = session.looksLikeKptPro ? ' · KPT Pro name match' : '';
    return '$label · handle 0x${session.connectionHandle.toRadixString(16).padLeft(4, '0')} · ${session.maskedAddress}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final capture = _capture;
    final selectedSession = capture == null || _selectedSessionId == null
        ? null
        : capture.sessionById(_selectedSessionId!);
    final selectedEvents = selectedSession == null
        ? const <KptBleAttEvent>[]
        : capture!.eventsForSession(selectedSession.id);
    final writes = selectedEvents.where((event) => event.isWrite).length;
    final notifications =
        selectedEvents.where((event) => event.isNotification).length;
    final reads = selectedEvents
        .where((event) => const [
          0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
        ].contains(event.opcode))
        .length;
    final discovery = selectedEvents
        .where((event) => const [
          0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x10, 0x11,
        ].contains(event.opcode))
        .length;
    final attErrors =
        selectedEvents.where((event) => event.opcode == 0x01).length;
    final hasCharacteristicMap = selectedSession != null &&
        (capture?.characteristicDiscoveryBySession[selectedSession.id]?.isNotEmpty ??
            false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bluetooth_searching, color: Color(0xFFFFC078)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ANDROID BLUETOOTH TRACE ANALYZER',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Import an Android BTSnoop HCI log captured while M-EFCS is connected to the KPT Pro. RigCanvas parses the file locally, never replays packets, and does not send any device commands.',
              style: TextStyle(
                color: Color(0xFF9AA4B2),
                fontSize: 11,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('import-kpt-hci-log'),
              onPressed: _busy ? null : _importCapture,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open),
              label: Text(_busy ? 'Reading capture…' : 'Import HCI snoop log'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _CaptureNotice(
                color: const Color(0xFFFFA38F),
                text: _error!,
              ),
            ],
            if (capture != null) ...[
              const Divider(height: 22),
              Text(
                _filename ?? 'BTSnoop capture',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _CaptureMetric('${capture.packetCount}', 'HCI packets'),
                  _CaptureMetric('${capture.connectionSessions.length}', 'BLE connections'),
                  _CaptureMetric('${capture.attEvents.length}', 'ATT events'),
                  _CaptureMetric('${capture.malformedHciPacketCount}', 'Malformed'),
                ],
              ),
              const SizedBox(height: 12),
              if (capture.connectionSessions.isEmpty)
                const _CaptureNotice(
                  color: Color(0xFFFFC078),
                  text: 'No LE connection-complete event was found. Ensure the HCI log was started before M-EFCS connected to the pedal.',
                )
              else ...[
                DropdownButtonFormField<int>(
                  key: const ValueKey('hci-session-filter'),
                  initialValue: _selectedSessionId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Connection to analyze',
                    border: OutlineInputBorder(),
                  ),
                  items: capture.connectionSessions.map((session) {
                    return DropdownMenuItem<int>(
                      value: session.id,
                      child: Text(
                        _sessionLabel(session),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedSessionId = value),
                ),
                const SizedBox(height: 10),
                if (selectedSession != null)
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _CaptureMetric('$writes', 'ATT writes'),
                      _CaptureMetric('$notifications', 'Notifications'),
                      _CaptureMetric('$reads', 'Value reads'),
                      _CaptureMetric('$discovery', 'GATT discovery'),
                      _CaptureMetric('$attErrors', 'ATT errors'),
                      _CaptureMetric('${selectedEvents.length}', 'Selected events'),
                    ],
                  ),
                if (selectedSession != null &&
                    discovery > 0 &&
                    !hasCharacteristicMap)
                  const Padding(
                    padding: EdgeInsets.only(top: 9),
                    child: _CaptureNotice(
                      color: Color(0xFFFFC078),
                      text: 'GATT discovery traffic is present, but no successful service/characteristic declaration map was captured. Attribute handles remain unmapped; capture the connection from before discovery or use a fresh GATT discovery session.',
                    ),
                  ),
                if (selectedSession != null && !selectedSession.looksLikeKptPro)
                  const Padding(
                    padding: EdgeInsets.only(top: 9),
                    child: _CaptureNotice(
                      color: Color(0xFFFFC078),
                      text: 'The advertisement name did not identify this connection as KPT Pro. Check the selected handle and timing before exporting. Other devices are never silently combined.',
                    ),
                  ),
                if (selectedSession != null && selectedEvents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 9),
                    child: _CaptureNotice(
                      color: Color(0xFFFFC078),
                      text: 'No ATT packets were found for this connection. The selected log may begin after the connection was established or contain only Bluetooth audio traffic.',
                    ),
                  ),
                if (selectedSession != null) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    key: const ValueKey('include-att-payload-toggle'),
                    contentPadding: EdgeInsets.zero,
                    value: _includePayload,
                    onChanged: (value) =>
                        setState(() => _includePayload = value ?? false),
                    title: const Text(
                      'Include ATT payload bytes',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Required to decode command data. Payloads may include preset names, parameter values, or proprietary data.',
                      style: TextStyle(
                        color: Color(0xFF9AA4B2),
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 5),
                  FilledButton.icon(
                    key: const ValueKey('copy-filtered-hci-report'),
                    onPressed: selectedEvents.isEmpty ? null : _copyFilteredReport,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy selected connection report'),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              const Text(
                'The exported report masks the BLE peer address and excludes all other connections. Payload inclusion is off by default. The original capture remains on your phone unless you remove it.',
                style: TextStyle(
                  color: Color(0xFF9AA4B2),
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CaptureMetric extends StatelessWidget {
  const _CaptureMetric(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF20262E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF39424D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _CaptureNotice extends StatelessWidget {
  const _CaptureNotice({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF20262E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, height: 1.4),
      ),
    );
  }
}
