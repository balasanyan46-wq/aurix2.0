import 'package:flutter/material.dart';
import 'package:aurix_flutter/presentation/theme/design_theme.dart';

class DesignLoginScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const DesignLoginScreen({super.key, this.onBack});

  @override
  State<DesignLoginScreen> createState() => _DesignLoginScreenState();
}

class _DesignLoginScreenState extends State<DesignLoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animController.dispose();
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
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        Text('Sign in', style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(height: 8),
                        Text('Enter your credentials', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 40),
                        _FloatingField(label: 'Email', hint: 'you@example.com'),
                        const SizedBox(height: 20),
                        _FloatingField(label: 'Password', hint: '••••••••', obscure: true),
                        const SizedBox(height: 32),
                        _GradientButton(label: 'Sign in'),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {},
                          child: Text('Forgot password?', style: TextStyle(color: DesignTheme.primaryOrange)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingField extends StatefulWidget {
  final String label;
  final String hint;
  final bool obscure;

  const _FloatingField({required this.label, required this.hint, this.obscure = false});

  @override
  State<_FloatingField> createState() => _FloatingFieldState();
}

class _FloatingFieldState extends State<_FloatingField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _focused ? DesignTheme.primaryOrange : DesignTheme.borderSubtle,
            width: _focused ? 2 : 1,
          ),
        ),
        child: TextField(
          obscureText: widget.obscure,
          style: const TextStyle(color: DesignTheme.textPrimary),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            filled: true,
            fillColor: DesignTheme.surfaceCard,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final String label;

  const _GradientButton({required this.label});

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: _hover ? [DesignTheme.accentAmber, DesignTheme.primaryOrange] : [DesignTheme.primaryOrange, DesignTheme.deepOrange],
          ),
          boxShadow: _hover ? [BoxShadow(color: DesignTheme.primaryOrange.withValues(alpha: 0.5), blurRadius: 20)] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text(widget.label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16))),
            ),
          ),
        ),
      ),
    );
  }
}
