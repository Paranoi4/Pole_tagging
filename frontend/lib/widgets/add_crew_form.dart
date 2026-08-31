// 📁 lib/widgets/add_crew_form.dart
//
// Rendered directly under the "Crew" tab on the home dashboard — not a
// dialog/modal. The parent (HomeScreen) is responsible for the surrounding
// card/container; this widget is just the form's contents.
//
// The City/Area field is a search-only autocomplete: it queries
// ApiService.searchCities(duId, query) as the admin types (debounced) and
// only lets them pick from what comes back. There is deliberately no path
// to create a brand-new city from this form — if nothing matches, the
// admin has to add the city first from wherever cities are managed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/models/city.dart';
import 'package:frontend/models/du.dart';
import 'package:frontend/providers/api_providers.dart';
import 'package:frontend/providers/du_provider.dart';
import 'package:frontend/services/api_exception.dart';

class AddCrewForm extends ConsumerStatefulWidget {
  /// Called after a successful "Add crew" (not "+ Add another"). The parent
  /// typically uses this to switch back to the Batches & pool tab.
  final VoidCallback? onDone;

  /// Called when Cancel is pressed. The parent typically uses this to
  /// switch back to the Batches & pool tab without saving.
  final VoidCallback? onCancel;

  const AddCrewForm({super.key, this.onDone, this.onCancel});

  @override
  ConsumerState<AddCrewForm> createState() => _AddCrewFormState();
}

