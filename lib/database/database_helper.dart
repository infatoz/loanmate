import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/loan.dart';
import '../models/emi.dart';
import '../models/document.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('loanmate.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const textNullable = 'TEXT';

    await db.execute('''
CREATE TABLE loans (
  id $idType,
  lender_name $textType,
  loan_name $textType,
  loan_type $textType,
  loan_amount $realType,
  emi_amount $realType,
  interest_rate $realType,
  total_months $integerType,
  remaining_months $integerType,
  start_date $textType,
  due_day_of_month $integerType,
  notes $textNullable,
  status $textType,
  created_at $textType
)
''');

    await db.execute('''
CREATE TABLE emis (
  id $idType,
  loan_id $textType,
  emi_number $integerType,
  due_date $textType,
  amount $realType,
  status $textType,
  payment_date $textNullable,
  payment_method $textNullable,
  payment_reference $textNullable,
  proof_image_path $textNullable,
  FOREIGN KEY (loan_id) REFERENCES loans (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE documents (
  id $idType,
  loan_id $textType,
  file_path $textType,
  file_type $textType,
  uploaded_at $textType,
  FOREIGN KEY (loan_id) REFERENCES loans (id) ON DELETE CASCADE
)
''');
  }

  // --- LOAN CRUD ---

  Future<void> insertLoan(Loan loan) async {
    final db = await instance.database;
    await db.insert('loans', loan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Loan>> getAllLoans() async {
    final db = await instance.database;
    final result = await db.query('loans', orderBy: 'created_at DESC');
    return result.map((json) => Loan.fromMap(json)).toList();
  }

  Future<Loan?> getLoanById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'loans',
      columns: ['*'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Loan.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<void> updateLoan(Loan loan) async {
    final db = await instance.database;
    await db.update(
      'loans',
      loan.toMap(),
      where: 'id = ?',
      whereArgs: [loan.id],
    );
  }

  Future<void> deleteLoan(String id) async {
    final db = await instance.database;
    await db.delete(
      'loans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- EMI CRUD ---

  Future<void> insertEmi(Emi emi) async {
    final db = await instance.database;
    await db.insert('emis', emi.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertEmis(List<Emi> emis) async {
    final db = await instance.database;
    Batch batch = db.batch();
    for (var emi in emis) {
      batch.insert('emis', emi.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Emi>> getEmisForLoan(String loanId) async {
    final db = await instance.database;
    final result = await db.query(
      'emis',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'emi_number ASC',
    );
    return result.map((json) => Emi.fromMap(json)).toList();
  }

  Future<List<Emi>> getAllEmis() async {
    final db = await instance.database;
    final result = await db.query('emis', orderBy: 'due_date ASC');
    return result.map((json) => Emi.fromMap(json)).toList();
  }

  Future<List<Emi>> getUpcomingEmis() async {
    final db = await instance.database;
    final now = DateTime.now();
    // Start of today so we include today's EMIs
    final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();
    
    final result = await db.query(
      'emis',
      where: 'status = ? OR (status = ? AND due_date >= ?)',
      whereArgs: [EmiStatus.pending.name, EmiStatus.overdue.name, startOfToday],
      orderBy: 'due_date ASC',
      limit: 10,
    );
    return result.map((json) => Emi.fromMap(json)).toList();
  }
  
  Future<List<Emi>> getEmisBetweenDates(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.query(
        'emis',
        where: 'due_date >= ? AND due_date <= ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
        orderBy: 'due_date ASC'
    );
    return result.map((json) => Emi.fromMap(json)).toList();
  }

  Future<void> updateEmi(Emi emi) async {
    final db = await instance.database;
    await db.update(
      'emis',
      emi.toMap(),
      where: 'id = ?',
      whereArgs: [emi.id],
    );
  }

  Future<void> deleteUnpaidEmisForLoan(String loanId) async {
    final db = await instance.database;
    await db.delete(
      'emis',
      where: 'loan_id = ? AND status != ?',
      whereArgs: [loanId, EmiStatus.paid.name],
    );
  }

  // --- DOCUMENT CRUD ---

  Future<void> insertDocument(Document doc) async {
    final db = await instance.database;
    await db.insert('documents', doc.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Document>> getDocumentsForLoan(String loanId) async {
    final db = await instance.database;
    final result = await db.query(
      'documents',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'uploaded_at DESC',
    );
    return result.map((json) => Document.fromMap(json)).toList();
  }
  
  Future<void> deleteDocument(String id) async {
    final db = await instance.database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
