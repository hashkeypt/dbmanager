-- Oracle Sample Schema for Development
-- DBM Project - Sample Data for Testing Permissions and Metrics

-- Drop existing objects if they exist
BEGIN
    -- Drop views
    FOR i IN (SELECT view_name FROM user_views WHERE view_name IN ('VW_CUSTOMER_ORDERS', 'VW_PRODUCT_INVENTORY')) LOOP
        EXECUTE IMMEDIATE 'DROP VIEW ' || i.view_name;
    END LOOP;
    
    -- Drop tables
    FOR i IN (SELECT table_name FROM user_tables WHERE table_name IN ('ORDER_ITEMS', 'ORDERS', 'PRODUCTS', 'CUSTOMERS', 'EMPLOYEES')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || i.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
    
    -- Drop sequences
    FOR i IN (SELECT sequence_name FROM user_sequences WHERE sequence_name LIKE '%_SEQ') LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || i.sequence_name;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- Create sequences for auto-increment IDs
CREATE SEQUENCE customers_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE products_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE orders_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE order_items_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE employees_seq START WITH 1 INCREMENT BY 1;

-- 1. Customers table
CREATE TABLE customers (
    id NUMBER PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    email VARCHAR2(150) UNIQUE NOT NULL,
    telefone VARCHAR2(20),
    data_cadastro DATE DEFAULT SYSDATE NOT NULL
);

-- 2. Products table
CREATE TABLE products (
    id NUMBER PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    descricao VARCHAR2(500),
    preco NUMBER(10,2) NOT NULL CHECK (preco >= 0),
    estoque NUMBER DEFAULT 0 CHECK (estoque >= 0)
);

-- 3. Orders table
CREATE TABLE orders (
    id NUMBER PRIMARY KEY,
    customer_id NUMBER NOT NULL,
    data_pedido DATE DEFAULT SYSDATE NOT NULL,
    valor_total NUMBER(10,2) DEFAULT 0 CHECK (valor_total >= 0),
    status VARCHAR2(20) DEFAULT 'PENDENTE' CHECK (status IN ('PENDENTE', 'PROCESSANDO', 'ENVIADO', 'ENTREGUE', 'CANCELADO'))
);

-- 4. Order items table
CREATE TABLE order_items (
    id NUMBER PRIMARY KEY,
    order_id NUMBER NOT NULL,
    product_id NUMBER NOT NULL,
    quantidade NUMBER NOT NULL CHECK (quantidade > 0),
    preco_unitario NUMBER(10,2) NOT NULL CHECK (preco_unitario >= 0)
);

-- 5. Employees table
CREATE TABLE employees (
    id NUMBER PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    cargo VARCHAR2(50) NOT NULL,
    departamento VARCHAR2(50) NOT NULL,
    salario NUMBER(10,2) CHECK (salario > 0),
    data_admissao DATE DEFAULT SYSDATE NOT NULL
);

-- Add foreign key constraints
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer 
    FOREIGN KEY (customer_id) REFERENCES customers(id);

ALTER TABLE order_items ADD CONSTRAINT fk_order_items_order 
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;

ALTER TABLE order_items ADD CONSTRAINT fk_order_items_product 
    FOREIGN KEY (product_id) REFERENCES products(id);

-- Create triggers for auto-increment IDs
CREATE OR REPLACE TRIGGER customers_bi
BEFORE INSERT ON customers
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT customers_seq.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER products_bi
BEFORE INSERT ON products
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT products_seq.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER orders_bi
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT orders_seq.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER order_items_bi
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT order_items_seq.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER employees_bi
BEFORE INSERT ON employees
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT employees_seq.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

-- Insert sample data

-- Customers
INSERT INTO customers (nome, email, telefone, data_cadastro) VALUES 
    ('João Silva', 'joao.silva@email.com', '11987654321', DATE '2024-01-15');
INSERT INTO customers (nome, email, telefone, data_cadastro) VALUES 
    ('Maria Santos', 'maria.santos@email.com', '11976543210', DATE '2024-02-20');
INSERT INTO customers (nome, email, telefone, data_cadastro) VALUES 
    ('Pedro Oliveira', 'pedro.oliveira@email.com', '11965432109', DATE '2024-03-10');
INSERT INTO customers (nome, email, telefone, data_cadastro) VALUES 
    ('Ana Costa', 'ana.costa@email.com', '11954321098', DATE '2024-04-05');
INSERT INTO customers (nome, email, telefone, data_cadastro) VALUES 
    ('Carlos Ferreira', 'carlos.ferreira@email.com', '11943210987', DATE '2024-05-12');

-- Products
INSERT INTO products (nome, descricao, preco, estoque) VALUES 
    ('Notebook Dell', 'Notebook Dell Inspiron 15, Intel i7, 16GB RAM, 512GB SSD', 4599.90, 25);
INSERT INTO products (nome, descricao, preco, estoque) VALUES 
    ('Mouse Logitech', 'Mouse sem fio Logitech MX Master 3', 549.90, 150);
INSERT INTO products (nome, descricao, preco, estoque) VALUES 
    ('Teclado Mecânico', 'Teclado mecânico RGB Cherry MX', 899.90, 80);
INSERT INTO products (nome, descricao, preco, estoque) VALUES 
    ('Monitor LG', 'Monitor LG UltraWide 29" IPS', 1899.90, 45);
INSERT INTO products (nome, descricao, preco, estoque) VALUES 
    ('Webcam HD', 'Webcam Full HD 1080p com microfone', 299.90, 200);
INSERT INTO products (nome, descricao, preco, estoque) VALUES 
    ('Headset Gamer', 'Headset Gamer 7.1 Surround com LED', 399.90, 120);
INSERT INTO products (nome, descricao, preco, estoque) VALUES 
    ('SSD 1TB', 'SSD NVMe M.2 1TB de alta velocidade', 799.90, 90);
INSERT INTO products (nome, descricao, preco, estoque) VALUES 
    ('Cadeira Gamer', 'Cadeira Gamer ergonômica com apoio lombar', 1299.90, 30);

-- Employees
INSERT INTO employees (nome, cargo, departamento, salario, data_admissao) VALUES 
    ('Fernando Alves', 'Gerente de Vendas', 'Vendas', 8500.00, DATE '2023-01-10');
INSERT INTO employees (nome, cargo, departamento, salario, data_admissao) VALUES 
    ('Juliana Martins', 'Analista de TI', 'TI', 6500.00, DATE '2023-03-15');
INSERT INTO employees (nome, cargo, departamento, salario, data_admissao) VALUES 
    ('Roberto Lima', 'Vendedor', 'Vendas', 3500.00, DATE '2023-06-01');
INSERT INTO employees (nome, cargo, departamento, salario, data_admissao) VALUES 
    ('Camila Rocha', 'Analista de RH', 'RH', 5500.00, DATE '2023-08-20');
INSERT INTO employees (nome, cargo, departamento, salario, data_admissao) VALUES 
    ('Lucas Mendes', 'Desenvolvedor Senior', 'TI', 9500.00, DATE '2022-11-10');
INSERT INTO employees (nome, cargo, departamento, salario, data_admissao) VALUES 
    ('Patricia Souza', 'Contadora', 'Financeiro', 7000.00, DATE '2023-02-01');

-- Orders
INSERT INTO orders (customer_id, data_pedido, valor_total, status) VALUES 
    (1, DATE '2024-06-01', 5149.80, 'ENTREGUE');
INSERT INTO orders (customer_id, data_pedido, valor_total, status) VALUES 
    (2, DATE '2024-06-05', 899.90, 'ENTREGUE');
INSERT INTO orders (customer_id, data_pedido, valor_total, status) VALUES 
    (3, DATE '2024-06-10', 2199.80, 'ENVIADO');
INSERT INTO orders (customer_id, data_pedido, valor_total, status) VALUES 
    (1, DATE '2024-06-12', 1099.80, 'PROCESSANDO');
INSERT INTO orders (customer_id, data_pedido, valor_total, status) VALUES 
    (4, DATE '2024-06-15', 1899.90, 'PENDENTE');
INSERT INTO orders (customer_id, data_pedido, valor_total, status) VALUES 
    (5, DATE '2024-06-18', 3999.60, 'ENVIADO');

-- Order items
-- Order 1
INSERT INTO order_items (order_id, product_id, quantidade, preco_unitario) VALUES 
    (1, 1, 1, 4599.90);
INSERT INTO order_items (order_id, product_id, quantidade, preco_unitario) VALUES 
    (1, 2, 1, 549.90);

-- Order 2
INSERT INTO order_items (order_id, product_id, quantidade, preco_unitario) VALUES 
    (2, 3, 1, 899.90);

-- Order 3
INSERT INTO order_items (order_id, product_id, quantidade, preco_unitario) VALUES 
    (3, 4, 1, 1899.90);
INSERT INTO order_items (order_id, product_id, quantidade, preco_unitario) VALUES 
    (3, 5, 1, 299.90);

-- Order 4
INSERT INTO order_items (order_id, product_id, quantidade, preco_unitario) VALUES 
    (4, 2, 2, 549.90);

-- Order 5
INSERT INTO order_items (order_id, product_id, quantidade, preco_unitario) VALUES 
    (5, 4, 1, 1899.90);

-- Order 6
INSERT INTO order_items (order_id, product_id, quantidade, preco_unitario) VALUES 
    (6, 7, 2, 799.90);
INSERT INTO order_items (order_id, product_id, quantidade, preco_unitario) VALUES 
    (6, 6, 1, 399.90);
INSERT INTO order_items (order_id, product_id, quantidade, preco_unitario) VALUES 
    (6, 8, 1, 1299.90);
INSERT INTO order_items (order_id, product_id, quantidade, preco_unitario) VALUES 
    (6, 5, 2, 299.90);

-- Create useful indexes
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_data_cadastro ON customers(data_cadastro);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_data_pedido ON orders(data_pedido);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_products_nome ON products(nome);
CREATE INDEX idx_products_preco ON products(preco);
CREATE INDEX idx_employees_departamento ON employees(departamento);
CREATE INDEX idx_employees_cargo ON employees(cargo);

-- Create views

-- View 1: Customer orders summary
CREATE OR REPLACE VIEW vw_customer_orders AS
SELECT 
    c.id AS customer_id,
    c.nome AS customer_nome,
    c.email AS customer_email,
    COUNT(DISTINCT o.id) AS total_pedidos,
    SUM(o.valor_total) AS valor_total_gasto,
    MAX(o.data_pedido) AS ultimo_pedido,
    MIN(o.data_pedido) AS primeiro_pedido
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.nome, c.email;

-- View 2: Product inventory status
CREATE OR REPLACE VIEW vw_product_inventory AS
SELECT 
    p.id AS product_id,
    p.nome AS product_nome,
    p.preco AS preco_atual,
    p.estoque AS estoque_atual,
    COUNT(oi.id) AS vezes_vendido,
    SUM(oi.quantidade) AS quantidade_vendida,
    SUM(oi.quantidade * oi.preco_unitario) AS receita_total,
    CASE 
        WHEN p.estoque = 0 THEN 'SEM ESTOQUE'
        WHEN p.estoque < 10 THEN 'ESTOQUE BAIXO'
        WHEN p.estoque < 50 THEN 'ESTOQUE MÉDIO'
        ELSE 'ESTOQUE ALTO'
    END AS status_estoque
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
GROUP BY p.id, p.nome, p.preco, p.estoque;

-- Commit all changes
COMMIT;

-- Display summary
SELECT 'Tables created: ' || COUNT(*) || ' tables' AS summary FROM user_tables WHERE table_name IN ('CUSTOMERS', 'PRODUCTS', 'ORDERS', 'ORDER_ITEMS', 'EMPLOYEES');
SELECT 'Total customers: ' || COUNT(*) AS count FROM customers;
SELECT 'Total products: ' || COUNT(*) AS count FROM products;
SELECT 'Total orders: ' || COUNT(*) AS count FROM orders;
SELECT 'Total employees: ' || COUNT(*) AS count FROM employees;
SELECT 'Indexes created: ' || COUNT(*) || ' indexes' AS summary FROM user_indexes WHERE index_name LIKE 'IDX_%';
SELECT 'Views created: ' || COUNT(*) || ' views' AS summary FROM user_views WHERE view_name LIKE 'VW_%';