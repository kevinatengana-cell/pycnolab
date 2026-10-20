import 'package:flutter/material.dart';

class Etape1MetaWidget extends StatefulWidget {
  const Etape1MetaWidget({
    super.key,
    required this.codeNorme,
    required this.titre,
    required this.categorie,
    required this.description,
    required this.onChanged,
  });

  final String codeNorme;
  final String titre;
  final String categorie;
  final String description;
  final ValueChanged<MetaProtocoleData> onChanged;

  @override
  State<Etape1MetaWidget> createState() => _Etape1MetaWidgetState();
}

class MetaProtocoleData {
  const MetaProtocoleData({required this.codeNorme, required this.titre, required this.categorie, required this.description});
  final String codeNorme;
  final String titre;
  final String categorie;
  final String description;
}

class _Etape1MetaWidgetState extends State<Etape1MetaWidget> {
  late final TextEditingController _codeController;
  late final TextEditingController _titreController;
  late final TextEditingController _categorieController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();
  static const suggestions = <String>['Traction', 'Compression', 'Flexion'];

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.codeNorme);
    _titreController = TextEditingController(text: widget.titre);
    _categorieController = TextEditingController(text: widget.categorie);
    _descriptionController = TextEditingController(text: widget.description);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _titreController.dispose();
    _categorieController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  MetaProtocoleData _data() => MetaProtocoleData(
        codeNorme: _codeController.text.trim(),
        titre: _titreController.text.trim(),
        categorie: _categorieController.text.trim(),
        description: _descriptionController.text.trim(),
      );

  void _emit() => widget.onChanged(_data());

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Métadonnées du protocole', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Définissez l’identité de la norme avant de construire ses calculs.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 28),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Code norme *', hintText: 'ISO 13934-1', border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
              validator: (value) => value == null || value.trim().isEmpty ? 'Le code norme est requis.' : null,
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titreController,
              decoration: const InputDecoration(labelText: 'Titre *', border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
              validator: (value) => value == null || value.trim().isEmpty ? 'Le titre est requis.' : null,
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: widget.categorie),
              optionsBuilder: (value) {
                final query = value.text.toLowerCase();
                return suggestions.where((item) => item.toLowerCase().contains(query));
              },
              onSelected: (value) {
                _categorieController.text = value;
                _emit();
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                controller.text = _categorieController.text;
                controller.selection = TextSelection.collapsed(offset: controller.text.length);
                controller.addListener(() {
                  if (_categorieController.text != controller.text) {
                    _categorieController.text = controller.text;
                    _emit();
                  }
                });
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Catégorie', hintText: 'Traction, Compression, Flexion ou autre', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true, border: OutlineInputBorder()),
              minLines: 4,
              maxLines: 8,
              onChanged: (_) => _emit(),
            ),
          ],
        ),
      ),
    );
  }

  bool validate() => _formKey.currentState?.validate() ?? false;
}
