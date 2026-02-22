import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/features/legal/data/legal_template_model.dart';
import 'package:aurix_flutter/features/legal/presentation/widgets/legal_template_card.dart';
import 'package:aurix_flutter/features/legal/presentation/widgets/legal_category_chips.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';

final _templatesQueryProvider = FutureProvider.family<List<LegalTemplateModel>, ({String? query, LegalCategory? category})>((ref, params) async {
  final repo = ref.watch(legalRepositoryProvider);
  return repo.fetchTemplates(query: params.query, category: params.category);
});

class LegalListPage extends ConsumerStatefulWidget {
  const LegalListPage({super.key});

  @override
  ConsumerState<LegalListPage> createState() => _LegalListPageState();
}

class _LegalListPageState extends ConsumerState<LegalListPage> {
  final _searchController = TextEditingController();
  LegalCategory _selectedCategory = LegalCategory.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final q = query.isEmpty ? null : query;
    final cat = _selectedCategory == LegalCategory.all ? null : _selectedCategory;
    final async = ref.watch(_templatesQueryProvider((query: q, category: cat)));

    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final padding = horizontalPadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Юридические документы',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AurixTokens.text,
                            fontSize: isDesktop ? null : 22,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Шаблоны договоров и соглашений для музыкальной индустрии',
                      style: TextStyle(color: AurixTokens.muted, fontSize: isDesktop ? 15 : 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AurixButton(
                text: 'История',
                icon: Icons.history_rounded,
                onPressed: () => context.go('/legal/history'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: AurixTokens.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Поиск по шаблонам...',
              hintStyle: TextStyle(color: AurixTokens.muted, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: AurixTokens.muted, size: 20),
              filled: true,
              fillColor: AurixTokens.glass(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AurixTokens.stroke()),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          LegalCategoryChips(
            selected: _selectedCategory,
            onSelected: (c) => setState(() => _selectedCategory = c),
          ),
          const SizedBox(height: 24),
          async.when(
            data: (templates) {
              if (templates.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Text(
                      'Ничего не найдено',
                      style: TextStyle(color: AurixTokens.muted, fontSize: 16),
                    ),
                  ),
                );
              }
              if (!isDesktop) {
                return Column(
                  children: templates
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LegalTemplateCard(
                              template: t,
                              compact: true,
                              onOpen: () => context.push('/legal/${t.id}'),
                            ),
                          ))
                      .toList(),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 900
                      ? 3
                      : (constraints.maxWidth > 600 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final t = templates[index];
                      return LegalTemplateCard(
                        template: t,
                        onOpen: () => context.push('/legal/${t.id}'),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: AurixTokens.orange))),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ошибка загрузки', style: TextStyle(color: AurixTokens.orange)),
                    const SizedBox(height: 8),
                    Text(e.toString(), style: TextStyle(color: AurixTokens.muted, fontSize: 12), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    AurixButton(text: 'Повторить', onPressed: () => ref.invalidate(_templatesQueryProvider((query: q, category: cat)))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
