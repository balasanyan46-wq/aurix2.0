import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/level_engine.dart';

void main() {
  late LevelEngine engine;

  setUp(() {
    engine = LevelEngine();
  });

  group('LevelEngine', () {
    test('getLevel returns correct level by score', () {
      expect(engine.getLevel(0).id, 'rookie');
      expect(engine.getLevel(249).id, 'rookie');
      expect(engine.getLevel(250).id, 'rising');
      expect(engine.getLevel(449).id, 'rising');
      expect(engine.getLevel(450).id, 'pro');
      expect(engine.getLevel(649).id, 'pro');
      expect(engine.getLevel(650).id, 'top');
      expect(engine.getLevel(799).id, 'top');
      expect(engine.getLevel(800).id, 'elite');
      expect(engine.getLevel(1000).id, 'elite');
    });

    test('pointsToNextLevel is never negative', () {
      for (var s = 0; s <= 1000; s += 50) {
        expect(engine.pointsToNextLevel(s), greaterThanOrEqualTo(0));
      }
    });

    test('pointsToNextLevel is correct at boundaries', () {
      expect(engine.pointsToNextLevel(249), 1);
      expect(engine.pointsToNextLevel(449), 1);
      expect(engine.pointsToNextLevel(649), 1);
      expect(engine.pointsToNextLevel(799), 1);
      expect(engine.pointsToNextLevel(800), 0);
      expect(engine.pointsToNextLevel(1000), 0);
    });

    test('progressToNextLevel is in 0..1', () {
      for (var s = 0; s <= 1000; s += 50) {
        final p = engine.progressToNextLevel(s);
        expect(p, greaterThanOrEqualTo(0.0));
        expect(p, lessThanOrEqualTo(1.0));
      }
    });
  });
}
