// Copyright (c) 2013, Alexandre Ardhuin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library rational;

import 'package:rational/bigint.dart';

final IS_JS = identical(1, 1.0);

final _PATTERN = new RegExp(r"^(-?\d+)(\.\d+)?$");

final _0 = new Rational(0);
final _1 = new Rational(1);
final _5 = new Rational(5);
final _10 = new Rational(10);

_int(int value) => IS_JS ? new BigInt.fromJsInt(value) : value;
final _INT_0 = _int(0);
final _INT_1 = _int(1);
final _INT_2 = _int(2);
final _INT_5 = _int(5);
final _INT_10 = _int(10);
final _INT_31 = _int(31);

_parseInt(String text) => IS_JS ? BigInt.parse(text) : int.parse(text);

_gcd(a, b) {
  while (b != _INT_0) {
    var t = b;
    b = a % t;
    a = t;
  }
  return a;
}

abstract class Rational<T extends dynamic/*int|BigInt*/> implements Comparable<Rational> {
  static Rational parse(String decimalValue) {
    final match = _PATTERN.firstMatch(decimalValue);
    if (match == null) throw new FormatException("$decimalValue is not a valid format");
    final group1 = match.group(1);
    final group2 = match.group(2);

    var numerator = _INT_0;
    var denominator = _INT_1;
    if (group2 != null) {
      for (int i = 1; i < group2.length; i++) {
        denominator = denominator * _INT_10;
      }
      numerator = _parseInt('${group1}${group2.substring(1)}');
    } else {
      numerator = _parseInt(group1);
    }
    return new Rational._normalize(numerator, denominator);
  }

  final T numerator, denominator;

  Rational._(this.numerator, this.denominator);

  factory Rational._normalized(numerator, denominator) => IS_JS ?
      new _RationalJs._normalized(numerator, denominator) :
        new _RationalVM._normalized(numerator, denominator);

  factory Rational(int numerator, [int denominator = 1]) =>
      new Rational._normalize(_int(numerator), _int(denominator));

  factory Rational._normalize(numerator, denominator) {
    if (denominator == _INT_0) throw new IntegerDivisionByZeroException();
    if (numerator == _INT_0) return new Rational._normalized(_INT_0, _INT_1);
    if (denominator < _INT_0) {
      numerator = -numerator;
      denominator = -denominator;
    }
    final aNumerator = numerator.abs();
    final aDenominator = denominator.abs();
    final gcd = _gcd(aNumerator, aDenominator);
    return (gcd == _INT_1)
        ? new Rational._normalized(numerator, denominator)
        : new Rational._normalized(numerator ~/ gcd, denominator ~/ gcd);
  }

  bool get isInteger => denominator == _INT_1;

  int get hashCode => (numerator + _INT_31 * denominator).hashCode;

  bool operator ==(Rational other) => numerator == other.numerator && denominator == other.denominator;

  String toString() {
    if (numerator == _INT_0) return '0';
    if (isInteger) return '$numerator';
    else return '$numerator/$denominator';
  }

  String toDecimalString() {
    if (isInteger) return toStringAsFixed(0);

    // remove factor 2 and 5 of denominator to know if String representation is finished
    // in decimal system, division by 2 or 5 leads to a finished size of decimal part
    var denominator = this.denominator;
    int fractionDigits = 0;
    while (denominator % _INT_2 == _INT_0) {
      denominator = denominator ~/ _INT_2;
      fractionDigits++;
    }
    while (denominator % _INT_5 == _INT_0) {
      denominator = denominator ~/ _INT_5;
      fractionDigits++;
    }
    final hasLimitedLength = numerator % denominator == _INT_0;
    if (!hasLimitedLength) {
      fractionDigits = 10;
    }
    String asString = toStringAsFixed(fractionDigits);
    while (asString.contains('.') && (asString.endsWith('0') || asString.endsWith('.'))) {
      asString = asString.substring(0, asString.length - 1);
    }
    return asString;
  }
  // implementation of Comparable

  int compareTo(Rational other) => (numerator * other.denominator).compareTo(other.numerator * denominator);

  // implementation of num

  /** Addition operator. */
  Rational operator +(Rational other) => new Rational._normalize(numerator * other.denominator + other.numerator * denominator, denominator * other.denominator);

  /** Subtraction operator. */
  Rational operator -(Rational other) => new Rational._normalize(numerator * other.denominator - other.numerator * denominator, denominator * other.denominator);

  /** Multiplication operator. */
  Rational operator *(Rational other) => new Rational._normalize(numerator * other.numerator, denominator * other.denominator);

  /** Euclidean modulo operator. */
  Rational operator %(Rational other) => this.remainder(other) + (isNegative ? other.abs() : _0);

  /** Division operator. */
  Rational operator /(Rational other) => new Rational._normalize(numerator * other.denominator, denominator * other.numerator);

  /**
   * Truncating division operator.
   *
   * The result of the truncating division [:a ~/ b:] is equivalent to
   * [:(a / b).truncate():].
   */
  Rational operator ~/(Rational other) => (this / other).truncate();

