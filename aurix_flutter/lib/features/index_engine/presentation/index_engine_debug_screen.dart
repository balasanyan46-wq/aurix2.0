import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Debug: table artist -> score -> rank -> trendDelta -> penalty.
class IndexEngineDebugScreen extends ConsumerStatefulWidget {
  const IndexEngineDebugScreen({super.key});

  @override
  ConsumerState<IndexEngineDebugScreen> createState() => _IndexEngineDebugScreenState();
}

class _IndexEngineDebugScreenState extends ConsumerState<IndexEngineDebugScreen> {
  List<({String name, int score, int rank, int trendDelta, double penalty})>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _data = null;
      _error = null;
    });
    try {
      final service = ref.read(indexEngineServiceProvider);
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month - 1, 1);
      final periodEnd = now;
      final leaderboard = await service.getLeaderboard(periodStart, periodEnd);
      setState(() {
        _data = leaderboard.map((e) => (
          name: e.artist.name,
          score: e.score.score,
          rank: e.score.rankOverall,
          trendDelta: e.score.trendDelta,
          penalty: e.score.penaltyApplied,
        )).toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Index Engine Debug'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text('Ошибка: $_error', style: TextStyle(color: AurixTokens.muted)));
    }
    if (_data == null) {
      return const Center(child: CircularProgressIndicator(color: AurixTokens.orange));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AurixTokens.glass(0.1)),
          columns: const [
            DataColumn(label: Text('Rank')),
            DataColumn(label: Text('Artist')),
            DataColumn(label: Text('Score'), numeric: true),
            DataColumn(label: Text('Trend'), numeric: true),
            DataColumn(label: Text('Penalty'), numeric: true),
          ],
          rows: _data!.asMap().entries.map((e) {
            final d = e.value;
            return DataRow(
              cells: [
                DataCell(Text('${d.rank}')),
                DataCell(Text(d.name)),
                DataCell(Text('${d.score}')),
                DataCell(Text('${d.trendDelta >= 0 ? '+' : ''}${d.trendDelta}')),
                DataCell(Text(d.penalty.toStringAsFixed(2))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
