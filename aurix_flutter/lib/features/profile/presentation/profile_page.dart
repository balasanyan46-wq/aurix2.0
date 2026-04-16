import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/core/api/api_error.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/app/auth/auth_store_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart'
    show currentProfileProvider, currentUserProvider;
import 'package:aurix_flutter/presentation/providers/subscription_provider.dart';
import 'package:aurix_flutter/features/profile/presentation/profile_gate.dart'
    show profileNeedsFillProvider;

/// Full profile form with AURIX theme. Optional [isMandatory] blocks back navigation.
/// [onBack] for DesignShell (no GoRouter); when null, uses context.pop().
/// [onViewIndex] for navigation to Aurix Index; when null, uses context.go('/index').
class ProfilePage extends ConsumerStatefulWidget {
  final bool isMandatory;
  final VoidCallback? onBack;
  final VoidCallback? onViewIndex;

  const ProfilePage(
      {super.key, this.isMandatory = false, this.onBack, this.onViewIndex});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _artistNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  bool _loading = false;
  bool _uploadingAvatar = false;
  bool _initialFillDone = false;
  String? _gender;

  static const _genders = [
    (value: null, label: 'Не выбрано'),
    (value: 'male', label: 'Мужской'),
    (value: 'female', label: 'Женский'),
    (value: 'other', label: 'Другое'),
  ];

  @override
  void dispose() {
    _artistNameController.dispose();
    _displayNameController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _fillFromProfile(ProfileModel? profile) {
    if (profile == null) return;
    final hasIncomingData = [
      profile.artistName,
      profile.displayName,
      profile.name,
      profile.city,
      profile.phone,
      profile.bio,
      profile.avatarUrl,
      profile.gender,
    ].any((v) => (v?.trim().isNotEmpty ?? false));
    final formLooksEmpty = [
      _artistNameController.text,
      _displayNameController.text,
      _nameController.text,
      _cityController.text,
      _phoneController.text,
      _bioController.text,
      _avatarUrlController.text,
      _gender,
    ].every((v) => (v?.trim().isEmpty ?? true));

    if (!_initialFillDone || (formLooksEmpty && hasIncomingData)) {
      _initialFillDone = true;
      _artistNameController.text = profile.artistName ?? '';
      _displayNameController.text = profile.displayName ?? '';
      _nameController.text = profile.name ?? '';
      _cityController.text = profile.city ?? '';
      _phoneController.text = profile.phone ?? '';
      _bioController.text = profile.bio ?? '';
      _avatarUrlController.text = profile.avatarUrl ?? '';
      _gender = profile.gender;
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Укажите имя или псевдоним';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[^\d+\s\-]'), '');
    if (cleaned.length < 7) return 'Минимум 7 цифр';
    return null;
  }

