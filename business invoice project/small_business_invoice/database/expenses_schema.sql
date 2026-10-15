-- MySQL schema for the Expenses module
-- (matches the fields used in lib/models/expense.dart)

CREATE DATABASE IF NOT EXISTS small_business_invoice;
USE small_business_invoice;

CREATE TABLE IF NOT EXISTS expense_categories (
  category_id  INT AUTO_INCREMENT PRIMARY KEY,
  name         VARCHAR(60)  NOT NULL UNIQUE,
  icon_index   INT          NOT NULL DEFAULT 0,
  color_index  INT          NOT NULL DEFAULT 0,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS expenses (
  expense_id      INT AUTO_INCREMENT PRIMARY KEY,
  title           VARCHAR(120)  NOT NULL,
  category_id     INT           NOT NULL,
  amount          DECIMAL(12,2) NOT NULL CHECK (amount > 0),
  expense_date    DATE          NOT NULL,
  payment_method  VARCHAR(30)   NOT NULL,
  note            TEXT          NULL,
  created_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_expense_category
    FOREIGN KEY (category_id) REFERENCES expense_categories(category_id)
    ON DELETE RESTRICT
);

INSERT IGNORE INTO expense_categories (name, icon_index, color_index) VALUES
  ('Rent', 0, 0), ('Utilities', 1, 2), ('Salaries', 2, 1),
  ('Supplies', 3, 3), ('Transport', 4, 5), ('Marketing', 5, 6), ('Other', 6, 7);
