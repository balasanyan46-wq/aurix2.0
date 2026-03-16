import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../data/dnk_tests_models.dart';
import '../data/dnk_tests_service.dart';

class DnkTestInterviewScreen extends StatefulWidget {
  final String testTitle;
  final DnkTestStartResponse startResponse;

  const DnkTestInterviewScreen({
    super.key,
    required this.testTitle,
    required this.startResponse,
  });

  @override
  State<DnkTestInterviewScreen> createState() => _DnkTestInterviewScreenState();
}

class _DnkTestInterviewScreenState extends State<DnkTestInterviewScreen> {
  final _service = DnkTestsService();
  final List<DnkTestQuestion> _queue = [];
  int _index = 0;
  int _scaleValue = 3;
  String? _choiceKey;
  final _textController = TextEditingController();
  bool _submitting = false;
  bool _finishing = false;

  DnkTestQuestion get _q => _queue[_index];
  int get _total => _queue.length;
  double get _progress => _total == 0 ? 0 : (_index + 1) / _total;

  @override
  void initState() {
    super.initState();
    _queue.addAll(widget.startResponse.questions);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _canNext {
    if (_submitting || _finishing) return false;
    if (_q.type == 'open') return _textController.text.trim().isNotEmpty;
    if (_q.type == 'forced_choice' || _q.type == 'sjt') return _choiceKey != null;
    return true;
  }

  Future<void> _next() async {
    if (!_canNext) return;
    setState(() => _submitting = true);
    try {
      Map<String, dynamic> answerJson;
      if (_q.type == 'scale') {
        answerJson = {'value': _scaleValue};
      } else if (_q.type == 'forced_choice' || _q.type == 'sjt') {
        answerJson = {'key': _choiceKey};
      } else {
        answerJson = {'text': _textController.text.trim()};
      }

      final followup = await _service.submitAnswer(
        sessionId: widget.startResponse.sessionId,
        questionId: _q.id,
        answerType: _q.type,
        answerJson: answerJson,
      );
      if (followup.followup != null) {
        _queue.insert(_index + 1, followup.followup!);
      }

      if (_index + 1 < _queue.length) {
        setState(() {
          _index++;
          _submitting = false;
          _scaleValue = 3;
          _choiceKey = null;
          _textController.clear();
        });
      } else {
        setState(() {
          _submitting = false;
          _finishing = true;
        });
        final result = await _service.finishAndWait(widget.startResponse.sessionId);
        if (!mounted) return;
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1,
        title: Text(widget.testTitle, style: const TextStyle(color: AurixTokens.text)),
        iconTheme: const IconThemeData(color: AurixTokens.textSecondary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _progress,
            color: AurixTokens.accent,
            backgroundColor: AurixTokens.border,
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Вопрос ${_index + 1} из $_total',
                    style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                  ),
                  const Spacer(),
                  if (_q.isFollowup)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AurixTokens.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Уточнение',
                        style: TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: SingleChildScrollView(
                  key: ValueKey(_q.id),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _q.text,
                        style: const TextStyle(
                          color: AurixTokens.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _buildAnswer(),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _canNext ? _next : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AurixTokens.accent,
                    disabledBackgroundColor: AurixTokens.border,
                  ),
                  child: _submitting || _finishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_index + 1 == _total ? 'Завершить тест' : 'Далее'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswer() {
    switch (_q.type) {
      case 'scale':
        return Column(
          children: [
            Row(
              children: [
                Text(
                  _q.scaleLabels?.isNotEmpty == true ? _q.scaleLabels!.first : '1',
                  style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _q.scaleLabels?.length == 5 ? _q.scaleLabels!.last : '5',
                  style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final v = i + 1;
                final selected = v == _scaleValue;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: GestureDetector(
                    onTap: () => setState(() => _scaleValue = v),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: selected ? AurixTokens.accent : AurixTokens.bg2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? AurixTokens.accent : AurixTokens.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$v',
                        style: TextStyle(
                          color: selected ? Colors.white : AurixTokens.textSecondary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      case 'forced_choice':
      case 'sjt':
        final options = _q.options ?? const <DnkTestOption>[];
        return Column(
          children: options.map((o) {
            final selected = _choiceKey == o.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => _choiceKey = o.key),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? AurixTokens.accent.withValues(alpha: 0.12) : AurixTokens.bg2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? AurixTokens.accent : AurixTokens.border),
                  ),
                  child: Text(
                    o.text,
                    style: TextStyle(
                      color: selected ? AurixTokens.text : AurixTokens.textSecondary,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      case 'open':
      default:
        return TextField(
          controller: _textController,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(color: AurixTokens.text),
          decoration: InputDecoration(
            hintText: 'Напиши ответ...',
            hintStyle: const TextStyle(color: AurixTokens.muted),
            filled: true,
            fillColor: AurixTokens.bg2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AurixTokens.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AurixTokens.accent),
            ),
          ),
          onChanged: (_) => setState(() {}),
        );
    }
  }
}
