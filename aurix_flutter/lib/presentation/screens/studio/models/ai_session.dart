/// Stores context passed between AI characters in a pipeline.
class AiSession {
  String? idea;
  String? producerResult;
  String? writerResult;
  String? visualResult;
  String? smmResult;

  AiSession({this.idea});

  /// Build context string for a character based on previous results.
  String contextFor(String characterId) {
    final parts = <String>[];

    switch (characterId) {
      case 'producer':
        if (idea != null && idea!.isNotEmpty && producerResult != null) {
          parts.add(producerResult!);
          parts.add('\n$idea');
        }
      case 'writer':
        if (producerResult != null) {
          parts.add('Продюсер уже подготовил концепцию:\n\n$producerResult');
          parts.add('\nНапиши текст песни на основе этой концепции и хука.');
        }
      case 'visual':
        if (producerResult != null) {
          parts.add('Концепция от продюсера:\n\n$producerResult');
        }
        if (writerResult != null) {
          parts.add('Текст от автора:\n\n$writerResult');
          parts.add('\nСоздай визуальный стиль, обложку и атмосферу на основе текста и концепции.');
        }
      case 'smm':
        if (producerResult != null) {
          parts.add('Концепция:\n\n$producerResult');
        }
        if (writerResult != null) {
          parts.add('Текст:\n\n$writerResult');
        }
        if (visualResult != null) {
          parts.add('Визуал:\n\n$visualResult');
          parts.add('\nСоздай контент-план и Reels-идеи на основе всего вышестоящего.');
        }
    }

    if (parts.isEmpty) return '';
    return parts.join('\n\n---\n\n');
  }

  void saveResult(String characterId, String result) {
    switch (characterId) {
      case 'producer':
        producerResult = result;
      case 'writer':
        writerResult = result;
      case 'visual':
        visualResult = result;
      case 'smm':
        smmResult = result;
    }
  }

  /// Returns the index (0-3) of the current pipeline step.
  int stepIndex(String characterId) {
    const order = ['producer', 'writer', 'visual', 'smm'];
    return order.indexOf(characterId).clamp(0, 3);
  }

  /// How many steps are completed.
  int get completedSteps {
    int n = 0;
    if (producerResult != null) n++;
    if (writerResult != null) n++;
    if (visualResult != null) n++;
    if (smmResult != null) n++;
    return n;
  }
}
