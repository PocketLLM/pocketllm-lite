class MathExpressionError implements Exception {
  final String message;
  const MathExpressionError(this.message);

  @override
  String toString() => message;
}

class SafeMathExpression {
  late String _source;
  var _index = 0;

  double evaluate(String source) {
    _source = source;
    _index = 0;
    if (source.trim().isEmpty) {
      throw const MathExpressionError('Expression is empty.');
    }
    final result = _expression();
    _skipWhitespace();
    if (_index != _source.length) {
      throw MathExpressionError(
          'Unexpected character at position ${_index + 1}.');
    }
    if (!result.isFinite) {
      throw const MathExpressionError('Result is not finite.');
    }
    return result;
  }

  double _expression() {
    var value = _term();
    while (true) {
      if (_consume('+')) {
        value += _term();
      } else if (_consume('-')) {
        value -= _term();
      } else {
        return value;
      }
    }
  }

  double _term() {
    var value = _factor();
    while (true) {
      if (_consume('*')) {
        value *= _factor();
      } else if (_consume('/')) {
        final divisor = _factor();
        if (divisor == 0) throw const MathExpressionError('Division by zero.');
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _factor() {
    if (_consume('+')) return _factor();
    if (_consume('-')) return -_factor();
    if (_consume('(')) {
      final value = _expression();
      if (!_consume(')')) {
        throw const MathExpressionError('Missing closing parenthesis.');
      }
      return value;
    }
    return _number();
  }

  double _number() {
    _skipWhitespace();
    final start = _index;
    var decimalSeen = false;
    while (_index < _source.length) {
      final character = _source[_index];
      if (character == '.' && !decimalSeen) {
        decimalSeen = true;
        _index++;
      } else if ('0123456789'.contains(character)) {
        _index++;
      } else {
        break;
      }
    }
    if (start == _index) {
      throw MathExpressionError('Expected a number at position ${_index + 1}.');
    }
    final value = double.tryParse(_source.substring(start, _index));
    if (value == null) throw const MathExpressionError('Invalid number.');
    return value;
  }

  bool _consume(String character) {
    _skipWhitespace();
    if (_index < _source.length && _source[_index] == character) {
      _index++;
      return true;
    }
    return false;
  }

  void _skipWhitespace() {
    while (_index < _source.length && _source[_index].trim().isEmpty) {
      _index++;
    }
  }
}
