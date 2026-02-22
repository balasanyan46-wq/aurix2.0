import 'package:flutter/material.dart';
import 'package:aurix_flutter/presentation/theme/design_theme.dart';

class DesignCreateReleaseScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const DesignCreateReleaseScreen({super.key, this.onBack});

  @override
  State<DesignCreateReleaseScreen> createState() => _DesignCreateReleaseScreenState();
}

class _DesignCreateReleaseScreenState extends State<DesignCreateReleaseScreen> {
  int _step = 0;

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
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text('Create Release', style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 24),
                    _StepIndicator(current: _step, total: 3, onStepTap: (s) => setState(() => _step = s)),
                    const SizedBox(height: 32),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      ),
                      child: _stepContent(context),
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

  Widget _stepContent(BuildContext context) {
    switch (_step) {
      case 0:
        return _Step1(onNext: () => setState(() => _step = 1));
      case 1:
        return _Step2(onNext: () => setState(() => _step = 2), onPrev: () => setState(() => _step = 0));
      case 2:
        return _Step3(onPrev: () => setState(() => _step = 1));
      default:
        return const SizedBox();
    }
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  final ValueChanged<int> onStepTap;

  const _StepIndicator({required this.current, required this.total, required this.onStepTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i == current;
        final isPast = i < current;
        return Expanded(
          child: GestureDetector(
            onTap: () => onStepTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: EdgeInsets.only(right: i < total - 1 ? 8 : 0),
              height: 6,
              decoration: BoxDecoration(
                color: isActive || isPast ? DesignTheme.primaryOrange : DesignTheme.surfaceCard,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Step1 extends StatelessWidget {
  final VoidCallback onNext;

  const _Step1({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      key: const ValueKey(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Basic info', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: 'Album or single name',
              filled: true,
              fillColor: DesignTheme.surfaceDark,
            ),
            style: const TextStyle(color: DesignTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'Release type',
              hintText: 'Single / EP / Album',
              filled: true,
              fillColor: DesignTheme.surfaceDark,
            ),
            style: const TextStyle(color: DesignTheme.textPrimary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onNext, child: const Text('Next')),
        ],
      ),
    );
  }
}

class _Step2 extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _Step2({required this.onNext, required this.onPrev});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      key: const ValueKey(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cover & Track', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          _DropZone(label: 'Cover art', icon: Icons.image),
          const SizedBox(height: 16),
          _DropZone(label: 'Track', icon: Icons.audiotrack),
          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: onPrev,
                style: OutlinedButton.styleFrom(foregroundColor: DesignTheme.textSecondary),
                child: const Text('Back'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(onPressed: onNext, child: const Text('Next')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step3 extends StatelessWidget {
  final VoidCallback onPrev;

  const _Step3({required this.onPrev});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      key: const ValueKey(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Review & Submit', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          Text('Your release is ready to submit.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: onPrev,
                style: OutlinedButton.styleFrom(foregroundColor: DesignTheme.textSecondary),
                child: const Text('Back'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(onPressed: () {}, child: const Text('Submit')),
            ],
          ),
        ],
      ),
    );
  }
}

class _DropZone extends StatefulWidget {
  final String label;
  final IconData icon;

  const _DropZone({required this.label, required this.icon});

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: DesignTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hover ? DesignTheme.primaryOrange.withValues(alpha: 0.6) : DesignTheme.borderSubtle,
            width: _hover ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(widget.icon, size: 48, color: DesignTheme.primaryOrange.withValues(alpha: _hover ? 1 : 0.7)),
            const SizedBox(height: 12),
            Text(widget.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DesignTheme.textSecondary)),
            const SizedBox(height: 4),
            Text('Drop file here or tap to browse', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({super.key, required this.child});

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
