import 'dart:async';
import 'package:flutter/material.dart';
import 'package:furfeel_mobile/data/ble_provisioning_service.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';

class WifiProvisioningModal extends StatefulWidget {
  const WifiProvisioningModal({super.key, this.service});
  final BleProvisioningService? service;
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const WifiProvisioningModal(),
  );
  @override
  State<WifiProvisioningModal> createState() => _WifiProvisioningModalState();
}

class _WifiProvisioningModalState extends State<WifiProvisioningModal> {
  late final _service = widget.service ?? BleProvisioningService();
  final _ssid = TextEditingController(), _password = TextEditingController();
  List<BleDiscoveredCollar> _collars = [];
  List<WifiNetwork> _networks = [];
  BleDiscoveredCollar? _collar;
  WifiNetwork? _network;
  bool _busy = false,
      _ready = false,
      _scanCompleted = false,
      _manual = false,
      _hiddenPassword = true,
      _connected = false;
  String _message = '', _error = '';
  @override
  void initState() {
    super.initState();
    _find();
  }

  @override
  void dispose() {
    unawaited(_service.stopScan());
    unawaited(_service.disconnect());
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(String message, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = message;
      _error = '';
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        final message = e.toString();
        setState(
          () => _error =
              message.contains('GATT_CONNECTION_TIMEOUT') ||
                  e is TimeoutException
              ? 'Could not connect to the harness over Bluetooth. Wi-Fi details were not sent. Restart the harness, keep it near your phone, close other apps connected to it, then tap Find harnesses again.'
              : message,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = '';
        });
      }
    }
  }

  Future<void> _find() => _run('Finding nearby harnesses…', () async {
    final collars = await _service.findCollars();
    if (!mounted) return;
    setState(() {
      _collars = collars;
      _collar = null;
      _ready = false;
      _scanCompleted = false;
      _network = null;
      _networks = [];
    });
    if (collars.isEmpty) {
      throw const BleException(
        'No harness found. Turn it on and move closer, then retry.',
      );
    }
    if (collars.length == 1) await _select(collars.first);
  });
  Future<void> _select(BleDiscoveredCollar collar) async {
    setState(() {
      _collar = collar;
      _ready = false;
      _scanCompleted = false;
      _network = null;
      _networks = [];
      _password.clear();
      _message = 'Scanning Wi-Fi near the harness…';
    });
    await _service.connect(collar.device);
    if (!mounted) {
      await _service.disconnect();
      return;
    }
    setState(() => _ready = true);
    await _scan();
  }

  Future<void> _scan() async {
    setState(() => _scanCompleted = false);
    final networks = await _service.scanNetworks();
    if (!mounted) return;
    setState(() {
      _networks = networks;
      _scanCompleted = true;
      _network = null;
      _password.clear();
    });
  }

  Future<void> _submit() => _run('Connecting harness to Wi-Fi…', () async {
    final name = _manual ? _ssid.text : _network?.ssid ?? '';
    if (!_ready || _collar == null || name.isEmpty) {
      throw const BleException('Select a harness and Wi-Fi network first.');
    }
    final password = !_manual && _network?.secured == false
        ? ''
        : _password.text;
    if ((_manual || _network?.secured == true) &&
        password.isNotEmpty &&
        password.length < 8) {
      throw const BleException(
        'Use at least 8 characters for the Wi-Fi password.',
      );
    }
    if (!_manual && _network?.secured == true && password.isEmpty) {
      throw const BleException('Enter this network’s Wi-Fi password.');
    }
    await _service.sendCredentialsToCollar(
      device: _collar!.device,
      ssid: name,
      password: password,
    );
    if (mounted) setState(() => _connected = true);
    await _service.disconnect();
  });
  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return PopScope(
      canPop: !_busy,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Connect harness to Wi-Fi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: ff.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text('Choose a 2.4 GHz network near your harness.'),
              const SizedBox(height: 16),
              if (_connected) ...[
                Icon(Icons.check_circle_outline, color: ff.brand, size: 48),
                const Text(
                  'Harness connected to Wi-Fi',
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'Connection confirmed by the harness. Live readings appear when telemetry reaches FurFeel.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ] else ...[
                if (_collars.isNotEmpty)
                  DropdownButtonFormField<BleDiscoveredCollar>(
                    initialValue: _collar,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Harness'),
                    items: _collars
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (c) {
                            if (c != null) {
                              _run('Connecting to harness…', () => _select(c));
                            }
                          },
                  ),
                TextButton.icon(
                  onPressed: _busy ? null : _find,
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Find harnesses again'),
                ),
                if (_collar != null && _ready) ...[
                  Row(
                    children: [
                      const Expanded(child: Text('Available Wi-Fi networks')),
                      IconButton(
                        tooltip: 'Refresh networks',
                        onPressed: _busy
                            ? null
                            : () => _run('Scanning Wi-Fi…', () async {
                                await _service.connect(_collar!.device);
                                await _scan();
                              }),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  if (_networks.isEmpty && !_busy && _scanCompleted)
                    const Text(
                      'No visible networks found. Refresh or enter a hidden network.',
                    ),
                  for (final n in _networks)
                    ListTile(
                      selected: !_manual && _network == n,
                      leading: Icon(
                        !_manual && _network == n
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: _busy
                          ? null
                          : () => setState(() {
                              _network = n;
                              _manual = false;
                              _password.clear();
                            }),
                      title: Text(n.ssid),
                      subtitle: Text(
                        '${n.rssi} dBm · ${n.secured ? "Password required" : "Open network"}',
                      ),
                      trailing: Icon(n.secured ? Icons.wifi_lock : Icons.wifi),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enter a hidden network'),
                    value: _manual,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _manual = value;
                            _password.clear();
                          }),
                  ),
                  if (_manual)
                    TextField(
                      controller: _ssid,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Hidden Wi-Fi name (SSID)',
                      ),
                    ),
                  if (_manual || _network?.secured == true)
                    TextField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _hiddenPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: _manual
                            ? 'Password (leave empty for an open network)'
                            : 'Wi-Fi password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _hiddenPassword = !_hiddenPassword,
                          ),
                          icon: Icon(
                            _hiddenPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: const Text('Connect harness'),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(_message),
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
