// ignore_for_file: avoid_print

void main() {
  const int iterations = 1000;
  const int chunksPerIteration = 1000;
  const String chunk = 'word ';

  print('Running benchmark with $iterations iterations of $chunksPerIteration chunks each...');

  // Measure String Concatenation (Baseline)
  final stopwatch = Stopwatch()..start();

  for (int i = 0; i < iterations; i++) {
    String result = '';
    for (int j = 0; j < chunksPerIteration; j++) {
      result += chunk;
    }
    // Prevent optimization
    if (result.length != chunksPerIteration * chunk.length) {
      throw Exception('Validation failed');
    }
  }

  stopwatch.stop();
  final double averageTimeUs = stopwatch.elapsedMicroseconds / iterations;

  print('Baseline: String += concatenation');
  print('Total time: ${stopwatch.elapsedMilliseconds}ms');
  print('Average time per iteration: ${averageTimeUs.toStringAsFixed(2)}µs');

  // Measure StringBuffer (Optimization)
  final stopwatchOpt = Stopwatch()..start();

  for (int i = 0; i < iterations; i++) {
    final buffer = StringBuffer();
    for (int j = 0; j < chunksPerIteration; j++) {
      buffer.write(chunk);
    }
    final result = buffer.toString();
    // Prevent optimization
    if (result.length != chunksPerIteration * chunk.length) {
      throw Exception('Validation failed');
    }
  }

  stopwatchOpt.stop();
  final double averageTimeOptUs = stopwatchOpt.elapsedMicroseconds / iterations;

  print('\nOptimization: StringBuffer');
  print('Total time: ${stopwatchOpt.elapsedMilliseconds}ms');
  print('Average time per iteration: ${averageTimeOptUs.toStringAsFixed(2)}µs');

  final speedup = averageTimeUs / averageTimeOptUs;
  print('\nSpeedup factor: ${speedup.toStringAsFixed(1)}x');
}
