import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

class PerformanceMetrics {
  final Map<String, List<int>> _metrics = {
    'build_duration': [],
    'deployment_duration': [],
    'memory_consumption': [],
    'network_latency': [],
    'pipeline_duration': [],
    'concurrent_jobs_duration': [],
  };

  void recordBuildDuration(int duration) {
    _metrics['build_duration']?.add(duration);
  }

  void recordDeploymentDuration(int duration) {
    _metrics['deployment_duration']?.add(duration);
  }

  void recordMemoryConsumption(int bytes) {
    _metrics['memory_consumption']?.add(bytes);
  }

  void recordNetworkLatency(int latency) {
    _metrics['network_latency']?.add(latency);
  }

  void recordPipelineDuration(int duration) {
    _metrics['pipeline_duration']?.add(duration);
  }

  void recordConcurrentJobsDuration(int duration) {
    _metrics['concurrent_jobs_duration']?.add(duration);
  }

  Future<int> getCurrentMemoryUsage() async {
    if (Platform.isLinux || Platform.isMacOS) {
      final result = await Process.run('ps', ['-o', 'rss=', '-p', '${pid}']);
      return int.parse(result.stdout.toString().trim());
    } else if (Platform.isWindows) {
      final result = await Process.run('wmic', [
        'process',
        'where',
        'ProcessId=${pid}',
        'get',
        'WorkingSetSize'
      ]);
      final lines = result.stdout.toString().split('\n');
      return int.parse(lines[1].trim()) ~/ 1024; // Convert bytes to KB
    }
    return 0;
  }

  Map<String, Map<String, num>> _calculateStats() {
    final stats = <String, Map<String, num>>{};
    
    _metrics.forEach((metric, values) {
      if (values.isEmpty) return;
      
      final avg = values.reduce((a, b) => a + b) / values.length;
      final sorted = List<int>.from(values)..sort();
      final median = values.length.isOdd
          ? sorted[values.length ~/ 2]
          : (sorted[(values.length - 1) ~/ 2] + sorted[values.length ~/ 2]) / 2;
      
      stats[metric] = {
        'min': values.reduce((a, b) => a < b ? a : b),
        'max': values.reduce((a, b) => a > b ? a : b),
        'avg': avg,
        'median': median,
      };
    });
    
    return stats;
  }

  void exportMetrics() {
    final stats = _calculateStats();
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'metrics': stats,
      'environment': {
        'os': Platform.operatingSystem,
        'version': Platform.version,
        'numberOfProcessors': Platform.numberOfProcessors,
      },
    };

    final reportsDir = Directory(path.join(
      Directory.current.path,
      'test_reports',
      'performance'
    ));
    
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }

    final reportFile = File(path.join(
      reportsDir.path,
      'performance_report_${DateTime.now().millisecondsSinceEpoch}.json'
    ));
    
    reportFile.writeAsStringSync(
      JsonEncoder.withIndent('  ').convert(report),
      flush: true
    );
  }
}