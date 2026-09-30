import 'package:core/core.dart' as core;

/// A Calculator
class Calculator {
  /// Returns [value] plus 1, using core's calculator.
  int addOne(int value) => core.Calculator().addOne(value);
}
