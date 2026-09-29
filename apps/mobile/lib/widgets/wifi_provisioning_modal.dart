import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:furfeel_mobile/data/ble_provisioning_service.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';

enum ProvisioningStep {
  scanningCollars,
  connectingCollar,
  selectWifi,
  connectingWifi,
  success,
  error,
}

class WifiProvisioningModal extends StatefulWidget {
  const WifiProvisioningModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WifiProvisioningModal(),
    );
  }

  @override
  State<WifiProvisioningModal> createState() => _WifiProvisioningModalState();
}

class _WifiProvisioningModalState extends State<WifiProvisioningModal> {
  final _bleService = BleProvisioningService();
  final _passwordController = TextEditingController();

  ProvisioningStep _step = ProvisioningStep.scanningCollars;
  List<BleDiscoveredCollar> _discoveredCollars = [];
  BleDiscoveredCollar? _selectedCollar;
  List<String> _wifiNetworks = [];
  String? _selectedSsid;
  String _errorMessage = '';
  String _connectedIp = '';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _startCollarScan();
  }

  @override
  void dispose() {
    _bleService.disconnect();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCollarScan() {
    setState(() {
      _step = ProvisioningStep.scanningCollars;
      _discoveredCollars = [];
      _errorMessage = '';
    });

    _bleService.scanForCollars().listen(
      (collars) {
        if (mounted) {
          setState(() => _discoveredCollars = collars);
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _step = ProvisioningStep.error;
            _errorMessage = err.toString();
          });
        }
      },
    );
  }

  Future<void> _connectToCollar(BleDiscoveredCollar collar) async {
    setState(() {
      _selectedCollar = collar;
      _step = ProvisioningStep.connectingCollar;
      _errorMessage = '';
    });

    try {
      await _bleService.connectToCollar(collar.device);
      final networks = await _bleService.requestWifiScan();
      if (!mounted) return;

      setState(() {
        _wifiNetworks = networks;
        if (networks.isNotEmpty) {
          _selectedSsid = networks.first.split(' (').first;
        }
        _step = ProvisioningStep.selectWifi;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = ProvisioningStep.error;
        _errorMessage = 'Failed to connect to collar: $e';
      });
    }
  }

  Future<void> _submitWifiCredentials() async {
    final ssid = _selectedSsid?.trim() ?? '';
    final pass = _passwordController.text.trim();

    if (ssid.isEmpty) {
      setState(() => _errorMessage = 'Please select a Wi-Fi network.');
      return;
    }

    setState(() {
      _step = ProvisioningStep.connectingWifi;
      _errorMessage = '';
    });

    try {
      final result = await _bleService.sendWifiCredentials(ssid, pass);
      if (!mounted) return;

      if (result.startsWith('CONNECTED')) {
        final parts = result.split(';');
        setState(() {
          _connectedIp = parts.length > 1 ? parts[1] : '';
          _step = ProvisioningStep.success;
        });
      } else if (result == 'TIMEOUT') {
        setState(() {
          _step = ProvisioningStep.error;
          _errorMessage = 'Connection timed out. Check your password and ensure collar is near the router.';
        });
      } else {
        setState(() {
          _step = ProvisioningStep.error;
          _errorMessage = 'Collar failed to connect to "$ssid". Please verify your password.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = ProvisioningStep.error;
        _errorMessage = 'Error transmitting Wi-Fi credentials: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: ff.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: ff.hairline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildHeader(ff),
          const SizedBox(height: 20),
          _buildBody(ff),
        ],
      ),
    );
  }

  Widget _buildHeader(FurFeelPalette ff) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ff.brandSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.wifi_tethering, color: ff.brand, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect Collar to Wi-Fi',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ff.ink,
                ),
              ),
              Text(
                'Bluetooth Home Setup',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: ff.inkMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: ff.inkMuted),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildBody(FurFeelPalette ff) {
    switch (_step) {
      case ProvisioningStep.scanningCollars:
        return _buildScanningCollarsView(ff);
      case ProvisioningStep.connectingCollar:
        return _buildLoadingView(ff, 'Connecting to FurFeel Collar...');
      case ProvisioningStep.selectWifi:
        return _buildSelectWifiView(ff);
      case ProvisioningStep.connectingWifi:
        return _buildLoadingView(ff, 'Saving Wi-Fi to Collar & Connecting...');
      case ProvisioningStep.success:
        return _buildSuccessView(ff);
      case ProvisioningStep.error:
        return _buildErrorView(ff);
    }
  }

  Widget _buildScanningCollarsView(FurFeelPalette ff) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Make sure your FurFeel harness is powered on and nearby.',
          style: TextStyle(fontSize: 14, color: ff.inkMuted),
        ),
        const SizedBox(height: 16),
        if (_discoveredCollars.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36),
            alignment: Alignment.center,
            child: Column(
              children: [
                CircularProgressIndicator(color: ff.brand),
                const SizedBox(height: 16),
                Text(
                  'Searching for nearby collars via Bluetooth...',
                  style: TextStyle(fontSize: 13, color: ff.inkMuted),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _discoveredCollars.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final collar = _discoveredCollars[index];
              return ListTile(
                tileColor: ff.surfaceAlt,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: ff.hairline),
                ),
                leading: Icon(Icons.bluetooth, color: ff.brand),
                title: Text(collar.name, style: TextStyle(fontWeight: FontWeight.w600, color: ff.ink)),
                subtitle: Text('Signal: ${collar.rssi} dBm', style: TextStyle(fontSize: 12, color: ff.inkMuted)),
                trailing: Icon(Icons.arrow_forward_ios, size: 14, color: ff.inkMuted),
                onTap: () => _connectToCollar(collar),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSelectWifiView(FurFeelPalette ff) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Connected to ${_selectedCollar?.name ?? "Collar"}. Select your 2.4GHz home Wi-Fi network:',
          style: TextStyle(fontSize: 14, color: ff.inkMuted),
        ),
        const SizedBox(height: 16),
        if (_wifiNetworks.isEmpty)
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Wi-Fi Network Name (SSID)',
              prefixIcon: Icon(Icons.wifi),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => _selectedSsid = val,
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedSsid,
            decoration: const InputDecoration(
              labelText: 'Available Wi-Fi Networks',
              prefixIcon: Icon(Icons.wifi),
              border: OutlineInputBorder(),
            ),
            items: _wifiNetworks.map((net) {
              final ssidName = net.split(' (').first;
              return DropdownMenuItem<String>(
                value: ssidName,
                child: Text(net, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedSsid = val),
          ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Wi-Fi Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ff.brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _submitWifiCredentials,
          child: const Text('Save & Connect Collar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildLoadingView(FurFeelPalette ff, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          CircularProgressIndicator(color: ff.brand),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ff.ink),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(FurFeelPalette ff) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 54).animate().scale(),
              const SizedBox(height: 12),
              const Text(
                'Collar Connected to Wi-Fi!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 6),
              Text(
                'Collar IP: $_connectedIp\nLive telemetry is now streaming to your app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ff.brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildErrorView(FurFeelPalette ff) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMessage.isNotEmpty ? _errorMessage : 'An unexpected error occurred.',
                  style: const TextStyle(fontSize: 13, color: Colors.red),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ff.brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _startCollarScan,
          child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ],
    );
  }
}
