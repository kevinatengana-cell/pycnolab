import 'package:flutter/material.dart';

import '../services/license_service.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({
    super.key,
    required this.licenseService,
    required this.onActivated,
    this.errorFromGate,
  });

  final LicenseService licenseService;
  final Future<void> Function() onActivated;
  final String? errorFromGate;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleActivation() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir une clé.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.licenseService.activateLicense(code);
      if (!mounted) return;
      if (!success) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Clé invalide ou déjà utilisée. '
              'Essai 24 h : PYCNO-TEST-24H. '
              'Essai 7 jours : PYCNO-TEST-7D.';
        });
        return;
      }

      await widget.onActivated();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur pendant l’activation : $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedError = _errorMessage ?? widget.errorFromGate;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo PycnoLab officiel
                      Image.asset(
                        'assets/images/LOGOS.jpg',
                        height: 110,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.key_rounded,
                            size: 48,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Activation PycnoLab',
                        style: TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Entrez une clé de licence valide pour déverrouiller l’ensemble des fonctionnalités.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5F6368),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _codeController,
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Clé de licence',
                          hintText: 'ex: PYCNO-TEST-7D',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.normal,
                          ),
                          errorText: displayedError,
                          errorMaxLines: 2,
                          prefixIcon: const Icon(
                            Icons.vpn_key_outlined,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                        onSubmitted: (_) => _handleActivation(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleActivation,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'ACTIVER LA LICENCE',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 14, color: Color(0xFF6B7280)),
                                SizedBox(width: 6),
                                Text(
                                  'Essai 24 h : PYCNO-TEST-24H',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Essai 7 jours : PYCNO-TEST-7D',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
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
          ),
        ),
      ),
    );
  }
}
