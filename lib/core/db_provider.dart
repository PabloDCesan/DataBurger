import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final databaseProvider = Provider<Database>((ref) {
  return AppDb().db;
});