  /** Negate operator. */
  Rational operator -() => new Rational._normalized(-numerator, denominator);

  /** Return the remainder from dividing this [num] by [other]. */
  Rational remainder(Rational other) => this - (this ~/ other) * other;

  /** Relational less than operator. */
  bool operator <(Rational other) => this.compareTo(other) < 0;

  /** Relational less than or equal operator. */
  bool operator <=(Rational other) => this.compareTo(other) <= 0;

  /** Relational greater than operator. */
  bool operator >(Rational other) => this.compareTo(other) > 0;

  /** Relational greater than or equal operator. */
  bool operator >=(Rational other) => this.compareTo(other) >= 0;

  bool get isNaN => false;

  bool get isNegative => numerator < _INT_0;

  bool get isInfinite => false;

  /** Returns the absolute value of this [num]. */
  Rational abs() => isNegative ? (-this) : this;

  /**
   * Returns the integer value closest to this [num].
   *
   * Rounds away from zero when there is no closest integer:
   *  [:(3.5).round() == 4:] and [:(-3.5).round() == -4:].
   */
  Rational round() {
    final abs = this.abs();
    final absBy10 =  abs * _10;
    Rational r;
    if (absBy10 % _10 < _5) {
      r = abs.truncate();
    } else {
      r = abs.truncate() + _1;
    }
    return isNegative ? -r : r;
  }

  /** Returns the greatest integer value no greater than this [num]. */
  Rational floor() => isInteger ? this.truncate() : isNegative ? (this.truncate() - _1) : this.truncate();

  /** Returns the least integer value that is no smaller than this [num]. */
  Rational ceil() => isInteger ? this.truncate() : isNegative ? this.truncate() : (this.truncate() + _1);

  /**
   * Returns the integer value obtained by discarding any fractional
   * digits from this [num].
   */
  Rational truncate() => new Rational._normalized(_toInt(), _INT_1);

  /**
   * Returns the integer value closest to `this`.
   *
   * Rounds away from zero when there is no closest integer:
   *  [:(3.5).round() == 4:] and [:(-3.5).round() == -4:].
   *
   * The result is a double.
   */
  double roundToDouble() => round().toDouble();

  /**
   * Returns the greatest integer value no greater than `this`.
   *
   * The result is a double.
   */
  double floorToDouble() => floor().toDouble();

  /**
   * Returns the least integer value no smaller than `this`.
   *
   * The result is a double.
   */
  double ceilToDouble() => ceil().toDouble();

  /**
   * Returns the integer obtained by discarding any fractional
   * digits from `this`.
   *
   * The result is a double.
   */
  double truncateToDouble() => truncate().toDouble();

  /**
   * Clamps [this] to be in the range [lowerLimit]-[upperLimit]. The comparison
   * is done using [compareTo] and therefore takes [:-0.0:] into account.
   */
  Rational clamp(Rational lowerLimit, Rational upperLimit) => this < lowerLimit ? lowerLimit : this > upperLimit ? upperLimit : this;

  /** Truncates this [num] to an integer and returns the result as an [int]. */
  int toInt();

  T _toInt() => numerator ~/ denominator;

  /**
   * Return this [num] as a [double].
   *
   * If the number is not representable as a [double], an
   * approximation is returned. For numerically large integers, the
   * approximation may be infinite.
   */
  double toDouble();

  /**
   * Converts a [num] to a string representation with [fractionDigits]
   * digits after the decimal point.
   */
  String toStringAsFixed(int fractionDigits) {
    if (fractionDigits == 0) {
      return round()._toInt().toString();
    } else {
      var mul = _INT_1;
      for (int i = 0; i < fractionDigits; i++) {
        mul *= _INT_10;
      }
      final mulRat = new Rational._normalize(mul, _INT_1);
      final tmp = (abs() + _1) * mulRat;
      final tmpRound = tmp.round();
      final intPart = ((tmpRound ~/ mulRat) - _1)._toInt();
      final decimalPart = tmpRound._toInt().toString().substring(intPart.toString().length);
      return '${isNegative ? '-' : ''}${intPart}.${decimalPart}';
    }
  }

  /**
   * Converts a [num] to a string in decimal exponential notation with
   * [fractionDigits] digits after the decimal point.
   */
  String toStringAsExponential(int fractionDigits)  => toDouble().toStringAsExponential(fractionDigits);

  /**
   * Converts a [num] to a string representation with [precision]
   * significant digits.
   */
  String toStringAsPrecision(int precision) => toDouble().toStringAsPrecision(precision);
}

class _RationalJs extends Rational<BigInt> {
  _RationalJs._normalized(BigInt numerator, BigInt denominator) :
    super._(numerator, denominator);

  int toInt() => int.parse(_toInt().toString());
  double toDouble() => double.parse('$numerator') / double.parse('$denominator');
}

class _RationalVM extends Rational<int> {
  _RationalVM._normalized(int numerator, int denominator) :
    super._(numerator, denominator);

  int toInt() => numerator ~/ denominator;
  double toDouble() => numerator / denominator;
}
