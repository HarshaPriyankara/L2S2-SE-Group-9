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
      version: 3, // 2 -> 3 (SaleItems.NormalPrice)
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
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
        NormalPrice REAL,
        UnitPrice REAL,
        SubTotal REAL,
        FOREIGN KEY (BillID) REFERENCES Sales(BillID) ON DELETE CASCADE,
        FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE RESTRICT
      )
    ''');

    // 8. Expense Categories + Expenses
    await _createExpenseTables(db);

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

  Future<void> _createExpenseTables(Database db) async {
    // Expense Categories Table
    await db.execute('''
      CREATE TABLE ExpenseCategories (
        ExCatID INTEGER PRIMARY KEY AUTOINCREMENT,
        ExCatName TEXT NOT NULL
      )
    ''');

    // Expenses Table
    await db.execute('''
      CREATE TABLE Expenses (
        ExID INTEGER PRIMARY KEY AUTOINCREMENT,
        ExpenseDate TEXT,
        Amount REAL DEFAULT 0.00,
        PaymentType TEXT DEFAULT 'CASH' CHECK(PaymentType IN ('CASH','CARD','BANK_TRANSFER','CHEQUE')),
        Notes TEXT,
        CreatedAt TEXT DEFAULT CURRENT_TIMESTAMP,
        UpdatedAt TEXT DEFAULT CURRENT_TIMESTAMP,
        SupplierID INTEGER,
        ExCatID INTEGER,
        FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID) ON DELETE SET NULL,
        FOREIGN KEY (ExCatID) REFERENCES ExpenseCategories(ExCatID) ON DELETE SET NULL
      )
    ''');
  }

  // Already install karapu app walata (version 1 -> 2)
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS Expenses');
      await _createExpenseTables(db);
    }
    if (oldVersion < 3) {
      // Old invoices: normal price = unit price (no discount info was saved)
      await db.execute('ALTER TABLE SaleItems ADD COLUMN NormalPrice REAL');
      await db.execute('UPDATE SaleItems SET NormalPrice = UnitPrice');
    }
  }

  Future<void> _seedDefaultData(Database db) async {
    // Default Users
    await db.rawInsert('''
      INSERT OR IGNORE INTO Users (UserID, FullName, Username, Password, UserRole) 
      VALUES (1, 'Default Admin', 'Admin', '123', 'Admin')
    ''');
    await db.rawInsert('''
      INSERT OR IGNORE INTO Users (UserID, FullName, Username, Password, UserRole) 
      VALUES (2, 'Default Cashier', 'Cashier', '123', 'Cashier')
    ''');

    // Default Category
    await db.rawInsert('''
      INSERT OR IGNORE INTO Categories (CategoryID, CategoryName) 
      VALUES (1, 'Default Category')
    ''');

    // Default Supplier
    await db.rawInsert('''
      INSERT OR IGNORE INTO Suppliers (SupplierID, SupplierName, SupplierCompany, ContactNumber) 
      VALUES (1, 'Default Supplier', 'Default Company', '')
    ''');

    // Default Customer
    await db.rawInsert('''
      INSERT OR IGNORE INTO Customers (CustomerID, CustomerName, ContactNumber) 
      VALUES (1, 'Default Customer', '')
    ''');

    // Default Expense Category
    await db.rawInsert('''
      INSERT OR IGNORE INTO ExpenseCategories (ExCatID, ExCatName) 
      VALUES (1, 'Default Expense')
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

  //-----------------------------------------------------------------------------------
  // Product CRUD Operations
  // 1. Get all Products with Category & Supplier details
  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT P.*, C.CategoryName, S.SupplierName
      FROM Products P
      LEFT JOIN Categories C ON P.CategoryID = C.CategoryID
      LEFT JOIN Suppliers S ON P.SupplierID = S.SupplierID
      ORDER BY P.ProductID DESC
    ''');
  }

  // 2. Insert new Product
  Future<int> insertProduct(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('Products', row);
  }

  // 3. Update Product
  Future<int> updateProduct(Map<String, dynamic> row) async {
    final db = await instance.database;
    final String id = row['ProductID'].toString();

    return await db.update(
      'Products',
      {
        'ProductName': row['ProductName']?.toString(),
        'CategoryID': row['CategoryID'],
        'SupplierID': row['SupplierID'],
        'StockQuantity': row['StockQuantity'],
        'MinimumStock': row['MinimumStock'],
        'SupplierPrice': row['SupplierPrice'],
        'NormalPrice': row['NormalPrice'],
        'OurPrice': row['OurPrice'],
      },
      where: 'ProductID = ?',
      whereArgs: [id],
    );
  }

  // 4. Delete Product
  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete('Products', where: 'ProductID = ?', whereArgs: [id.toString()]);
  }

  // 5. Get Categories for Dropdown
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await instance.database;
    return await db.query('Categories', orderBy: 'CategoryName ASC');
  }

  // 6. Add new Category
  Future<int> insertCategory(String name) async {
    final db = await instance.database;
    return await db.insert('Categories', {'CategoryName': name});
  }

  // 7. Delete Category (default category protect)
  Future<int> deleteCategory(int id) async {
    if (id == 1) return 0;
    final db = await instance.database;
    return await db.delete('Categories', where: 'CategoryID = ?', whereArgs: [id]);
  }

  // 8. Adjust stock (+ add / - remove)
  Future<int> adjustStock(int id, double qty) async {
    final db = await instance.database;
    return await db.rawUpdate(
      'UPDATE Products SET StockQuantity = StockQuantity + ? WHERE ProductID = ?',
      [qty, id],
    );
  }

  // -----------------------------------------------------------------------------------
  // Invoice Operations

  // 1. add new Invoice and reduce stock from inventory
  Future<int> insertSale(Map<String, dynamic> saleData, List<Map<String, dynamic>> items) async {
    final db = await instance.database;
    int billId = 0;

    await db.transaction((txn) async {
      // stock check (race / negative stock protect)
      for (final item in items) {
        final r = await txn.rawQuery(
          'SELECT StockQuantity FROM Products WHERE ProductID = ?',
          [item['ProductID']],
        );
        final stock = (r.first['StockQuantity'] as num?)?.toDouble() ?? 0;
        if (stock < (item['Quantity'] as num).toDouble()) {
          throw Exception('Not enough stock for ${item['ProductName']}');
        }
      }

      billId = await txn.insert('Sales', saleData);

      for (final item in items) {
        await txn.insert('SaleItems', {
          'BillID': billId,
          'ProductID': item['ProductID'],
          'Quantity': item['Quantity'],
          'NormalPrice': item['NormalPrice'],
          'UnitPrice': item['UnitPrice'],
          'SubTotal': item['SubTotal'],
        });

        await txn.rawUpdate(
          'UPDATE Products SET StockQuantity = StockQuantity - ? WHERE ProductID = ?',
          [item['Quantity'], item['ProductID']],
        );
      }
    });

    return billId;
  }

  // 2. get all sales
  Future<List<Map<String, dynamic>>> getSales() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT S.*, C.CustomerName 
      FROM Sales S
      LEFT JOIN Customers C ON S.CustomerID = C.CustomerID
      ORDER BY S.BillID DESC
    ''');
  }

  // 3. get sale details for PDF generation
  Future<Map<String, dynamic>?> getSaleDetails(int billId) async {
    final db = await instance.database;

    final sales = await db.rawQuery('''
      SELECT S.*, C.CustomerName, C.ContactNumber, C.Email
      FROM Sales S
      LEFT JOIN Customers C ON S.CustomerID = C.CustomerID
      WHERE S.BillID = ?
    ''', [billId]);

    if (sales.isEmpty) return null;

    final items = await db.rawQuery('''
      SELECT SI.*, P.ProductName
      FROM SaleItems SI
      LEFT JOIN Products P ON SI.ProductID = P.ProductID
      WHERE SI.BillID = ?
    ''', [billId]);

    final store = await db.query('Store', limit: 1);

    return {
      'sale': sales.first,
      'items': items,
      'store': store.isNotEmpty ? store.first : {'StoreName': 'EasyBill POS'},
    };
  }
}