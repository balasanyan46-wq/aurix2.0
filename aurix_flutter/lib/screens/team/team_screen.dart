import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/data/models/team_member_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

final _teamProvider = FutureProvider.autoDispose<List<TeamMemberModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(teamRepositoryProvider).getMyTeam(user.id);
});

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(_teamProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInSlide(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Команда', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Участники, роли и сплиты', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => _showAddDialog(context, ref),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Добавить'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AurixTokens.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          teamAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
            error: (e, _) {
              final msg = e.toString();
              if (msg.contains('does not exist')) {
                return _buildMigrationHint(context);
              }
              return Center(child: Text('Ошибка: $msg', style: TextStyle(color: AurixTokens.muted)));
            },
            data: (members) {
              if (members.isEmpty) return _buildEmpty(context);

              final totalSplit = members.fold<double>(0, (s, m) => s + m.splitPercent);

              return Column(
                children: [
                  FadeInSlide(
                    delayMs: 50,
                    child: AurixGlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Участники', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 16),
                          ...members.map((m) => _MemberRow(
                                member: m,
                                onRemove: () => _removeMember(context, ref, m),
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeInSlide(
                    delayMs: 100,
                    child: AurixGlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Сплиты (доли)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 16),
                          ...members.where((m) => m.splitPercent > 0).map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(m.memberName, style: const TextStyle(color: AurixTokens.text, fontSize: 14))),
                                    Text('${m.splitPercent.toStringAsFixed(m.splitPercent.truncateToDouble() == m.splitPercent ? 0 : 1)}%',
                                        style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )),
                          const Divider(color: AurixTokens.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Итого', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600)),
                              Text(
                                '${totalSplit.toStringAsFixed(totalSplit.truncateToDouble() == totalSplit ? 0 : 1)}%',
                                style: TextStyle(
                                  color: totalSplit > 100 ? Colors.redAccent : Colors.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (totalSplit > 100)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Сумма сплитов превышает 100%!', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return FadeInSlide(
      delayMs: 50,
      child: AurixGlassCard(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 64, color: AurixTokens.muted),
              const SizedBox(height: 24),
              Text('Команда пуста', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(
                'Добавьте участников команды — продюсеров, менеджеров, звукорежиссёров — и распределите доли.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMigrationHint(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 48, color: AurixTokens.orange),
          const SizedBox(height: 16),
          Text('Таблица team_members не найдена', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Выполните SQL-миграцию 013_team_members.sql в Supabase SQL Editor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (ctx) => _AddMemberDialog(ref: ref));
  }

  Future<void> _removeMember(BuildContext context, WidgetRef ref, TeamMemberModel m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Удалить участника?', style: TextStyle(color: AurixTokens.text)),
        content: Text('${m.memberName} будет удалён из команды.', style: TextStyle(color: AurixTokens.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Удалить', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(teamRepositoryProvider).removeMember(m.id);
      ref.invalidate(_teamProvider);
    }
  }
}

class _MemberRow extends StatelessWidget {
  final TeamMemberModel member;
  final VoidCallback onRemove;

  const _MemberRow({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AurixTokens.orange.withValues(alpha: 0.2),
            child: Text(
              member.memberName.isNotEmpty ? member.memberName[0].toUpperCase() : '?',
              style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.memberName, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14)),
                Row(
                  children: [
                    Text(member.roleLabel, style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                    if (member.memberEmail != null && member.memberEmail!.isNotEmpty) ...[
                      Text('  •  ', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                      Flexible(child: Text(member.memberEmail!, style: TextStyle(color: AurixTokens.muted, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (member.splitPercent > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AurixTokens.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${member.splitPercent.toStringAsFixed(member.splitPercent.truncateToDouble() == member.splitPercent ? 0 : 1)}%',
                style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(icon: Icon(Icons.close, color: AurixTokens.muted, size: 18), onPressed: onRemove),
        ],
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  final WidgetRef ref;
  const _AddMemberDialog({required this.ref});

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _splitC = TextEditingController(text: '0');
  String _role = 'producer';
  bool _loading = false;
  String? _error;

  static const _roles = ['producer', 'manager', 'engineer', 'songwriter', 'designer', 'other'];
  static const _roleLabels = {
    'producer': 'Продюсер',
    'manager': 'Менеджер',
    'engineer': 'Звукорежиссёр',
    'songwriter': 'Автор',
    'designer': 'Дизайнер',
    'other': 'Другое',
  };

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _splitC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameC.text.trim().isEmpty) {
      setState(() => _error = 'Введите имя');
      return;
    }
    final split = double.tryParse(_splitC.text) ?? 0;
    if (split < 0 || split > 100) {
      setState(() => _error = 'Сплит: от 0 до 100');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final user = widget.ref.read(currentUserProvider);
      if (user == null) throw StateError('Не авторизован');
      await widget.ref.read(teamRepositoryProvider).addMember(
        ownerId: user.id,
        name: _nameC.text.trim(),
        email: _emailC.text.trim().isNotEmpty ? _emailC.text.trim() : null,
        role: _role,
        splitPercent: split,
      );
      widget.ref.invalidate(_teamProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AurixTokens.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Добавить участника', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AurixTokens.text)),
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              TextField(
                controller: _nameC,
                style: const TextStyle(color: AurixTokens.text),
                decoration: InputDecoration(
                  labelText: 'Имя *',
                  labelStyle: TextStyle(color: AurixTokens.muted),
                  filled: true,
                  fillColor: AurixTokens.bg2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailC,
                style: const TextStyle(color: AurixTokens.text),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: AurixTokens.muted),
                  filled: true,
                  fillColor: AurixTokens.bg2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                dropdownColor: AurixTokens.bg2,
                style: const TextStyle(color: AurixTokens.text),
                decoration: InputDecoration(
                  labelText: 'Роль',
                  labelStyle: TextStyle(color: AurixTokens.muted),
                  filled: true,
                  fillColor: AurixTokens.bg2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(_roleLabels[r]!))).toList(),
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _splitC,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AurixTokens.text),
                decoration: InputDecoration(
                  labelText: 'Сплит (%)',
                  labelStyle: TextStyle(color: AurixTokens.muted),
                  filled: true,
                  fillColor: AurixTokens.bg2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AurixTokens.orange,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Добавить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
