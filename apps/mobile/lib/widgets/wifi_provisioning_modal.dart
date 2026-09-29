import 'package:flutter/material.dart';
import 'package:furfeel_mobile/data/ble_provisioning_service.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';

enum ProvisioningStep {
  form,
  sending,
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
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  ProvisioningStep _step = ProvisioningStep.form;
  BleDiscoveredCollar? _selectedCollar;
  String _errorMessage = '';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _bleService.stopScan();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startScan() {
    _bleService.scanForCollars().listen((collars) {
      if (mounted) {
        setState(() {
          if (_selectedCollar == null && collars.isNotEmpty) {
            _selectedCollar = collars.first;
          }
        });
      }
    });
  }

  Future<void> _submit() async {
    final ssid = _ssidController.text.trim();
    final pass = _passwordController.text.trim();

    if (ssid.isEmpty) {
      setState(() => _errorMessage = 'Please enter your home Wi-Fi name (SSID).');
      return;
    }

    if (_selectedCollar == null) {
      setState(() => _errorMessage = 'No FurFeel collar detected. Make sure it is powered on.');
      return;
    }

    setState(() {
      _step = ProvisioningStep.sending;
      _errorMessage = '';
    });

    try {
      await _bleService.sendCredentialsToCollar(
        device: _selectedCollar!.device,
        ssid: ssid,
        password: pass,
      );

      if (!mounted) return;
      setState(() => _step = ProvisioningStep.success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = ProvisioningStep.error;
        _errorMessage = 'Failed to transmit Wi-Fi credentials: $e';
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
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
          Row(
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
                      'Direct Bluetooth Push',
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
          ),
          const SizedBox(height: 20),
          _buildBody(ff),
        ],
      ),
    );
  }

  Widget _buildBody(FurFeelPalette ff) {
    switch (_step) {
      case ProvisioningStep.form:
        return _buildFormView(ff);
      case ProvisioningStep.sending:
        return _buildSendingView(ff);
      case ProvisioningStep.success:
        return _buildSuccessView(ff);
      case ProvisioningStep.error:
        return _buildErrorView(ff);
    }
  }

  Widget _buildFormView(FurFeelPalette ff) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Collar selection indicator
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ff.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ff.hairline),
          ),
          child: Row(
            children: [
              Icon(Icons.bluetooth_connected, color: ff.brand, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _selectedCollar != null
                      ? 'Detected: ${_selectedCollar!.name}'
                      : 'Searching for collar nearby...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _selectedCollar != null ? ff.ink : ff.inkMuted,
                  ),
                ),
              ),
              if (_selectedCollar == null)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ssidController,
          decoration: InputDecoration(
            labelText: 'Home Wi-Fi Name (SSID)',
            hintText: 'e.g. MyHomeWiFi',
            prefixIcon: const Icon(Icons.wifi),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Wi-Fi Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
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
          onPressed: _submit,
          child: const Text('Send to Collar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildSendingView(FurFeelPalette ff) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: Column(
        children: [
          CircularProgressIndicator(color: ff.brand),
          const SizedBox(height: 20),
          Text(
            'Connecting to collar and transmitting credentials...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ff.ink),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(FurFeelPalette ff) {
    final ssid = _ssidController.text.trim();

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
              const Icon(Icons.check_circle, color: Colors.green, size: 50),
              const SizedBox(height: 12),
              const Text(
                'Wi-Fi Credentials Sent!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 6),
              Text(
                'The collar is now connecting to "$ssid" and will begin streaming telemetry.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
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
              const Icon(Icons.error_outline, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_errorMessage, style: const TextStyle(fontSize: 13, color: Colors.red)),
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
          onPressed: () => setState(() => _step = ProvisioningStep.form),
          child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
