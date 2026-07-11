import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/pages/models_list/widgets/model_card.dart';
import 'package:lemonade_controller/services/settings_service.dart';
import 'package:lemonade_controller/utils/quantization_color.dart';

enum UserModelFilter { all, userOnly, nonUserOnly }

class ModelsPage extends ConsumerStatefulWidget {
  const ModelsPage({super.key});

  @override
  ConsumerState<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends ConsumerState<ModelsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  UserModelFilter _userFilter = UserModelFilter.all;
  String? _selectedQuantization;
  bool _favouritesExpanded = true;

  int get _activeFilterCount =>
      (_userFilter == UserModelFilter.all ? 0 : 1) +
      (_selectedQuantization == null ? 0 : 1);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static final _qLevelPattern = RegExp(r'Q(\d)');

  static int? _parseQLevel(String quantization) {
    final match = _qLevelPattern.firstMatch(quantization);
    if (match == null) return null;
    return int.parse(match.group(1)!);
  }

  List<String> _extractQuantizations(List<LemonadeModel> models) {
    final quants = models
        .where((m) => m.isUserModel)
        .map((m) => m.quantization)
        .where((q) => q != 'Unknown')
        .toSet()
        .toList();
    quants.sort();
    return quants;
  }

  List<LemonadeModel> _applyFilters(List<LemonadeModel> models) {
    var filtered = models;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (m) =>
                m.id.toLowerCase().contains(query) ||
                m.checkpoint.toLowerCase().contains(query) ||
                m.labels.any((l) => l.toLowerCase().contains(query)),
          )
          .toList();
    }

    switch (_userFilter) {
      case UserModelFilter.userOnly:
        filtered = filtered.where((m) => m.isUserModel).toList();
        break;
      case UserModelFilter.nonUserOnly:
        filtered = filtered.where((m) => !m.isUserModel).toList();
        break;
      case UserModelFilter.all:
        break;
    }

    if (_selectedQuantization != null) {
      filtered = filtered
          .where((m) => m.quantization == _selectedQuantization)
          .toList();
    }

    filtered.sort((a, b) {
      if (a.isUserModel == b.isUserModel) return a.id.compareTo(b.id);
      return a.isUserModel ? -1 : 1;
    });

    return filtered;
  }

  Future<void> _showMobileFilters(List<String> quantizations) async {
    final result = await Navigator.of(context).push<_ModelFilterSelection>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MobileModelFiltersPage(
          quantizations: quantizations,
          initialUserFilter: _userFilter,
          initialQuantization: _selectedQuantization,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _userFilter = result.userFilter;
      _selectedQuantization = result.quantization;
    });
  }

  Widget _buildInlineFilters(ThemeData theme, List<String> quantizations) {
    return Row(
      children: [
        FilterChip(
          label: const Text('All'),
          selected: _userFilter == UserModelFilter.all,
          onSelected: (_) => setState(() => _userFilter = UserModelFilter.all),
        ),
        const SizedBox(width: 8),
        FilterChip(
          avatar: _userFilter == UserModelFilter.userOnly
              ? null
              : Icon(
                  Icons.person_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
          label: const Text('Custom'),
          selected: _userFilter == UserModelFilter.userOnly,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) =>
              setState(() => _userFilter = UserModelFilter.userOnly),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Built-in'),
          selected: _userFilter == UserModelFilter.nonUserOnly,
          onSelected: (_) =>
              setState(() => _userFilter = UserModelFilter.nonUserOnly),
        ),
        if (quantizations.isNotEmpty) ...[
          const SizedBox(width: 16),
          Container(height: 24, width: 1, color: theme.dividerColor),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedQuantization,
                hint: const Text('Quantization'),
                isDense: true,
                isExpanded: true,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                borderRadius: BorderRadius.circular(12),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All quants'),
                  ),
                  ...quantizations.map((q) {
                    final level = _parseQLevel(q);
                    return DropdownMenuItem<String?>(
                      value: q,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: quantizationColor(level),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(q),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (value) =>
                    setState(() => _selectedQuantization = value),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModelsList(
    List<LemonadeModel> filtered,
    Set<String> favouriteIds,
    ThemeData theme,
  ) {
    final favouriteModels = filtered
        .where((m) => favouriteIds.contains(m.id))
        .toList();

    const listPadding = EdgeInsets.symmetric(horizontal: 16);

    return CustomScrollView(
      slivers: [
        if (favouriteModels.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text('Favourites', style: theme.textTheme.titleSmall),
                  const SizedBox(width: 4),
                  Text(
                    '(${favouriteModels.length})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: AnimatedRotation(
                      turns: _favouritesExpanded ? 0.0 : -0.25,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more, size: 20),
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(
                      () => _favouritesExpanded = !_favouritesExpanded,
                    ),
                    tooltip: _favouritesExpanded
                        ? 'Collapse favourites'
                        : 'Expand favourites',
                  ),
                ],
              ),
            ),
          ),
          if (_favouritesExpanded)
            SliverPadding(
              padding: listPadding,
              sliver: SliverList.builder(
                itemCount: favouriteModels.length,
                itemBuilder: (_, i) =>
                    _buildModelCard(favouriteModels[i], favouriteIds, ref),
              ),
            ),
          const SliverToBoxAdapter(child: Divider(indent: 16, endIndent: 16)),
        ],
        SliverPadding(
          padding: listPadding.copyWith(bottom: 16),
          sliver: SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) =>
                _buildModelCard(filtered[i], favouriteIds, ref),
          ),
        ),
      ],
    );
  }

  Widget _buildModelCard(
    LemonadeModel model,
    Set<String> favouriteIds,
    WidgetRef ref,
  ) {
    return ModelCard(
      model: model,
      isFavourite: favouriteIds.contains(model.id),
      onToggleFavourite: () =>
          ref.read(settingsProvider.notifier).toggleFavourite(model.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelsAsync = ref.watch(modelsProvider);
    final favouriteIds =
        ref.watch(settingsProvider).value?.favouriteModelIds ?? {};
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search models...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            modelsAsync.when(
              data: (models) {
                final quantizations = _extractQuantizations(models);
                final filtered = _applyFilters(models);
                return Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: compact
                            ? Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showMobileFilters(quantizations),
                                  icon: const Icon(Icons.filter_list),
                                  label: Text(
                                    _activeFilterCount == 0
                                        ? 'Filters'
                                        : 'Filters ($_activeFilterCount)',
                                  ),
                                ),
                              )
                            : _buildInlineFilters(theme, quantizations),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${filtered.length} of ${models.length} models',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (_searchQuery.isNotEmpty ||
                                _userFilter != UserModelFilter.all ||
                                _selectedQuantization != null)
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _userFilter = UserModelFilter.all;
                                  _selectedQuantization = null;
                                }),
                                icon: const Icon(Icons.clear_all, size: 18),
                                label: const Text('Clear filters'),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No models match your filters',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            : _buildModelsList(filtered, favouriteIds, theme),
                      ),
                    ],
                  ),
                );
              },
              error: (err, _) =>
                  Expanded(child: Center(child: Text('Error: $err'))),
              loading: () => const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModelFilterSelection {
  final UserModelFilter userFilter;
  final String? quantization;

  const _ModelFilterSelection({
    required this.userFilter,
    required this.quantization,
  });
}

