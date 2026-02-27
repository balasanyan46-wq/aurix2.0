import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  String _search = '';
  String _roleFilter = 'all';
  String _planFilter = 'all';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(allProfilesProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: AurixTokens.bg1,
          child: Column(
            children: [
              TextField(
                style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Поиск по имени или email...',
                  hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: AurixTokens.muted, size: 20),
                  filled: true,
                  fillColor: AurixTokens.bg2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AurixTokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AurixTokens.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('Роль', _roleFilter, ['all', 'artist', 'admin'], (v) => setState(() => _roleFilter = v)),
                    const SizedBox(width: 8),
                    _filterChip('План', _planFilter, ['all', 'start', 'breakthrough', 'empire'], (v) => setState(() => _planFilter = v)),
                    const SizedBox(width: 8),
                    _filterChip('Статус', _statusFilter, ['all', 'active', 'suspended'], (v) => setState(() => _statusFilter = v)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: profilesAsync.when(
            data: (profiles) {
              var filtered = profiles.where((p) {
                if (_search.isNotEmpty) {
                  final name = p.displayNameOrName.toLowerCase();
                  final email = p.email.toLowerCase();
                  if (!name.contains(_search) && !email.contains(_search)) return false;
                }
                if (_roleFilter != 'all' && p.role != _roleFilter) return false;
                if (_planFilter != 'all' && p.plan != _planFilter) return false;
                if (_statusFilter != 'all' && p.accountStatus != _statusFilter) return false;
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text('Нет пользователей', style: TextStyle(color: AurixTokens.muted)),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = filtered[i];
                  return _UserCard(
                    profile: p,
                    onAction: () => _showActions(context, p),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
            error: (e, _) => Center(child: Text('Ошибка: $e', style: TextStyle(color: AurixTokens.muted))),
          ),
        ),
      ],
    );
  }

  static String _chipLabel(String raw) {
    switch (raw) {
      case 'all': return 'Все';
      case 'start': return 'Старт';
      case 'breakthrough': return 'Прорыв';
      case 'empire': return 'Империя';
      default: return raw;
    }
  }

  Widget _filterChip(String label, String current, List<String> options, ValueChanged<String> onSelect) {
    return PopupMenuButton<String>(
      onSelected: onSelect,
      color: AurixTokens.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (_) => options.map((o) => PopupMenuItem(
        value: o,
        child: Text(
          _chipLabel(o),
          style: TextStyle(
            color: current == o ? AurixTokens.orange : AurixTokens.text,
            fontSize: 13,
          ),
        ),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: current != 'all' ? AurixTokens.orange.withValues(alpha: 0.15) : AurixTokens.bg2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: current != 'all' ? AurixTokens.orange.withValues(alpha: 0.4) : AurixTokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ${_chipLabel(current)}',
              style: TextStyle(
                color: current != 'all' ? AurixTokens.orange : AurixTokens.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: AurixTokens.muted),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context, ProfileModel profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AurixTokens.bg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _UserActionsSheet(
        profile: profile,
        onDone: () {
          ref.invalidate(allProfilesProvider);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.profile, required this.onAction});
  final ProfileModel profile;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAction,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AurixTokens.bg1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AurixTokens.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AurixTokens.bg2,
              child: Text(
                (profile.displayNameOrName).isNotEmpty
                    ? profile.displayNameOrName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayNameOrName,
                    style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 12, color: AurixTokens.muted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          profile.email.isNotEmpty ? profile.email : '—',
                          style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 12, color: AurixTokens.muted),
                        const SizedBox(width: 4),
                        Text(
                          profile.phone!,
                          style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _badge(profile.role, profile.role == 'admin' ? AurixTokens.orange : AurixTokens.muted),
            const SizedBox(width: 6),
            _badge(_planBadgeLabel(profile.plan), AurixTokens.positive),
            const SizedBox(width: 6),
            if (profile.accountStatus == 'suspended')
              _badge('blocked', Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd.MM.yy').format(profile.createdAt),
              style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  static String _planBadgeLabel(String plan) {
    switch (plan) {
      case 'start': return 'Старт';
      case 'breakthrough': return 'Прорыв';
      case 'empire': return 'Империя';
      default: return plan;
    }
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }
}

class _UserActionsSheet extends ConsumerStatefulWidget {
  const _UserActionsSheet({required this.profile, required this.onDone});
  final ProfileModel profile;
  final VoidCallback onDone;

  @override
  ConsumerState<_UserActionsSheet> createState() => _UserActionsSheetState();
}

class _UserActionsSheetState extends ConsumerState<_UserActionsSheet> {
  bool _loading = false;
  int _releasesCount = 0;
  double _totalRevenue = 0;
  int _totalStreams = 0;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      final releases = ref.read(allReleasesAdminProvider).valueOrNull ?? [];
      final rows = ref.read(allReportRowsProvider).valueOrNull ?? [];
      final uid = widget.profile.userId;
      if (mounted) {
        setState(() {
          _releasesCount = releases.where((r) => r.ownerId == uid).length;
          final userRows = rows.where((r) => r.userId == uid);
          _totalRevenue = userRows.fold<double>(0, (s, r) => s + r.revenue);
          _totalStreams = userRows.fold<int>(0, (s, r) => s + r.streams);
          _statsLoaded = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _changeRole(String newRole) async {
    setState(() => _loading = true);
    try {
      await ref.read(profileRepositoryProvider).updateRole(widget.profile.userId, newRole);
      final adminId = ref.read(currentUserProvider)?.id;
      if (adminId != null) {
        await ref.read(adminLogRepositoryProvider).log(
          adminId: adminId,
          action: 'user_role_changed',
          targetType: 'profile',
          targetId: widget.profile.userId,
          details: {'old': widget.profile.role, 'new': newRole},
        );
      }
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
      setState(() => _loading = false);
    }
  }

  String _planLabel(String plan) {
    switch (plan) {
      case 'start': return 'Старт';
      case 'breakthrough': return 'Прорыв';
      case 'empire': return 'Империя';
      default: return 'Старт';
    }
  }

  Future<void> _changePlan(String newPlan) async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(billingServiceProvider).adminAssignPlan(
            userId: widget.profile.userId,
            plan: newPlan,
            billingPeriod: 'monthly',
          );
      if (!res.ok) {
        throw Exception(res.error ?? 'Не удалось назначить тариф');
      }
      final adminId = ref.read(currentUserProvider)?.id;
      if (adminId != null) {
        await ref.read(adminLogRepositoryProvider).log(
          adminId: adminId,
          action: 'user_plan_changed',
          targetType: 'profile',
          targetId: widget.profile.userId,
          details: {'old': widget.profile.plan, 'new': newPlan},
        );
      }
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleSuspend() async {
    final newStatus = widget.profile.accountStatus == 'active' ? 'suspended' : 'active';
    setState(() => _loading = true);
    try {
      await ref.read(profileRepositoryProvider).updateAccountStatus(widget.profile.userId, newStatus);
      final adminId = ref.read(currentUserProvider)?.id;
      if (adminId != null) {
        await ref.read(adminLogRepositoryProvider).log(
          adminId: adminId,
          action: newStatus == 'suspended' ? 'user_suspended' : 'user_activated',
          targetType: 'profile',
          targetId: widget.profile.userId,
          details: {'old': widget.profile.accountStatus, 'new': newStatus},
        );
      }
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AurixTokens.orange.withValues(alpha: 0.2),
                child: Text(
                  p.displayNameOrName.isNotEmpty ? p.displayNameOrName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w800, fontSize: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.displayNameOrName, style: const TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
                    if (p.artistName != null && p.artistName!.isNotEmpty && p.artistName != p.displayNameOrName)
                      Text('Псевдоним: ${p.artistName}', style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AurixTokens.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(_planLabel(p.plan).toUpperCase(), style: TextStyle(color: AurixTokens.orange, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contact info
          _contactRow(Icons.email_outlined, p.email.isNotEmpty ? p.email : '—'),
          if (p.phone != null && p.phone!.isNotEmpty) _contactRow(Icons.phone_outlined, p.phone!),
          if (p.city != null && p.city!.isNotEmpty) _contactRow(Icons.location_on_outlined, p.city!),
          if (p.name != null && p.name!.isNotEmpty) _contactRow(Icons.badge_outlined, 'ФИО: ${p.name}'),
          if (p.gender != null && p.gender!.isNotEmpty)
            _contactRow(Icons.person_outline, 'Пол: ${p.gender == 'male' ? 'Мужской' : p.gender == 'female' ? 'Женский' : p.gender!}'),
          if (p.bio != null && p.bio!.isNotEmpty) _contactRow(Icons.info_outline, p.bio!),
          _contactRow(Icons.calendar_today, 'Регистрация: ${p.createdAt.day}.${p.createdAt.month}.${p.createdAt.year}'),

          if (_statsLoaded) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _miniStat('Релизы', '$_releasesCount', Icons.album_rounded),
                const SizedBox(width: 10),
                _miniStat('Доход', '\$${_totalRevenue.toStringAsFixed(2)}', Icons.payments_rounded),
                const SizedBox(width: 10),
                _miniStat('Стримы', _totalStreams > 1000 ? '${(_totalStreams / 1000).toStringAsFixed(1)}K' : '$_totalStreams', Icons.headphones_rounded),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: AurixTokens.orange))
          else ...[
            _actionRow('Роль', p.role, [
              if (p.role != 'admin') _actionBtn('Сделать админом', () => _changeRole('admin')),
              if (p.role != 'artist') _actionBtn('Сделать артистом', () => _changeRole('artist')),
            ]),
            const SizedBox(height: 12),
            _actionRow('План', _planLabel(p.plan), [
              if (p.plan != 'start') _actionBtn('Старт', () => _changePlan('start')),
              if (p.plan != 'breakthrough') _actionBtn('Прорыв', () => _changePlan('breakthrough')),
              if (p.plan != 'empire') _actionBtn('Империя', () => _changePlan('empire')),
            ]),
            const SizedBox(height: 12),
            _actionRow(
              'Статус',
              p.accountStatus,
              [
                _actionBtn(
                  p.accountStatus == 'active' ? 'Заблокировать' : 'Разблокировать',
                  _toggleSuspend,
                  color: p.accountStatus == 'active' ? Colors.redAccent : AurixTokens.positive,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AurixTokens.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: AurixTokens.text, fontSize: 12))),
      ],
    ),
  );

  Widget _miniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AurixTokens.bg2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AurixTokens.orange),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _actionRow(String label, String current, List<Widget> buttons) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AurixTokens.bg2,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(current.toUpperCase(), style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 12),
        ...buttons,
      ],
    );
  }

  Widget _actionBtn(String label, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color ?? AurixTokens.orange,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}
