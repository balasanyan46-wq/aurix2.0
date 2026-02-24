import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';

import 'tool_result_screen.dart';

class BudgetFormScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  const BudgetFormScreen({super.key, required this.release});

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  bool _checkingSaved = true;
  bool _loading = false;

  final _budgetController = TextEditingController(text: '30000');
  String _currency = 'RUB';
  String _releaseType = 'single';
  String _goal = 'streams';
  String _region = 'RU';
  bool _hasDesigner = false;
  bool _hasVideo = false;
  bool _hasPR = false;
  bool _noTargetAds = false;
  bool _noBloggers = false;

  static const _currencies = [('RUB', '₽ Рубли'), ('AMD', '֏ Драмы'), ('USD', '\$ Доллары')];
  static const _releaseTypes = [('single', 'Сингл'), ('ep', 'EP'), ('album', 'Альбом')];
  static const _goals = [
    ('streams', 'Стримы'),
    ('playlisting', 'Плейлисты'),
    ('followers', 'Подписчики'),
    ('brand', 'Бренд'),
  ];
  static const _regions = [('RU', 'Россия'), ('AM', 'Армения'), ('GLOBAL', 'Глобально')];

  @override
  void initState() {
    super.initState();
    _releaseType = widget.release.releaseType;
    _checkForSaved();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _checkForSaved() async {
    try {
      final saved = await ref.read(toolServiceProvider).getSaved(widget.release.id, 'budget-plan');
      if (saved != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ToolResultScreen(
              release: widget.release,
              toolKey: 'budget-plan',
              data: saved.output,
              isDemo: saved.isDemo,
            ),
          ),
        );
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _checkingSaved = false);
  }

  Future<void> _generate() async {
    final budgetVal = int.tryParse(_budgetController.text.replaceAll(RegExp(r'[^\d]'), ''));
    if (budgetVal == null || budgetVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите корректный бюджет')),
      );
      return;
    }

    setState(() => _loading = true);

    final inputs = {
      'totalBudget': budgetVal,
      'currency': _currency,
      'releaseType': _releaseType,
      'goal': _goal,
      'region': _region,
      'team': {'hasDesigner': _hasDesigner, 'hasVideo': _hasVideo, 'hasPR': _hasPR},
      'constraints': {'noTargetAds': _noTargetAds, 'noBloggers': _noBloggers},
    };

    final result = await ref.read(toolServiceProvider).generate(widget.release.id, 'budget-plan', inputs);
    if (!mounted) return;

    if (result.ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ToolResultScreen(
            release: widget.release,
            toolKey: 'budget-plan',
            data: result.data,
            isDemo: result.isDemo,
          ),
        ),
      );
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Ошибка расчёта'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSaved) {
      return Scaffold(
        appBar: AppBar(title: const Text('Бюджет-менеджер')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Бюджет: ${widget.release.title}')),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Рассчитываем бюджет...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _sectionTitle('Общий бюджет'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '30000',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _currency,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: _currencies.map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _currency = v); },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle('Тип релиза'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _releaseTypes.map((r) => ChoiceChip(
                    label: Text(r.$2),
                    selected: _releaseType == r.$1,
                    onSelected: (v) { if (v) setState(() => _releaseType = r.$1); },
                  )).toList(),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Цель'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _goals.map((g) => ChoiceChip(
                    label: Text(g.$2),
                    selected: _goal == g.$1,
                    onSelected: (v) { if (v) setState(() => _goal = g.$1); },
                  )).toList(),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Регион'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _regions.map((r) => ChoiceChip(
                    label: Text(r.$2),
                    selected: _region == r.$1,
                    onSelected: (v) { if (v) setState(() => _region = r.$1); },
                  )).toList(),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Ваша команда'),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Есть дизайнер'),
                  value: _hasDesigner,
                  onChanged: (v) => setState(() => _hasDesigner = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('Есть видеомейкер'),
                  value: _hasVideo,
                  onChanged: (v) => setState(() => _hasVideo = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('Есть PR-менеджер'),
                  value: _hasPR,
                  onChanged: (v) => setState(() => _hasPR = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 20),
                _sectionTitle('Ограничения'),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Без таргетированной рекламы'),
                  value: _noTargetAds,
                  onChanged: (v) => setState(() => _noTargetAds = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('Без блогеров'),
                  value: _noBloggers,
                  onChanged: (v) => setState(() => _noBloggers = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.calculate_rounded),
                  label: const Text('Рассчитать бюджет'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      );
}
