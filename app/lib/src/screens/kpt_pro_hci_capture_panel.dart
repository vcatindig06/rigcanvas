import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../device/btsnoop_capture.dart';
import '../device/kpt_pro_frame_analyzer.dart';

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
    final report = capture.toJson(
      sessionId: selectedId,
      includePayload: _includePayload,
    );
    if (_includePayload) {
      report['protocolEnvelopeAnalysis'] = KptProFrameAnalyzer.analyze(
        capture.eventsForSession(selectedId),
      ).toJson();
    }
    final json = const JsonEncoder.withIndent('  ').convert(report);
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
    final frameAnalysis = selectedSession == null
        ? null
        : KptProFrameAnalyzer.analyze(selectedEvents);
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
    final mtuRequests =
        selectedEvents.where((event) => event.opcode == 0x02).length;
    final hasCharacteristicMap = selectedSession != null &&
        (capture?.characteristicDiscoveryBySession[selectedSession.id]?.isNotEmpty ??
            false);
    final descriptorMap = selectedSession == null
        ? const <String, Object?>{}
        : capture!.descriptorDiscoveryBySession[selectedSession.id] ??
            const <String, Object?>{};
    final descriptorCount = descriptorMap.length;
    final eattBearers = selectedSession == null
        ? const <KptBleEnhancedAttBearer>[]
        : capture!.enhancedAttBearersBySession[selectedSession.id] ??
            const <KptBleEnhancedAttBearer>[];
    final eattEventCount = selectedEvents
        .where((event) => event.attBearerType == 'Enhanced ATT bearer')
        .length;

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
                      _CaptureMetric('$mtuRequests', 'MTU requests'),
                      _CaptureMetric('$descriptorCount', 'Descriptors'),
                      _CaptureMetric('${eattBearers.length}', 'EATT bearers'),
                      _CaptureMetric('$eattEventCount', 'EATT ATT events'),
                      _CaptureMetric(
                        '${selectedSession.startTimestampMicros} µs',
                        'Connection start offset',
                      ),
                      _CaptureMetric(
                        selectedSession.endTimestampMicros == null
                            ? 'Not seen'
                            : '${selectedSession.endTimestampMicros} µs',
                        'Connection end offset',
                      ),
                      _CaptureMetric('${selectedEvents.length}', 'Selected events'),
                    ],
                  ),
                if (selectedSession != null && mtuRequests > 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 9),
                    child: _CaptureNotice(
                      color: Color(0xFFFFC078),
                      text: 'Multiple ATT MTU Exchange Requests were captured for this connection. The client normally sends this request once per connection; verify the capture lifecycle before interpreting the MTU values.',
                    ),
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
                if (selectedSession != null && eattBearers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: _CaptureNotice(
                      color: const Color(0xFF8ED8B5),
                      text: 'Enhanced ATT channels were identified. Their ATT MTU comes from the negotiated L2CAP channel MTU; the report keeps each bearer and directional CID separate.',
                    ),
                  ),
                if (selectedSession != null &&
                    hasCharacteristicMap &&
                    descriptorCount == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 9),
                    child: _CaptureNotice(
                      color: Color(0xFFFFC078),
                      text: 'Characteristic declarations were found, but no descriptor map was captured. The analyzer needs successful Find Information Responses (ATT 0x05) to identify descriptor handles such as a possible notification configuration descriptor.',
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
                if (frameAnalysis != null) ...[
                  const SizedBox(height: 12),
                  _KptFrameAnalysisPanel(analysis: frameAnalysis),
                ],
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


class _KptFrameAnalysisPanel extends StatelessWidget {
  const _KptFrameAnalysisPanel({required this.analysis});

  final KptProFrameAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final recentFrames = analysis.frames.reversed.take(5).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF20262E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF46515E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OBSERVED 00 59 FRAME ENVELOPE',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Read-only parsing of captured ATT values. Command bytes are shown as raw identifiers, not interpreted operations.',
            style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 10, height: 1.35),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _CaptureMetric('${analysis.completeFrameCount}', 'Valid frames'),
              _CaptureMetric('${analysis.invalidFrameCount}', 'Invalid candidates'),
              _CaptureMetric('${analysis.incompleteStreamCount}', 'Incomplete streams'),
            ],
          ),
          if (analysis.commandSummaries.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Raw command counts',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            for (final summary in analysis.commandSummaries.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${summary.direction.label} · ${summary.attributeHandleLabel} · CMD ${summary.commandIdHex} × ${summary.count}',
                  style: const TextStyle(color: Color(0xFFD3DAE3), fontSize: 10),
                ),
              ),
          ],
          if (analysis.f1f2CandidateSummaries.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '8-byte CMD 0x23 field-slice candidates',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Phone-to-pedal traffic only; Tank-G-style f1/f2 comparison hypothesis. These values are not confirmed KPT Pro memory fields and do not prove a read operation.',
              style: TextStyle(color: Color(0xFFFFC078), fontSize: 10, height: 1.35),
            ),
            const SizedBox(height: 5),
            for (final summary in analysis.f1f2CandidateSummaries.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  'F1 ${summary.candidate.firstWordHex} · mem? ${summary.candidate.memoryIdCandidate} · addr? ${summary.candidate.addressCandidateHex}  |  F2 ${summary.candidate.secondWordHex} · len? ${summary.candidate.lengthCandidate} · space? ${summary.candidate.spaceCandidate}  × ${summary.count}',
                  style: const TextStyle(color: Color(0xFFD3DAE3), fontSize: 10),
                ),
              ),
          ],
          if (recentFrames.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Latest capture positions',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            for (final frame in recentFrames)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'ATT ${frame.firstFrameNumber}–${frame.lastFrameNumber} · ${frame.commandIdHex} · ${frame.bodyLength} B · ${frame.fragmentCount} value(s)',
                  style: const TextStyle(color: Color(0xFFD3DAE3), fontSize: 10),
                ),
              ),
          ],
          if (analysis.completeFrameCount == 0)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'No complete 00 59 frames were found in this selected connection. Confirm the selected connection and that its capture includes the vendor data stream.',
                style: TextStyle(color: Color(0xFFFFC078), fontSize: 10, height: 1.35),
              ),
            ),
          const SizedBox(height: 7),
          const Text(
            'This analysis does not identify parameter IDs, preset slots, acknowledgements, or command meanings. It never replays or sends frames.',
            style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 10, height: 1.35),
          ),
        ],
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
