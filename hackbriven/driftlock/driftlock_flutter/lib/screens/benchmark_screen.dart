import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform_io.dart';
import 'benchmark_debrief_screen.dart';

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key, this.capture});

  final String? capture;

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  late final _report = _load(widget.capture);
  var _index = 0;

  static Future<List<Map>> _load(String? capture) async {
    final raw = capture == null
        ? await rootBundle.loadString('assets/austin_benchmark.json')
        : await nativeChannel.invokeMethod<String>('benchmark', capture);
    final json = jsonDecode(raw!) as Map;
    if (json['schema'] != 'driftlock-hackathon-benchmark-v1') {
      throw const FormatException('Unknown benchmark schema');
    }
    return (json['groups'] as List).cast<Map>();
  }

  Future<void> _export(Map group, String format) async {
    final summary = group['summary'] as Map;
    final seconds = summary['outage_seconds'];
    final String contents;
    if (format == 'json') {
      contents = const JsonEncoder.withIndent('  ').convert(summary);
    } else {
      String quote(Object? value) =>
          '"${(value ?? '').toString().replaceAll('"', '""')}"';
      final csv = StringBuffer(
        'source,dataset_id,outage_seconds,window,method,sample_count,mean_error_m,'
        'median_error_m,p90_error_m,max_error_m,failure,provenance\n',
      );
      void write(String window, List values, Object? failure) {
        for (final Map method in values) {
          csv.writeln(
            [
              'Recorded',
              summary['dataset_id'],
              seconds,
              window,
              method['name'],
              method['sample_count'],
              method['mean_error_m'],
              method['median_error_m'],
              method['p90_error_m'],
              method['max_error_m'],
              failure,
              summary['provenance'],
            ].map(quote).join(','),
          );
        }
      }

      write('aggregate', summary['methods'], group['elapsedUnavailable']);
      for (final Map window in group['windows']) {
        write(window['id'] as String, window['methods'], window['failure']);
      }
      contents = csv.toString();
    }
    try {
      await exportText('driftlock-${seconds}s.$format', contents);
      if (mounted && !hasIPhoneBridge) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${format.toUpperCase()} export ready')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export could not be opened.')),
        );
      }
    }
  }

  Widget _metrics(List methods) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columnSpacing: 16,
      horizontalMargin: 10,
      columns: const [
        DataColumn(label: Text('Method')),
        DataColumn(label: Text('Mean'), numeric: true),
        DataColumn(label: Text('Median'), numeric: true),
        DataColumn(label: Text('P90'), numeric: true),
        DataColumn(label: Text('Max'), numeric: true),
      ],
      rows: [
        for (final Map method in methods)
          DataRow(
            cells: [
              DataCell(Text(method['name'] as String)),
              for (final key in [
                'mean_error_m',
                'median_error_m',
                'p90_error_m',
                'max_error_m',
              ])
                DataCell(
                  Text(
                    method[key] == null
                        ? '—'
                        : (method[key] as num).toStringAsFixed(1),
                  ),
                ),
            ],
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Benchmark Arena')),
    body: FutureBuilder(
      future: _report,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Benchmark unavailable.'));
        }
        final groups = snapshot.data;
        if (groups == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final group = groups[_index];
        final summary = group['summary'] as Map;
        final windows = group['windows'] as List;
        final methods = summary['methods'] as List;
        final samples = (methods.first as Map)['sample_count'] as int;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              children: [
                Text(
                  'Outage performance',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text('Recorded phone motion · Imposed GPS outages'),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (index, item) in groups.indexed)
                      ChoiceChip(
                        label: Text('${item['summary']['outage_seconds']} s'),
                        selected: index == _index,
                        onSelected: (_) => setState(() => _index = index),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  samples == 0
                      ? 'Unmeasured · ${group['elapsedUnavailable'] ?? 'No complete comparisons.'}'
                      : '${windows.where((row) => row['failure'] == null).length} of ${windows.length} windows scored · '
                            '$samples withheld fixes · ${summary['tested_sessions']} original drive',
                ),
                if (samples > 0) ...[
                  const SizedBox(height: 6),
                  _metrics(methods),
                  const Text(
                    'Horizontal error in metres. P90 uses nearest rank.',
                  ),
                ],
                const Divider(height: 28),
                Text(
                  'Replay windows',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final Map window in windows)
                  ExpansionTile(
                    title: Text(
                      'Window ${window['id']} · starts at ${(window['startSeconds'] as num).round()} s',
                    ),
                    subtitle: Text(
                      window['failure'] as String? ??
                          '${window['expectedFixes']} comparison fixes',
                    ),
                    children: [
                      if (window['failure'] == null)
                        _metrics(window['methods'] as List)
                      else
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('Unmeasured · excluded from aggregate'),
                        ),
                    ],
                  ),
                const Divider(height: 28),
                const Text(
                  'All methods use the same eligible GPS fixes for scoring. '
                  'The estimator receives only admitted GPS and recorded motion. '
                  'The withheld phone GPS is the comparison reference. Generalization requires more drives.',
                ),
                const SizedBox(height: 10),
                SelectableText(summary['provenance'] as String),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _export(group, 'json'),
                      child: const Text('Export JSON'),
                    ),
                    OutlinedButton(
                      onPressed: () => _export(group, 'csv'),
                      child: const Text('Export CSV'),
                    ),
                    if (widget.capture == null)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const BenchmarkDebriefScreen(
                              evidence:
                                  'The Austin debrief covers the original five 30-second windows.',
                            ),
                          ),
                        ),
                        child: const Text('Adaption debrief'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
