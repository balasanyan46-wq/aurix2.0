import 'package:flutter/material.dart';
import 'package:aurix_flutter/presentation/theme/design_theme.dart';

enum ProfileRole { artist, admin }

class DesignProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const DesignProfileScreen({super.key, this.onBack});

  @override
  State<DesignProfileScreen> createState() => _DesignProfileScreenState();
}

class _DesignProfileScreenState extends State<DesignProfileScreen> with SingleTickerProviderStateMixin {
  ProfileRole _role = ProfileRole.artist;
  late AnimationController _switchController;

  @override
  void initState() {
    super.initState();
    _switchController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _switchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [DesignTheme.darkBg, Color(0xFF0F0D0C), DesignTheme.darkBg],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    if (widget.onBack != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back, color: DesignTheme.textPrimary),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Hero(
                      tag: 'profile_avatar',
                      child: _AvatarPlaceholder(),
                    ),
                    const SizedBox(height: 24),
                    Text('Artist Name', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text('artist@example.com', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 32),
                    _RoleSegmented(role: _role, onChanged: (r) => setState(() => _role = r)),
                    const SizedBox(height: 32),
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProfileRow(label: 'Display name', value: 'Artist Name'),
                          _ProfileRow(label: 'Phone', value: '+7 999 000-00-00'),
                          _ProfileRow(label: 'Artist name', value: 'Artist Name'),
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
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            DesignTheme.primaryOrange.withValues(alpha: 0.8),
            DesignTheme.deepOrange,
          ],
        ),
        boxShadow: [
          BoxShadow(color: DesignTheme.primaryOrange.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 0),
        ],
      ),
      child: const Icon(Icons.person, size: 60, color: Colors.white70),
    );
  }
}

class _RoleSegmented extends StatelessWidget {
  final ProfileRole role;
  final ValueChanged<ProfileRole> onChanged;

  const _RoleSegmented({required this.role, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: DesignTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DesignTheme.borderSubtle),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _SegmentTile(
                  label: 'Artist',
                  selected: role == ProfileRole.artist,
                  onTap: () => onChanged(ProfileRole.artist),
                ),
              ),
              Expanded(
                child: _SegmentTile(
                  label: 'Admin',
                  selected: role == ProfileRole.admin,
                  onTap: () => onChanged(ProfileRole.admin),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        gradient: selected ? LinearGradient(colors: [DesignTheme.primaryOrange, DesignTheme.deepOrange]) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(label, style: TextStyle(color: selected ? Colors.black : DesignTheme.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTheme.borderSubtle),
      ),
      child: child,
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