  String? _avatarContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  Future<void> _pickAvatar() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _showSnack('Не удалось прочитать файл. Попробуйте другое изображение.');
        return;
      }
      final safeName = file.name.replaceAll(' ', '_');
      final ext = (safeName.contains('.') ? safeName.split('.').last : 'jpg')
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      final res = await ApiClient.uploadFile(
        '/upload/cover',
        bytes,
        safeName,
        fieldName: 'file',
        contentType: _avatarContentType(ext),
      );
      final body = res.data is Map ? (res.data as Map).cast<String, dynamic>() : <String, dynamic>{};
      final publicUrl = (body['url'] ?? '').toString();
      _avatarUrlController.text = publicUrl;
      _showSnack('Фото профиля загружено');
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Ошибка загрузки фото: ${formatApiError(e)}');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) _showSnack('Войдите в аккаунт');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final current = await repo.getMyProfile();
      final profile = (current ??
              ProfileModel(
                userId: user.id,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                email: user.email,
              ))
          .copyWith(
        artistName: _artistNameController.text.trim().isEmpty
            ? null
            : _artistNameController.text.trim(),
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
        name: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        gender: _gender,
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        avatarUrl: _avatarUrlController.text.trim().isEmpty
            ? null
            : _avatarUrlController.text.trim(),
      );
      await repo.upsertMyProfile(profile);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(profileNeedsFillProvider);
      if (mounted) {
        _showSnack('Сохранено');
        setState(() => _loading = false);
        if (widget.isMandatory) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted) context.go('/home');
        }
      }
    } catch (e) {
      final msg = formatApiError(e);
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('Ошибка: $msg');
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(color: Colors.white)),
        backgroundColor: text.startsWith('Ошибка') ? AurixTokens.danger : AurixTokens.positive,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  double _completionProgress() {
    final checks = <bool>[
      _artistNameController.text.trim().isNotEmpty,
      _displayNameController.text.trim().isNotEmpty,
      _nameController.text.trim().isNotEmpty,
      _cityController.text.trim().isNotEmpty,
      _phoneController.text.trim().isNotEmpty,
      (_gender ?? '').isNotEmpty,
      _bioController.text.trim().isNotEmpty,
      _avatarUrlController.text.trim().isNotEmpty,
    ];
    final done = checks.where((v) => v).length;
    return done / checks.length;
  }

  String _planLabel(String plan) => switch (plan) {
        'empire' => 'Empire',
        'breakthrough' => 'Breakthrough',
        _ => 'Start',
      };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final releases = ref.watch(releasesProvider).valueOrNull ?? const [];
    final subscription = ref.watch(currentSubscriptionProvider);
    final liveReleases = releases
        .where((r) => r.status == 'approved' || r.status == 'live')
        .length;
    final draftReleases = releases.where((r) => r.status == 'draft').length;
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final padding = horizontalPadding(context);

    ref.listen(currentProfileProvider, (prev, next) {
      next.whenData((p) => _fillFromProfile(p));
    });

    // Fill form on first build if profile already loaded
    if (!_initialFillDone) {
      final existingProfile = profileAsync.valueOrNull;
      if (existingProfile != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fillFromProfile(existingProfile);
        });
      }
    }

    if (user == null) {
      return _buildCentered(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off, size: 64, color: AurixTokens.muted),
            const SizedBox(height: 16),
            Text('Войдите в аккаунт',
                style: TextStyle(color: AurixTokens.text, fontSize: 16)),
            const SizedBox(height: 24),
            AurixButton(text: 'Войти', onPressed: () => context.go('/login')),
          ],
        ),
      );
    }

    return PopScope(
      canPop: !widget.isMandatory,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: profileAsync.when(
              data: (profile) => Form(
                key: _formKey,
                child: AurixGlassCard(
                  padding: EdgeInsets.all(isDesktop ? 32 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (!widget.isMandatory)
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: AurixTokens.text),
                              onPressed: () {
                                if (widget.onBack != null) {
                                  widget.onBack!();
                                } else if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/home');
                                }
                              },
                            ),
                          Expanded(
                            child: Text(
                              widget.isMandatory
                                  ? 'Заполните профиль'
                                  : 'Профиль',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: AurixTokens.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.isMandatory)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          child: Text(
                            'Для продолжения укажите имя или псевдоним',
                            style: TextStyle(
                                color: AurixTokens.muted, fontSize: 14),
                          ),
                        ),
                      if (!widget.isMandatory) ...[
                        _ProfileSummaryBlock(
                          profile: profile,
                          fallbackEmail: user.email,
                          completion: _completionProgress(),
                          planLabel: _planLabel(profile?.plan ?? 'start'),
                          subscriptionStatus: subscription?.status ??
                              profile?.subscriptionStatus ??
                              'trial',
                          daysLeft: ref.watch(subscriptionDaysLeftProvider),
                          totalReleases: releases.length,
                          liveReleases: liveReleases,
                          draftReleases: draftReleases,
                        ),
                        const SizedBox(height: 18),
                      ],
                      _buildAvatarPanel(),
                      const SizedBox(height: 16),
                      const SizedBox(height: 20),
                      _buildField(
                        controller: _artistNameController,
                        label: 'Имя артиста / псевдоним',
                        hint: 'Как вас будут видеть слушатели',
                        validator: _validateName,
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: _displayNameController,
                        label: 'Отображаемое имя',
                        hint: 'Имя в интерфейсе',
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: _nameController,
                        label: 'Настоящее имя',
                        hint: '',
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: _cityController,
                        label: 'Город',
                        hint: '',
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: _phoneController,
                        label: 'Телефон',
                        hint: '+7 999 123-45-67',
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 16),
                      _buildGenderDropdown(),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: _bioController,
                        label: 'О себе',
                        hint: 'Краткое описание',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 52,
                        child: PremiumHoverLift(
                          enabled: isDesktop,
                          child: AurixButton(
                            text: _loading ? 'Сохранение…' : 'Сохранить',
                            onPressed: _loading ? null : _save,
                            icon: _loading ? null : Icons.check_rounded,
                          ),
                        ),
                      ),
                      if (!widget.isMandatory) ...[
                        const SizedBox(height: 16),
                        PremiumHoverLift(
                          enabled: isDesktop,
                          child: OutlinedButton.icon(
                            onPressed: widget.onViewIndex ??
                                () => context.go('/index'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AurixTokens.orange,
                              side: BorderSide(
                                  color: AurixTokens.orange
                                      .withValues(alpha: 0.5)),
                            ),
                            icon:
                                const Icon(Icons.leaderboard_rounded, size: 18),
                            label: const Text('Aurix Рейтинг'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        PremiumHoverLift(
                          enabled: isDesktop,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await ref.read(authStoreProvider).signOut();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AurixTokens.orange,
                              side: BorderSide(
                                  color: AurixTokens.orange
                                      .withValues(alpha: 0.5)),
                            ),
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Выйти'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              loading: () => _buildCentered(
                  child: const CircularProgressIndicator(
                      color: AurixTokens.orange)),
              error: (e, _) => _buildCentered(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ошибка: $e',
                        style: TextStyle(color: AurixTokens.muted),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    AurixButton(
                        text: 'Повторить',
                        onPressed: () =>
                            ref.invalidate(currentProfileProvider)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPanel() {
    final hasAvatar = _avatarUrlController.text.trim().isNotEmpty;
    final avatarUrl = _avatarUrlController.text.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.16)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AurixTokens.bg2,
            backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
            child: hasAvatar
                ? null
                : const Icon(Icons.person_rounded, color: AurixTokens.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Фото профиля',
                  style: TextStyle(
                      color: AurixTokens.text, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Загрузи изображение, чтобы профиль выглядел узнаваемо',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _uploadingAvatar ? null : _pickAvatar,
            icon: _uploadingAvatar
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AurixTokens.orange),
                  )
                : const Icon(Icons.upload_rounded, size: 16),
            label: const Text('Загрузить'),
          ),
        ],
      ),
    );
  }

  Widget _buildCentered({required Widget child}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: child,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String hint = '',
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool autofocus = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      autofocus: autofocus,
      validator: validator,
      style: const TextStyle(color: AurixTokens.text, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint.isNotEmpty ? hint : null,
        labelStyle: TextStyle(color: AurixTokens.muted),
        hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.7)),
        filled: true,
        fillColor: AurixTokens.glass(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AurixTokens.stroke()),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AurixTokens.stroke(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AurixTokens.orange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _gender,
      decoration: InputDecoration(
        labelText: 'Пол',
        labelStyle: const TextStyle(color: AurixTokens.muted),
        filled: true,
        fillColor: AurixTokens.glass(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AurixTokens.stroke()),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AurixTokens.stroke(0.15)),
        ),
      ),
      dropdownColor: AurixTokens.bg2,
      items: _genders
          .map((g) => DropdownMenuItem(
              value: g.value,
              child: Text(g.label,
                  style: const TextStyle(color: AurixTokens.text))))
          .toList(),
      onChanged: (v) => setState(() => _gender = v),
    );
  }
}

