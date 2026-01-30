import 'dart:convert';
import 'dart:typed_data';

/// Safely converts a SQLite column value to String.
///
/// Flutter's sqflite package can return TEXT columns as Uint8List
/// instead of String under certain buffer management conditions.
/// This helper handles both cases safely.
String dbString(dynamic value) {
  if (value is String) return value;
  if (value is Uint8List) return utf8.decode(value);
  if (value is List<int>) return utf8.decode(value);
  return value.toString();
}

/// Safely converts a nullable SQLite column value to String?.
String? dbStringOrNull(dynamic value) {
  if (value == null) return null;
  return dbString(value);
}

/// Safely converts a SQLite column value to int.
int dbInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.parse(value);
  return (value as num).toInt();
}

/// Safely converts a nullable SQLite column value to int?.
int? dbIntOrNull(dynamic value) {
  if (value == null) return null;
  return dbInt(value);
}
