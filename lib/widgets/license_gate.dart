import 'package:flutter/material.dart';

import '../screens/activation_screen.dart';
import '../services/license_service.dart';

/// Enveloppe l’application et empêche l’accès au contenu tant qu’aucune
/// licence valide n’est présente dans le stockage sécurisé local.
class LicenseGate extends StatefulWidget {
  const LicenseGate({
    super.key,
    required this.child,
    this.service,
  });

  final Widget child;
  final LicenseService? service;

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  late final LicenseService _licenseService;
  bool _loading = true;
  bool _licensed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _licenseService = widget.service ?? LicenseService();
    _loadLicenseState();
  }

  Future<void> _loadLicenseState() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final valid = await _licenseService.isLicenseValid();
      if (!mounted) return;
      setState(() {
        _licensed = valid;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _licensed = false;
        _loading = false;
        _error = 'Impossible de vérifier la licence : $error';
      });
    }
  }

  Future<void> _onActivated() async {
    await _loadLicenseState();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_licensed) {
      return ActivationScreen(
        licenseService: _licenseService,
        errorFromGate: _error,
        onActivated: _onActivated,
      );
    }

    return widget.child;
  }
}
