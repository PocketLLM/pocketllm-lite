// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:typed_data';

void main() {
  // Create a realistic image-sized base64 string (approx 50KB)
  final Uint8List originalBytes = Uint8List(50 * 1024);
  for (int i = 0; i < originalBytes.length; i++) {
    originalBytes[i] = i % 256;
  }
  final String base64Image = base64Encode(originalBytes);

  // Measure repeated decoding (Baseline)
  final stopwatch = Stopwatch()..start();
  int iterations = 1000;

  for (int i = 0; i < iterations; i++) {
    // Simulate what happens in the build method
    final decoded = base64Decode(base64Image);
    // Use the bytes to ensure it's not optimized away
    if (decoded.length != originalBytes.length) {
      throw Exception('Validation failed');
    }
  }

  stopwatch.stop();
  final double averageTimeUs = stopwatch.elapsedMicroseconds / iterations;

  print('Baseline: Repeated base64Decode');
  print(
    'Total time for $iterations iterations: ${stopwatch.elapsedMilliseconds}ms',
  );
  print('Average time per decode: ${averageTimeUs.toStringAsFixed(2)}µs');

  // Measure optimized approach (Decode once, reuse)
  final stopwatchOpt = Stopwatch()..start();

  // Decode once
  final decodedOnce = base64Decode(base64Image);

  for (int i = 0; i < iterations; i++) {
    // Simulate reuse
    final bytes = decodedOnce;
    if (bytes.length != originalBytes.length) {
      throw Exception('Validation failed');
    }
  }

  stopwatchOpt.stop();
  final double averageTimeOptUs = stopwatchOpt.elapsedMicroseconds / iterations;

  print('\nOptimization: Decode once, reuse bytes');
  print(
    'Total time for $iterations iterations: ${stopwatchOpt.elapsedMilliseconds}ms',
  );
  print('Average time per access: ${averageTimeOptUs.toStringAsFixed(2)}µs');

  final speedup = averageTimeUs / averageTimeOptUs;
  print('\nSpeedup factor: ${speedup.toStringAsFixed(1)}x');
}
