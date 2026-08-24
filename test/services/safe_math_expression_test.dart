import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/safe_math_expression.dart';

void main() {
  final calculator = SafeMathExpression();

  test('supports precedence, parentheses, decimals, and unary negatives', () {
    expect(calculator.evaluate('(12 + 8) * 5'), 100);
    expect(calculator.evaluate('-2.5 * (4 - 6)'), 5);
    expect(calculator.evaluate('1 + 2 * 3'), 7);
  });

  test('rejects division by zero and non-math input', () {
    expect(() => calculator.evaluate('3 / 0'),
        throwsA(isA<MathExpressionError>()));
    expect(() => calculator.evaluate('run(1)'),
        throwsA(isA<MathExpressionError>()));
  });
}