class _ProfileSummaryBlock extends StatelessWidget {
  const _ProfileSummaryBlock({
    required this.profile,
    required this.fallbackEmail,
    required this.completion,
    required this.planLabel,
    required this.subscriptionStatus,
    required this.daysLeft,
    required this.totalReleases,
    required this.liveReleases,
    required this.draftReleases,
  });

  final ProfileModel? profile;
  final String fallbackEmail;
  final double completion;
  final String planLabel;
  final String subscriptionStatus;
  final int? daysLeft;
  final int totalReleases;
  final int liveReleases;
  final int draftReleases;

  @override
  Widget build(BuildContext context) {
    final name = (profile?.artistName?.trim().isNotEmpty ?? false)
        ? profile!.artistName!.trim()
        : ((profile?.name?.trim().isNotEmpty ?? false)
            ? profile!.name!.trim()
            : 'Профиль артиста');
    final email =
        profile?.email.isNotEmpty == true ? profile!.email : fallbackEmail;
    final pct = (completion * 100).round();
    final subLabel = switch (subscriptionStatus) {
      'active' => 'Активна',
      'trial' => 'Trial',
      'past_due' => 'Просрочена',
      'expired' => 'Истекла',
      'canceled' => 'Отменена',
      _ => subscriptionStatus,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg2.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.stroke(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AurixTokens.orange.withValues(alpha: 0.15),
                child:
                    const Icon(Icons.person_rounded, color: AurixTokens.orange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AurixTokens.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AurixTokens.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AurixTokens.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AurixTokens.orange.withValues(alpha: 0.28)),
                ),
                child: Text(
                  planLabel,
                  style: const TextStyle(
                      color: AurixTokens.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Подписка: $subLabel${daysLeft == null ? '' : ' · осталось $daysLeft дн.'}',
                  style: const TextStyle(
                    color: AurixTokens.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () => context.go('/subscription'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AurixTokens.orange,
                  side: BorderSide(
                      color: AurixTokens.orange.withValues(alpha: 0.45)),
                ),
                child: const Text('Продлить'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Заполненность профиля: $pct%',
            style:
                const TextStyle(color: AurixTokens.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: completion.clamp(0, 1),
              minHeight: 7,
              backgroundColor: AurixTokens.glass(0.08),
              valueColor: const AlwaysStoppedAnimation(AurixTokens.orange),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(
                  child: _ProfileInfoChip(
                      icon: Icons.verified_user_rounded,
                      label: 'Данные аккаунта защищены')),
              SizedBox(width: 8),
              Expanded(
                  child: _ProfileInfoChip(
                      icon: Icons.insights_rounded,
                      label: 'Влияет на рекомендации AURIX')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ProfileMetricPill(
                  label: 'Релизы',
                  value: '$totalReleases',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileMetricPill(
                  label: 'Live',
                  value: '$liveReleases',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileMetricPill(
                  label: 'Черновики',
                  value: '$draftReleases',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoChip extends StatelessWidget {
  const _ProfileInfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AurixTokens.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AurixTokens.muted, fontSize: 11.5, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetricPill extends StatelessWidget {
  const _ProfileMetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
