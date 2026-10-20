import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/license_model.dart';
import '../services/license_service.dart';

class InformationsScreen extends StatefulWidget {
  const InformationsScreen({super.key});

  @override
  State<InformationsScreen> createState() => _InformationsScreenState();
}

class _InformationsScreenState extends State<InformationsScreen> {
  static const _contactEmail = 'kevinatengana@gmail.com';
  final LicenseService _licenseService = LicenseService();
  final TextEditingController _extensionCodeController =
      TextEditingController();

  LicenseModel? _license;
  bool _loading = true;
  bool _extensionEnCours = false;
  String? _erreurExtension;

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  @override
  void dispose() {
    _extensionCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadLicense() async {
    final license = await _licenseService.getSavedLicense();
    if (!mounted) return;
    setState(() {
      _license = license;
      _loading = false;
    });
  }

  String _licenseType(LicenseModel license) {
    final seconds = license.totalSeconds;
    if (seconds == const Duration(hours: 24).inSeconds) {
      return 'Test 24 heures';
    }
    if (seconds == const Duration(minutes: 30).inSeconds) {
      return 'Test 30 minutes';
    }
    if (seconds == const Duration(days: 14).inSeconds) {
      return 'Essai 14 jours';
    }
    if (seconds == const Duration(days: 30).inSeconds) {
      return 'Mensuelle';
    }
    if (seconds == const Duration(days: 90).inSeconds) {
      return 'Trimestrielle';
    }
    if (seconds == const Duration(days: 180).inSeconds) {
      return 'Semestrielle';
    }
    if (seconds == const Duration(days: 365).inSeconds) {
      return 'Annuelle';
    }
    return '${license.totalDays} jours';
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} à '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _remainingLabel(LicenseModel license) {
    if (license.isExpired) return 'Expirée';
    final remaining = license.remainingTime;
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    if (days > 0) return '$days jour(s), $hours h';
    if (hours > 0) return '$hours h $minutes min';
    return '$minutes minute(s)';
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(const ClipboardData(text: _contactEmail));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Adresse e-mail copiée dans le presse-papier.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _ajouterCle() async {
    final code = _extensionCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _erreurExtension = 'Saisissez une clé de licence.');
      return;
    }

    setState(() {
      _extensionEnCours = true;
      _erreurExtension = null;
    });
    try {
      final success = await _licenseService.activateLicense(code);
      if (!mounted) return;
      if (!success) {
        setState(() {
          _extensionEnCours = false;
          _erreurExtension = 'Clé invalide ou déjà utilisée.';
        });
        return;
      }

      _extensionCodeController.clear();
      await _loadLicense();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Licence prolongée avec succès.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _extensionEnCours = false;
        _erreurExtension = 'Impossible d’ajouter cette clé : $error';
      });
    } finally {
      if (mounted) setState(() => _extensionEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text(
          'Informations & Licence',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontSize: 18,
            color: Color(0xFF1B5E20),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF374151)),
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1B5E20),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle('LICENCE EN COURS'),
                      const SizedBox(height: 12),
                      _licenseCard(_license),
                      const SizedBox(height: 16),
                      _extensionCard(),
                      const SizedBox(height: 32),
                      _sectionTitle('SUPPORT & CONTACT'),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.email_outlined,
                              color: Color(0xFF1B5E20),
                              size: 22,
                            ),
                          ),
                          title: const SelectableText(
                            _contactEmail,
                            style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: const Text(
                            'Adresse e-mail du développeur',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                          trailing: OutlinedButton.icon(
                            onPressed: _copyEmail,
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Copier'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF374151),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _extensionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Prolonger la licence',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ajoutez une nouvelle clé pour prolonger la date d’expiration '
            'actuelle. Sa durée s’ajoute au temps restant.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _extensionCodeController,
            enabled: !_extensionEnCours,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Nouvelle clé de licence',
              hintText: 'Saisir la clé',
              errorText: _erreurExtension,
              prefixIcon: const Icon(Icons.vpn_key_outlined),
            ),
            onSubmitted: (_) => _ajouterCle(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _extensionEnCours ? null : _ajouterCle,
              icon: _extensionEnCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(
                _extensionEnCours ? 'Ajout en cours...' : 'Ajouter la durée',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _licenseCard(LicenseModel? license) {
    if (license == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF9CA3AF)),
            SizedBox(width: 12),
            Text(
              'Aucune licence enregistrée.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ],
        ),
      );
    }

    final active = license.isActive && !license.isExpired;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          // En-tête de la carte avec statut
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.key_rounded,
                        color: Color(0xFF1B5E20),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _licenseType(license),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Licence d\'utilisation PycnoLab',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? const Color(0xFFA5D6A7)
                          : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        active ? 'Active' : 'Expirée',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: active
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Corps des détails
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _detailRow('Clé de licence', license.key, isCode: true),
                _detailRow('Durée totale', '${license.totalDays} jour(s)'),
                _detailRow(
                    'Date d’activation', _formatDate(license.activationDate)),
                _detailRow(
                    'Date d’expiration', _formatDate(license.expirationDate)),
                _detailRow('Temps restant', _remainingLabel(license),
                    isHighlight: active),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {bool isCode = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: isHighlight
                    ? const Color(0xFF1B5E20)
                    : const Color(0xFF1A1A1A),
                fontWeight:
                    isHighlight || isCode ? FontWeight.bold : FontWeight.w500,
                fontFamily: isCode ? 'monospace' : null,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
