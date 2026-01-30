import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybartenderai/src/utils/db_type_helpers.dart';

void main() {
  group('dbString', () {
    test('passes through String values unchanged', () {
      expect(dbString('hello'), equals('hello'));
      expect(dbString(''), equals(''));
      expect(dbString('Margarita'), equals('Margarita'));
    });

    test('converts Uint8List to String via UTF-8 decode', () {
      final bytes = Uint8List.fromList(utf8.encode('Margarita'));
      expect(dbString(bytes), equals('Margarita'));
    });

    test('handles UTF-8 multi-byte characters in Uint8List', () {
      final bytes = Uint8List.fromList(utf8.encode('Caña de Azúcar'));
      expect(dbString(bytes), equals('Caña de Azúcar'));
    });

    test('handles Uint8List sublist view (similar to internal unmodifiable view)', () {
      final original = Uint8List.fromList(utf8.encode('test value'));
      // buffer.asUint8List creates a view similar to _UnmodifiableUint8ArrayView
      final view = original.buffer.asUint8List(0, original.length);
      expect(dbString(view), equals('test value'));
    });

    test('converts comma-separated tags from Uint8List', () {
      final bytes = Uint8List.fromList(utf8.encode('Classic,Strong,IBA'));
      final result =
          dbString(bytes).split(',').where((t) => t.isNotEmpty).toList();
      expect(result, equals(['Classic', 'Strong', 'IBA']));
    });

    test('handles empty Uint8List', () {
      final bytes = Uint8List.fromList([]);
      expect(dbString(bytes), equals(''));
    });

    test('handles List<int> (safety net)', () {
      final intList = utf8.encode('Mojito');
      expect(dbString(intList), equals('Mojito'));
    });

    test('handles non-string/non-bytes via toString fallback', () {
      expect(dbString(42), equals('42'));
    });
  });

  group('dbStringOrNull', () {
    test('returns null for null input', () {
      expect(dbStringOrNull(null), isNull);
    });

    test('converts non-null Uint8List', () {
      final bytes = Uint8List.fromList(utf8.encode('Rocks'));
      expect(dbStringOrNull(bytes), equals('Rocks'));
    });

    test('passes through non-null String', () {
      expect(dbStringOrNull('Rocks'), equals('Rocks'));
    });
  });

  group('dbInt', () {
    test('passes through int values', () {
      expect(dbInt(42), equals(42));
      expect(dbInt(0), equals(0));
      expect(dbInt(-1), equals(-1));
    });

    test('parses String to int', () {
      expect(dbInt('42'), equals(42));
      expect(dbInt('0'), equals(0));
    });

    test('converts num (double) to int', () {
      expect(dbInt(42.0), equals(42));
    });
  });

  group('dbIntOrNull', () {
    test('returns null for null input', () {
      expect(dbIntOrNull(null), isNull);
    });

    test('passes through non-null int values', () {
      expect(dbIntOrNull(7), equals(7));
    });

    test('converts non-null String to int', () {
      expect(dbIntOrNull('7'), equals(7));
    });
  });

  group('Simulated Cocktail.fromDb scenario', () {
    test('handles row with all String values (normal case)', () {
      final row = <String, dynamic>{
        'id': 'custom_001',
        'name': 'My Drink',
        'tags': 'Classic,Strong',
        'created_at': '2026-01-30T00:00:00.000Z',
        'updated_at': '2026-01-30T00:00:00.000Z',
        'source': 'custom',
      };
      expect(dbString(row['id']), equals('custom_001'));
      expect(dbString(row['name']), equals('My Drink'));
      expect(
          dbString(row['tags']).split(','), equals(['Classic', 'Strong']));
      expect(DateTime.parse(dbString(row['created_at'])), isA<DateTime>());
    });

    test('handles row with Uint8List values (the bug scenario)', () {
      final row = <String, dynamic>{
        'id': Uint8List.fromList(utf8.encode('custom_001')),
        'name': Uint8List.fromList(utf8.encode('My Drink')),
        'tags': Uint8List.fromList(utf8.encode('Classic,Strong')),
        'created_at':
            Uint8List.fromList(utf8.encode('2026-01-30T00:00:00.000Z')),
        'updated_at':
            Uint8List.fromList(utf8.encode('2026-01-30T00:00:00.000Z')),
        'source': Uint8List.fromList(utf8.encode('custom')),
      };
      expect(dbString(row['id']), equals('custom_001'));
      expect(dbString(row['name']), equals('My Drink'));
      expect(
          dbString(row['tags']).split(','), equals(['Classic', 'Strong']));
      expect(DateTime.parse(dbString(row['created_at'])), isA<DateTime>());
      expect(dbStringOrNull(row['source']), equals('custom'));
    });

    test('handles mixed types in same row (realistic edge case)', () {
      final row = <String, dynamic>{
        'id': 'custom_002',
        'name': Uint8List.fromList(utf8.encode('Test Cocktail')),
        'tags': null,
        'created_at': '2026-01-30T12:00:00.000Z',
        'source': null,
      };
      expect(dbString(row['id']), equals('custom_002'));
      expect(dbString(row['name']), equals('Test Cocktail'));
      expect(dbStringOrNull(row['tags']), isNull);
      expect(dbStringOrNull(row['source']), isNull);
    });
  });

  group('Simulated DrinkIngredient.fromDb scenario', () {
    test('handles normal row', () {
      final row = <String, dynamic>{
        'id': 1,
        'drink_id': 'custom_001',
        'ingredient_name': 'Vodka',
        'measure': '2 oz',
        'ingredient_order': 1,
      };
      expect(dbIntOrNull(row['id']), equals(1));
      expect(dbString(row['drink_id']), equals('custom_001'));
      expect(dbString(row['ingredient_name']), equals('Vodka'));
      expect(dbStringOrNull(row['measure']), equals('2 oz'));
      expect(dbInt(row['ingredient_order']), equals(1));
    });

    test('handles Uint8List ingredient row', () {
      final row = <String, dynamic>{
        'id': 1,
        'drink_id': Uint8List.fromList(utf8.encode('custom_001')),
        'ingredient_name': Uint8List.fromList(utf8.encode('Vodka')),
        'measure': Uint8List.fromList(utf8.encode('2 oz')),
        'ingredient_order': 1,
      };
      expect(dbString(row['drink_id']), equals('custom_001'));
      expect(dbString(row['ingredient_name']), equals('Vodka'));
      expect(dbStringOrNull(row['measure']), equals('2 oz'));
    });
  });
}
