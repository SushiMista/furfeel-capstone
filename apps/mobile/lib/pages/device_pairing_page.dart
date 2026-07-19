import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/battery.dart';
import '../util/friendly_time.dart';
import '../util/errors.dart';

/// Device Pairing & Setup (docs/04 module 6): pair a harness by its device
/// code, see connectivity + last sync, and unpair. (QR scanning is a natural
/// follow-up; code entry covers the flow without a camera dependency.)
class DevicePairingPage extends StatefulWidget {
  const DevicePairingPage({super.key, required this.repository, required this.dog});

  final FurFeelRepository repository;
  final Dog dog;

  @override
  State<DevicePairingPage> createState() => _DevicePairingPageState();
}

class _DevicePairingPageState extends State<DevicePairingPage> {
  final _code = TextEditingController();
  Device? _device;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final device = await widget.repository.fetchDeviceForDog(widget.dog.id);
      if (!mounted) return;
      setState(() {
        _device = device;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = loadErrorMessage(e, 'the harness status');
      });
    }
  }

  Future<void> _pair() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final device = await widget.repository.pairDevice(code, widget.dog.id);
      if (!mounted) return;
      setState(() {
        _device = device;
        _busy = false;
        _code.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paired with ${device.deviceCode}')),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err is FurFeelDataException
            ? err.message
            : actionErrorMessage(err, 'Pairing');
      });
    }
  }

  Future<void> _unpair() async {
    final device = _device;
    if (device == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair harness?'),
        content: Text(
          '${widget.dog.name}\'s readings will stop until a harness is paired again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.unpairDevice(device.id);
      if (!mounted) return;
      setState(() {
        _device = null;
        _busy = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err is FurFeelDataException
            ? err.message
            : actionErrorMessage(err, 'Unpairing');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Harness — ${widget.dog.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(FurFeelTokens.space4),
                children: [
                  if (_device != null)
                    _PairedCard(device: _device!, busy: _busy, onUnpair: _unpair)
                  else
                    _PairForm(
                      controller: _code,
                      busy: _busy,
                      onPair: _pair,
                      dogName: widget.dog.name,
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: FurFeelTokens.space4),
                    Container(
                      padding: const EdgeInsets.all(FurFeelTokens.space3),
                      decoration: BoxDecoration(
                        color: context.ff.statusHighBg,
                        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: context.ff.statusHighOwner),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PairedCard extends StatelessWidget {
  const _PairedCard({required this.device, required this.busy, required this.onUnpair});

  final Device device;
  final bool busy;
  final Future<void> Function() onUnpair;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final offline = device.status == 'offline';
    final statusColor = device.isOnline
        ? context.ff.statusCalmFg
        : offline
            ? context.ff.statusHighOwner
            : context.ff.inkMuted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  device.isOnline ? Icons.sensors : Icons.sensors_off,
                  color: statusColor,
                ),
                const SizedBox(width: FurFeelTokens.space3),
                Expanded(child: Text(device.deviceCode, style: textTheme.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FurFeelTokens.space3,
                    vertical: FurFeelTokens.space1,
                  ),
                  decoration: BoxDecoration(
                    color: device.isOnline
                        ? context.ff.statusCalmBg
                        : offline
                            ? context.ff.statusHighBg
                            : context.ff.surfaceAlt,
                    borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
                  ),
                  child: Text(
                    device.status,
                    style: TextStyle(
                      fontSize: FurFeelTokens.typeCaptionSize,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FurFeelTokens.space4),
            // QA item 14: battery health with a clear low-battery state.
            if (device.batteryPercent != null) ...[
              Row(
                children: [
                  Icon(
                    batteryIconFor(device.batteryPercent!),
                    size: 18,
                    color: batteryColorFor(context, device.batteryPercent!),
                  ),
                  const SizedBox(width: FurFeelTokens.space1),
                  Text(
                    'Battery ${device.batteryPercent}%'
                    '${device.isBatteryLow ? ' — time for a charge' : ''}',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: device.isBatteryLow
                          ? context.ff.statusHighOwner
                          : context.ff.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FurFeelTokens.space2),
            ],
            Text(
              device.lastSeenAt != null
                  ? 'Last sync ${friendlyTimestamp(device.lastSeenAt!)}'
                  : 'No sync yet — put the harness on and give it a minute.',
              style: textTheme.bodySmall,
            ),
            if (offline) ...[
              const SizedBox(height: FurFeelTokens.space2),
              Text(
                'The harness hasn\'t checked in for a while. Check the strap, '
                'battery, and that it\'s within Wi-Fi range.',
                style: textTheme.bodyMedium,
              ),
            ],
            if (device.firmwareVersion != null) ...[
              const SizedBox(height: FurFeelTokens.space2),
              Text('Firmware ${device.firmwareVersion}', style: textTheme.bodySmall),
            ],
            const SizedBox(height: FurFeelTokens.space5),
            OutlinedButton(
              onPressed: busy ? null : onUnpair,
              child: Text(busy ? 'Working…' : 'Unpair harness'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairForm extends StatelessWidget {
  const _PairForm({
    required this.controller,
    required this.busy,
    required this.onPair,
    required this.dogName,
  });

  final TextEditingController controller;
  final bool busy;
  final Future<void> Function() onPair;
  final String dogName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PAIR A HARNESS', style: textTheme.labelSmall),
            const SizedBox(height: FurFeelTokens.space3),
            Text(
              'Enter the code printed inside $dogName\'s FurFeel harness.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: FurFeelTokens.space4),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Device code',
                hintText: 'FURFEEL-DEV-0002',
              ),
              onSubmitted: (_) => onPair(),
            ),
            const SizedBox(height: FurFeelTokens.space4),
            ElevatedButton(
              onPressed: busy ? null : onPair,
              child: Text(busy ? 'Pairing…' : 'Pair harness'),
            ),
          ],
        ),
      ),
    );
  }
}