class _MobileModelFiltersPage extends StatefulWidget {
  final List<String> quantizations;
  final UserModelFilter initialUserFilter;
  final String? initialQuantization;

  const _MobileModelFiltersPage({
    required this.quantizations,
    required this.initialUserFilter,
    required this.initialQuantization,
  });

  @override
  State<_MobileModelFiltersPage> createState() =>
      _MobileModelFiltersPageState();
}

class _MobileModelFiltersPageState extends State<_MobileModelFiltersPage> {
  late UserModelFilter _userFilter;
  String? _quantization;

  @override
  void initState() {
    super.initState();
    _userFilter = widget.initialUserFilter;
    _quantization = widget.initialQuantization;
  }

  void _clear() {
    setState(() {
      _userFilter = UserModelFilter.all;
      _quantization = null;
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      _ModelFilterSelection(
        userFilter: _userFilter,
        quantization: _quantization,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Filters')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Model source', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _userFilter == UserModelFilter.all,
                onSelected: (_) =>
                    setState(() => _userFilter = UserModelFilter.all),
              ),
              ChoiceChip(
                label: const Text('Custom'),
                selected: _userFilter == UserModelFilter.userOnly,
                onSelected: (_) =>
                    setState(() => _userFilter = UserModelFilter.userOnly),
              ),
              ChoiceChip(
                label: const Text('Built-in'),
                selected: _userFilter == UserModelFilter.nonUserOnly,
                onSelected: (_) =>
                    setState(() => _userFilter = UserModelFilter.nonUserOnly),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Quantization', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _QuantizationOption(
            label: 'All quants',
            selected: _quantization == null,
            onTap: () => setState(() => _quantization = null),
          ),
          for (final quantization in widget.quantizations)
            _QuantizationOption(
              label: quantization,
              level: _ModelsPageState._parseQLevel(quantization),
              selected: _quantization == quantization,
              onTap: () => setState(() => _quantization = quantization),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clear,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantizationOption extends StatelessWidget {
  final String label;
  final int? level;
  final bool selected;
  final VoidCallback onTap;

  const _QuantizationOption({
    required this.label,
    this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: level == null
          ? null
          : Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: quantizationColor(level),
                shape: BoxShape.circle,
              ),
            ),
      title: Text(label),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}
