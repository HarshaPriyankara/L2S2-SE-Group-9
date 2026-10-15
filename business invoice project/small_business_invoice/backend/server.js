require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'small_business_invoice',
  dateStrings: true, // DATE columns come back as 'YYYY-MM-DD' text
  connectionLimit: 10,
});

const app = express();
app.use(cors());
app.use(express.json());

// ---------------------------------------------------------------- helpers

// DB row (snake_case)  ->  JSON the Flutter app expects (camelCase)
const toCategory = (r) => ({
  id: r.category_id,
  name: r.name,
  iconIndex: r.icon_index,
  colorIndex: r.color_index,
});

const toExpense = (r) => ({
  id: r.expense_id,
  title: r.title,
  categoryId: r.category_id,
  amount: Number(r.amount),
  date: r.expense_date,
  paymentMethod: r.payment_method,
  note: r.note || '',
});

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// Wraps async route handlers so errors are turned into JSON responses.
const route = (fn) => (req, res) => {
  fn(req, res).catch((err) => {
    if (err instanceof HttpError) {
      return res.status(err.status).json({ error: err.message });
    }
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'This category already exists' });
    }
    if (err.code === 'ER_ROW_IS_REFERENCED_2') {
      return res.status(409).json({
        error: 'This category is used by expenses and cannot be deleted',
      });
    }
    if (err.code === 'ER_NO_REFERENCED_ROW_2') {
      return res.status(400).json({ error: 'Invalid category' });
    }
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  });
};

function readCategory(body) {
  const name = String(body.name || '').trim();
  if (!name || name.length > 60) {
    throw new HttpError(400, 'Category name is required (max 60 characters)');
  }
  return [name, Number(body.iconIndex) || 0, Number(body.colorIndex) || 0];
}

function readExpense(body) {
  const title = String(body.title || '').trim();
  const categoryId = Number(body.categoryId);
  const amount = Number(body.amount);
  const date = String(body.date || '');
  const paymentMethod = String(body.paymentMethod || '').trim();
  const note = String(body.note || '').trim();

  if (!title || title.length > 120) {
    throw new HttpError(400, 'Title is required (max 120 characters)');
  }
  if (!Number.isInteger(categoryId) || categoryId <= 0) {
    throw new HttpError(400, 'Category is required');
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpError(400, 'Amount must be greater than 0');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new HttpError(400, 'Date must be in YYYY-MM-DD format');
  }
  if (!paymentMethod || paymentMethod.length > 30) {
    throw new HttpError(400, 'Payment method is required');
  }
  return [title, categoryId, amount, date, paymentMethod, note || null];
}

const CATEGORY_SELECT =
  'SELECT category_id, name, icon_index, color_index FROM expense_categories';
const EXPENSE_SELECT =
  'SELECT expense_id, title, category_id, amount, expense_date, payment_method, note FROM expenses';

// ------------------------------------------------------------------ routes

app.get('/api/health', route(async (req, res) => {
  await pool.query('SELECT 1');
  res.json({ status: 'ok' });
}));

// ---- categories
app.get('/api/categories', route(async (req, res) => {
  const [rows] = await pool.query(`${CATEGORY_SELECT} ORDER BY category_id`);
  res.json(rows.map(toCategory));
}));

app.post('/api/categories', route(async (req, res) => {
  const values = readCategory(req.body);
  const [result] = await pool.execute(
    'INSERT INTO expense_categories (name, icon_index, color_index) VALUES (?, ?, ?)',
    values
  );
  const [rows] = await pool.execute(`${CATEGORY_SELECT} WHERE category_id = ?`, [
    result.insertId,
  ]);
  res.status(201).json(toCategory(rows[0]));
}));

app.put('/api/categories/:id', route(async (req, res) => {
  const values = readCategory(req.body);
  await pool.execute(
    'UPDATE expense_categories SET name = ?, icon_index = ?, color_index = ? WHERE category_id = ?',
    [...values, req.params.id]
  );
  const [rows] = await pool.execute(`${CATEGORY_SELECT} WHERE category_id = ?`, [
    req.params.id,
  ]);
  if (rows.length === 0) throw new HttpError(404, 'Category not found');
  res.json(toCategory(rows[0]));
}));

app.delete('/api/categories/:id', route(async (req, res) => {
  const [result] = await pool.execute(
    'DELETE FROM expense_categories WHERE category_id = ?',
    [req.params.id]
  );
  if (result.affectedRows === 0) throw new HttpError(404, 'Category not found');
  res.status(204).end();
}));

// ---- expenses
app.get('/api/expenses', route(async (req, res) => {
  const [rows] = await pool.query(
    `${EXPENSE_SELECT} ORDER BY expense_date DESC, expense_id DESC`
  );
  res.json(rows.map(toExpense));
}));

app.post('/api/expenses', route(async (req, res) => {
  const values = readExpense(req.body);
  const [result] = await pool.execute(
    `INSERT INTO expenses
       (title, category_id, amount, expense_date, payment_method, note)
     VALUES (?, ?, ?, ?, ?, ?)`,
    values
  );
  const [rows] = await pool.execute(`${EXPENSE_SELECT} WHERE expense_id = ?`, [
    result.insertId,
  ]);
  res.status(201).json(toExpense(rows[0]));
}));

app.put('/api/expenses/:id', route(async (req, res) => {
  const values = readExpense(req.body);
  await pool.execute(
    `UPDATE expenses
        SET title = ?, category_id = ?, amount = ?, expense_date = ?,
            payment_method = ?, note = ?
      WHERE expense_id = ?`,
    [...values, req.params.id]
  );
  const [rows] = await pool.execute(`${EXPENSE_SELECT} WHERE expense_id = ?`, [
    req.params.id,
  ]);
  if (rows.length === 0) throw new HttpError(404, 'Expense not found');
  res.json(toExpense(rows[0]));
}));

app.delete('/api/expenses/:id', route(async (req, res) => {
  const [result] = await pool.execute(
    'DELETE FROM expenses WHERE expense_id = ?',
    [req.params.id]
  );
  if (result.affectedRows === 0) throw new HttpError(404, 'Expense not found');
  res.status(204).end();
}));

// ------------------------------------------------------------------- start

const port = Number(process.env.PORT) || 3000;
app.listen(port, async () => {
  console.log(`API running on http://localhost:${port}`);
  try {
    await pool.query('SELECT 1');
    console.log('MySQL connection OK');
  } catch (err) {
    console.error('MySQL connection FAILED:', err.message);
  }
});