class _AddCrewFormState extends ConsumerState<AddCrewForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();

  DU? _selectedDu;
  City? _selectedCity;

  bool _searchingCities = false;
  bool _submitting = false;
  String? _cityError;
  String? _formError;

  Timer? _debounce;
  List<City> _cityOptions = [];

  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame: calling loadDUs() synchronously
    // inside initState can hit Riverpod's "don't modify a provider while
    // the widget tree is building" guard, which silently leaves isLoading
    // stuck true and the spinner spinning forever.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final duState = ref.read(duProvider);
      if (duState.dus.isEmpty && !duState.isLoading) {
        ref.read(duProvider.notifier).loadDUs();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  /// Debounced so a search fires only after the admin pauses typing, not on
  /// every keystroke.
  void _onCityTextChanged(String text) {
    // Any manual edit invalidates a previous selection - they have to pick
    // again from the list, even if they retype the same name.
    if (_selectedCity != null && text != _selectedCity!.cityName) {
      setState(() => _selectedCity = null);
    }

    _debounce?.cancel();
    if (_selectedDu == null || text.trim().isEmpty) {
      setState(() => _cityOptions = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searchingCities = true);
      try {
        final results = await ref.read(apiProvider).searchCities(
              duId: _selectedDu!.duId,
              search: text,
            );
        if (!mounted) return;
        setState(() {
          _cityOptions = results;
          _searchingCities = false;
        });
      } on ApiException catch (_) {
        if (!mounted) return;
        setState(() {
          _cityOptions = [];
          _searchingCities = false;
        });
      }
    });
  }

  void _onDuChanged(DU? du) {
    setState(() {
      _selectedDu = du;
      // A city belongs to one DU, so switching DU clears whatever city was
      // chosen for the old one.
      _selectedCity = null;
      _cityController.clear();
      _cityOptions = [];
    });
  }

  void _selectCity(City city) {
    setState(() {
      _selectedCity = city;
      _cityController.text = city.cityName;
      _cityOptions = [];
      _cityError = null;
    });
  }

  Future<void> _submit({required bool addAnother}) async {
    setState(() => _cityError = null);

    if (!_formKey.currentState!.validate()) return;

    // The city field must resolve to an actual picked City, not just
    // matching text - typing a name and never selecting it is not enough.
    if (_selectedCity == null) {
      setState(() => _cityError = 'Pick a city from the list');
      return;
    }

    setState(() {
      _submitting = true;
      _formError = null;
    });

    try {
      final crewLabel = _nameController.text.trim();
      await ref.read(apiProvider).createCrew(
            crewLabel: crewLabel,
            cityId: _selectedCity!.cityId,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Crew "$crewLabel" added')),
      );

      // Clear the form either way — "Add crew" and "+ Add another" both
      // leave a blank form; they only differ in whether onDone fires
      // (the parent decides what "done" means, e.g. refreshing a list).
      setState(() {
        _nameController.clear();
        _cityController.clear();
        _selectedCity = null;
        _cityOptions = [];
        _submitting = false;
      });

      if (!addAnother) {
        widget.onDone?.call();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final duState = ref.watch(duProvider);
    final dus = duState.dus;
    final loadingDus = duState.isLoading;
    final duLoadError =
        (!loadingDus && dus.isEmpty) ? duState.errorMessage : null;

    // Almost every org only has one DU, so there's nothing to actually
    // choose. Auto-select it once it loads instead of making the admin
    // open a dropdown with a single item in it.
    if (dus.length == 1 && _selectedDu?.duId != dus.first.duId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onDuChanged(dus.first);
      });
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add crew',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (_formError != null) ...[
            Text(_formError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // NAME
              Expanded(
                flex: 4,
                child: _fieldWrapper(
                  label: 'NAME',
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // DU
              Expanded(
                flex: 2,
                child: _fieldWrapper(
                  label: 'DU',
                  error: duLoadError,
                  child: loadingDus
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      // Only worth a dropdown once there's an actual choice
                      // to make (2+ DUs). Otherwise show it as plain,
                      // non-interactive text — same border/sizing as the
                      // other fields, just nothing to tap.
                      : dus.length <= 1
                          ? TextFormField(
                              key: ValueKey(dus.isEmpty ? '' : dus.first.duId),
                              initialValue: dus.isEmpty ? '' : dus.first.duCode,
                              enabled: false,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            )
                          : DropdownButtonFormField<DU>(
                              value: _selectedDu,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: dus
                                  .map((du) => DropdownMenuItem(
                                        value: du,
                                        child: Text(du.duCode),
                                      ))
                                  .toList(),
                              onChanged: _onDuChanged,
                              validator: (value) =>
                                  value == null ? 'Required' : null,
                            ),
                ),
              ),
              if (duLoadError != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: TextButton(
                    onPressed: () => ref.read(duProvider.notifier).loadDUs(),
                    child: const Text('Retry'),
                  ),
                ),
              const SizedBox(width: 16),
              // CITY / AREA
              Expanded(
                flex: 4,
                child: _fieldWrapper(
                  label: 'CITY / AREA',
                  error: _cityError,
                  child: _buildCityField(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
                onPressed:
                    _submitting ? null : () => _submit(addAnother: false),
                child: _submitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add crew'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _submitting ? null : () => _submit(addAnother: true),
                child: const Text('+ Add another'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _submitting ? null : () => widget.onCancel?.call(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The disabled hint explains why typing does nothing yet, rather than
  /// leaving the admin guessing whether the field is broken.
  Widget _buildCityField() {
    final enabled = _selectedDu != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _cityController,
          enabled: enabled,
          onChanged: _onCityTextChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
            hintText: enabled ? 'e.g. Talisay' : 'Select a DU first',
            suffixIcon: _searchingCities
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          validator: (_) => _selectedCity == null ? 'Pick a city' : null,
        ),
        if (_cityOptions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _cityOptions.length,
              itemBuilder: (context, index) {
                final city = _cityOptions[index];
                return ListTile(
                  dense: true,
                  title: Text(city.cityName),
                  onTap: () => _selectCity(city),
                );
              },
            ),
          )
        else if (enabled &&
            !_searchingCities &&
            _cityController.text.trim().isNotEmpty &&
            _selectedCity == null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'No matching city in this DU',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _fieldWrapper({
    required String label,
    required Widget child,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        child,
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error, style: const TextStyle(fontSize: 12, color: Colors.red)),
        ],
      ],
    );
  }
}
