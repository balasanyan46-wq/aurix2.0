import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../data/dnk_models.dart';
import '../data/dnk_service.dart';
import '../data/questions_bank.dart';

class DnkInterviewScreen extends StatefulWidget {
  const DnkInterviewScreen({super.key});

  @override
  State<DnkInterviewScreen> createState() => _DnkInterviewScreenState();
}

class _DnkInterviewScreenState extends State<DnkInterviewScreen> {
  final _service = DnkService();
  final List<DnkQuestion> _queue = [];
  int _currentIndex = 0;
  bool _submitting = false;
  bool _finishing = false;
  String _finishStatus = '';

  // Per-question state
  int _scaleValue = 3;
  String? _choiceKey;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _queue.addAll(
      dnkCoreQuestions
          .where((q) => dnkMandatoryCoreQuestionIds.contains(q.id))
          .toList(),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  DnkQuestion get _q => _queue[_currentIndex];
  int get _total => _queue.length;
  double get _progress => (_currentIndex + 1) / _total;

  Future<void> _submit() async {
    if (_submitting || _finishing) return;

    final answerType = _q.type;
    Map<String, dynamic> answerJson;

    if (answerType == 'scale') {
      answerJson = {'value': _scaleValue};
    } else if (answerType == 'forced_choice' || answerType == 'sjt') {
      if (_choiceKey == null) return;
      answerJson = {'key': _choiceKey};
    } else {
      final text = _textController.text.trim();
      if (text.isEmpty) return;
      answerJson = {'text': text};
    }

    // Store answer locally
    _service.addAnswer(
      questionId: _q.id,
      answerType: answerType,
      answerJson: answerJson,
    );

    if (_currentIndex + 1 < _queue.length) {
      setState(() {
        _currentIndex++;
        _resetInputs();
      });
    } else {
      await _finishInterview();
    }
  }

  void _resetInputs() {
    _scaleValue = 3;
    _choiceKey = null;
    _textController.clear();
  }

  // ── Finish flow ────────────────────────────────────────────
  Future<void> _finishInterview() async {
    setState(() {
      _finishing = true;
      _finishStatus = 'Отправляем ответы…';
    });

    _startProgressTimer();

    DnkResult? result;
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        result = await _service.finish();
        break;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[DNK] finish attempt ${attempt + 1} failed: $e');
        }
        if (attempt == 0 && mounted) {
          setState(() => _finishStatus = 'AI занят, пробуем ещё раз…');
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) setState(() => _finishStatus = 'Повторная генерация…');
        }
      }
    }

    _progressTimer?.cancel();

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Генерация не удалась. Попробуйте ещё раз.')),
      );
      setState(() => _finishing = false);
    }
  }

  Timer? _progressTimer;
  int _progressStep = 0;

  void _startProgressTimer() {
    _progressStep = 0;
    _progressTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _progressStep++;
      switch (_progressStep) {
        case 1:
          setState(() => _finishStatus = 'AI анализирует ваши ответы…');
          break;
        case 2:
          setState(() => _finishStatus = 'Извлекаем паттерны…');
          break;
        case 3:
          setState(() => _finishStatus = 'Строим профиль…');
          break;
        case 4:
          setState(() => _finishStatus = 'Формируем рекомендации…');
          break;
        case 5:
          setState(() => _finishStatus = 'Почти готово…');
          break;
        default:
          setState(() => _finishStatus = 'Ещё немного…');
          break;
      }
    });
  }

  bool get _canSubmit {
    if (_submitting || _finishing) return false;
    if (_q.type == 'forced_choice' || _q.type == 'sjt') {
      return _choiceKey != null;
    }
    if (_q.type == 'open') return _textController.text.trim().isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_finishing) {
      return Scaffold(
        backgroundColor: AurixTokens.bg0,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AurixTokens.accent),
              const SizedBox(height: 24),
              Text(
                _finishStatus,
                style:
                    TextStyle(color: AurixTokens.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Это может занять до минуты',
                style: TextStyle(color: AurixTokens.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AurixTokens.textSecondary),
          onPressed: () => _showExitDialog(),
        ),
        title: Text(
          'Вопрос ${_currentIndex + 1} из $_total',
          style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: AurixTokens.border,
            color: AurixTokens.accent,
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _q.text,
                      style: const TextStyle(
                        color: AurixTokens.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildAnswerWidget(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AurixTokens.accent,
                    disabledBackgroundColor: AurixTokens.border,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          _currentIndex + 1 == _total ? 'Завершить' : 'Далее',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerWidget() {
    switch (_q.type) {
      case 'scale':
        return _buildScale();
      case 'forced_choice':
      case 'sjt':
        return _buildOptions();
      case 'open':
        return _buildOpenText();
      default:
        return const SizedBox();
    }
  }

  Widget _buildScale() {
    final labels = _q.scaleLabels;
    final lowLabel =
        labels?.low.trim().isNotEmpty == true ? labels!.low : 'Совсем нет';
    final highLabel =
        labels?.high.trim().isNotEmpty == true ? labels!.high : 'Да, точно';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: '1',
                      style: TextStyle(
                        color: AurixTokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' — $lowLabel',
                      style: const TextStyle(
                        color: AurixTokens.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: RichText(
                textAlign: TextAlign.right,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$highLabel — ',
                      style: const TextStyle(
                        color: AurixTokens.muted,
                        fontSize: 12,
                      ),
                    ),
                    const TextSpan(
                      text: '5',
                      style: TextStyle(
                        color: AurixTokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final value = i + 1;
            final selected = _scaleValue == value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => setState(() => _scaleValue = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: selected ? AurixTokens.accent : AurixTokens.bg2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AurixTokens.accent : AurixTokens.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$value',
                    style: TextStyle(
                      color:
                          selected ? Colors.white : AurixTokens.textSecondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Text(
          'Выбрано: $_scaleValue',
          style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildOptions() {
    final options = _q.options ?? [];
    return Column(
      children: options.map((opt) {
        final selected = _choiceKey == opt.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => setState(() => _choiceKey = opt.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected
                    ? AurixTokens.accent.withValues(alpha: 0.12)
                    : AurixTokens.bg2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AurixTokens.accent : AurixTokens.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AurixTokens.accent : AurixTokens.bg1,
                      border: Border.all(
                        color: selected
                            ? AurixTokens.accent
                            : AurixTokens.borderLight,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      opt.text,
                      style: TextStyle(
                        color: selected
                            ? AurixTokens.text
                            : AurixTokens.textSecondary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOpenText() {
    return TextField(
      controller: _textController,
      maxLines: 6,
      minLines: 3,
      style: const TextStyle(color: AurixTokens.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Напиши здесь…',
        hintStyle: TextStyle(color: AurixTokens.muted),
        filled: true,
        fillColor: AurixTokens.bg2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AurixTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AurixTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AurixTokens.accent, width: 2),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Прервать интервью?',
            style: TextStyle(color: AurixTokens.text)),
        content: const Text(
          'Прогресс будет потерян. Вы сможете начать заново.',
          style: TextStyle(color: AurixTokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Продолжить',
                style: TextStyle(color: AurixTokens.accent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Выйти',
                style: TextStyle(color: AurixTokens.negative)),
          ),
        ],
      ),
    );
  }
}
