import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('easybill.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Store Table
    await db.execute('''
      CREATE TABLE Store (
        StoreID INTEGER PRIMARY KEY AUTOINCREMENT,
        StoreName TEXT NOT NULL,
        StoreLogo TEXT
      )
    ''');

    // 2. Categories Table
    await db.execute('''
      CREATE TABLE Categories (
        CategoryID INTEGER PRIMARY KEY AUTOINCREMENT,
        CategoryName TEXT UNIQUE NOT NULL
      )
    ''');

    // 3. Suppliers Table
    await db.execute('''
      CREATE TABLE Suppliers (
        SupplierID INTEGER PRIMARY KEY AUTOINCREMENT,
        SupplierName TEXT NOT NULL,
        SupplierCompany TEXT,
        ContactNumber TEXT
      )
    ''');

    // 4. Customers Table
    await db.execute('''
      CREATE TABLE Customers (
        CustomerID INTEGER PRIMARY KEY AUTOINCREMENT,
        CustomerName TEXT NOT NULL,
        Email TEXT,
        ContactNumber TEXT UNIQUE
      )
    ''');

    // 5. Products Table
    await db.execute('''
      CREATE TABLE Products (
        ProductID INTEGER PRIMARY KEY AUTOINCREMENT,
        ProductName TEXT NOT NULL,
        CategoryID INTEGER,
        SupplierID INTEGER,
        StockQuantity REAL DEFAULT 0,
        MinimumStock REAL DEFAULT 0,
        SupplierPrice REAL DEFAULT 0.00 CHECK (SupplierPrice >= 0),
        NormalPrice REAL DEFAULT 0.00 CHECK (NormalPrice >= 0),
        OurPrice REAL DEFAULT 0.00 CHECK (OurPrice >= 0),
        FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID) ON DELETE SET NULL,
        FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID) ON DELETE SET NULL
      )
    ''');

    // 6. Sales Table
    await db.execute('''
      CREATE TABLE Sales (
        BillID INTEGER PRIMARY KEY AUTOINCREMENT,
        BillDate TEXT DEFAULT CURRENT_TIMESTAMP,
        CustomerID INTEGER,
        TotalAmount REAL DEFAULT 0.00,
        TotalDiscount REAL DEFAULT 0.00,
        CashReceived REAL DEFAULT 0.00,
        Balance REAL DEFAULT 0.00,
        CashierName TEXT,
        IsVoided INTEGER DEFAULT 0,
        PaymentType TEXT DEFAULT 'CASH' CHECK(PaymentType IN ('CASH', 'CARD')),
        FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE SET NULL
      )
    ''');

    // 7. SaleItems Table
    await db.execute('''
      CREATE TABLE SaleItems (
        SaleItemID INTEGER PRIMARY KEY AUTOINCREMENT,
        BillID INTEGER,
        ProductID INTEGER,
        Quantity REAL,
        UnitPrice REAL,
        SubTotal REAL,
        FOREIGN KEY (BillID) REFERENCES Sales(BillID) ON DELETE CASCADE,
        FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE RESTRICT
      )
    ''');

    // 8. Expenses Table 
    await db.execute('''
      CREATE TABLE Expenses (
        ExpenseID INTEGER PRIMARY KEY AUTOINCREMENT,
        Title TEXT NOT NULL,
        Category TEXT,
        Amount REAL DEFAULT 0.00 CHECK (Amount >= 0),
        Date TEXT DEFAULT CURRENT_TIMESTAMP,
        Note TEXT,
        AddedBy TEXT
      )
    ''');

    // 9. Users Table
    await db.execute('''
      CREATE TABLE Users (
        UserID INTEGER PRIMARY KEY AUTOINCREMENT,
        FullName TEXT,
        Username TEXT UNIQUE,
        Password TEXT,
        UserRole TEXT
      )
    ''');

    await _seedDefaultData(db);
  }

  Future<void> _seedDefaultData(Database db) async {
    // Default Users
    await db.rawInsert('''
      INSERT OR IGNORE INTO Users (UserID, FullName, Username, Password, UserRole) 
      VALUES (1, 'Saman', 'Admin', '123', 'Admin')
    ''');
    await db.rawInsert('''
      INSERT OR IGNORE INTO Users (UserID, FullName, Username, Password, UserRole) 
      VALUES (2, 'Kumara', 'Cashier', '123', 'Cashier')
    ''');

    // Default Category
    await db.rawInsert('''
      INSERT OR IGNORE INTO Categories (CategoryID, CategoryName) 
      VALUES (1, 'General Category')
    ''');

    // Default Supplier
    await db.rawInsert('''
      INSERT OR IGNORE INTO Suppliers (SupplierID, SupplierName, SupplierCompany, ContactNumber) 
      VALUES (1, 'General Supplier', 'General', '')
    ''');

    // Default Customer
    await db.rawInsert('''
      INSERT OR IGNORE INTO Customers (CustomerID, CustomerName, ContactNumber) 
      VALUES (1, 'Cash Customer', '')
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
  Future<Map<String, dynamic>?> loginUser(String username, String password) async {
  final db = await instance.database;
  
  final result = await db.query(
    'Users',
    where: 'Username = ? AND Password = ?',
    whereArgs: [username, password],
  );

  if (result.isNotEmpty) {
    return result.first; 
  } else {
    return null; 
  }
  }
  //-----------------------------------------------------------------------------------
  // Customer CRUD Operations
  // 1.Get all customers
Future<List<Map<String, dynamic>>> getCustomers() async {
  final db = await instance.database;
  return await db.query('Customers', orderBy: 'CustomerID DESC');
}

// 2.Add new customer
Future<int> insertCustomer(Map<String, dynamic> row) async {
  final db = await instance.database;
  return await db.insert('Customers', row);
}

// 3. Customer Update
Future<int> updateCustomer(Map<String, dynamic> row) async {
  final db = await instance.database;

  return await db.update(
    'Customers',
    {
      'CustomerName': row['CustomerName'],
      'Email': row['Email'],
      'ContactNumber': row['ContactNumber'],
    },
    where: 'CustomerID = ?',
    whereArgs: [row['CustomerID']],
  );
}

// 4. Customer Delete
Future<int> deleteCustomer(int id) async {
  if (id == 1) return 0; // Default customer protect
  final db = await instance.database;
  return await db.delete('Customers', where: 'CustomerID = ?', whereArgs: [id]);
}

//-----------------------------------------------------------------------------------
//User CRUD Operations
// 1. Get all Users
Future<List<Map<String, dynamic>>> getUsers() async {
  final db = await instance.database;
  return await db.query('Users', orderBy: 'UserID DESC');
}

// 2. Insert new User
Future<int> insertUser(Map<String, dynamic> row) async {
  final db = await instance.database;
  return await db.insert('Users', row);
}

// 3. Update User
Future<int> updateUser(Map<String, dynamic> row) async {
  final db = await instance.database;
  final String id = row['UserID'].toString();

  return await db.update(
    'Users',
    {
      'FullName': row['FullName']?.toString(),
      'Username': row['Username']?.toString(),
      'Password': row['Password']?.toString(),
      'UserRole': row['UserRole']?.toString(),
    },
    where: 'UserID = ?',
    whereArgs: [id],
  );
}

// 4. Delete User
Future<int> deleteUser(int id) async {
  if (id == 1 || id == 2) return 0; // Default users protect
  final db = await instance.database;
  return await db.delete('Users', where: 'UserID = ?', whereArgs: [id.toString()]);
}

//-----------------------------------------------------------------------------------
// Supplier CRUD Operations
// 1. Get all suppliers
Future<List<Map<String, dynamic>>> getSuppliers() async {
  final db = await instance.database;
  return await db.query('Suppliers', orderBy: 'SupplierID DESC');
}

// 2. Insert new supplier
Future<int> insertSupplier(Map<String, dynamic> row) async {
  final db = await instance.database;
  return await db.insert('Suppliers', row);
}

// 3. Update supplier
Future<int> updateSupplier(Map<String, dynamic> row) async {
  final db = await instance.database;
  return await db.update(
    'Suppliers',
    {
      'SupplierName': row['SupplierName'],
      'SupplierCompany': row['SupplierCompany'],
      'ContactNumber': row['ContactNumber'],
    },
    where: 'SupplierID = ?',
    whereArgs: [row['SupplierID']],
  );
}

// 4. Delete supplier
Future<int> deleteSupplier(int id) async {
  if (id == 1) return 0; // Default supplier protect
  final db = await instance.database;
  return await db.delete('Suppliers', where: 'SupplierID = ?', whereArgs: [id]);
}
}