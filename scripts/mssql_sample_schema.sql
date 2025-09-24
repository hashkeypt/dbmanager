-- SQL Server Sample Schema for Development
-- This script creates sample tables with data for testing DBM features

-- Set required options
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- Create schemas
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'sales')
    EXEC('CREATE SCHEMA sales');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'hr')
    EXEC('CREATE SCHEMA hr');
GO

-- Drop tables if they exist (in correct order due to foreign keys)
IF OBJECT_ID('sales.order_items', 'U') IS NOT NULL
    DROP TABLE sales.order_items;
GO

IF OBJECT_ID('sales.orders', 'U') IS NOT NULL
    DROP TABLE sales.orders;
GO

IF OBJECT_ID('sales.products', 'U') IS NOT NULL
    DROP TABLE sales.products;
GO

IF OBJECT_ID('dbo.customers', 'U') IS NOT NULL
    DROP TABLE dbo.customers;
GO

IF OBJECT_ID('hr.employees', 'U') IS NOT NULL
    DROP TABLE hr.employees;
GO

-- 1. Create customers table in dbo schema
CREATE TABLE dbo.customers (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nome NVARCHAR(100) NOT NULL,
    email NVARCHAR(150) UNIQUE NOT NULL,
    telefone VARCHAR(20),
    data_cadastro DATETIME2 DEFAULT GETDATE(),
    ativo BIT DEFAULT 1,
    credito_limite DECIMAL(10,2) DEFAULT 0.00
);
GO

-- 2. Create products table in sales schema
CREATE TABLE sales.products (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nome NVARCHAR(200) NOT NULL,
    descricao NVARCHAR(MAX),
    preco DECIMAL(10,2) NOT NULL CHECK (preco >= 0),
    estoque INT NOT NULL DEFAULT 0 CHECK (estoque >= 0),
    categoria NVARCHAR(50),
    data_criacao DATETIME2 DEFAULT GETDATE(),
    ultima_atualizacao DATETIME2 DEFAULT GETDATE()
);
GO

-- 3. Create orders table in sales schema
CREATE TABLE sales.orders (
    id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT NOT NULL,
    data_pedido DATETIME2 DEFAULT GETDATE(),
    valor_total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDENTE',
    observacoes NVARCHAR(500),
    data_entrega DATETIME2,
    CONSTRAINT FK_orders_customer FOREIGN KEY (customer_id) 
        REFERENCES dbo.customers(id),
    CONSTRAINT CK_order_status CHECK (status IN ('PENDENTE', 'PROCESSANDO', 'ENVIADO', 'ENTREGUE', 'CANCELADO'))
);
GO

-- 4. Create order_items table in sales schema
CREATE TABLE sales.order_items (
    id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantidade INT NOT NULL CHECK (quantidade > 0),
    preco_unitario DECIMAL(10,2) NOT NULL CHECK (preco_unitario >= 0),
    desconto DECIMAL(5,2) DEFAULT 0.00 CHECK (desconto >= 0 AND desconto <= 100),
    valor_total AS (quantidade * preco_unitario * (1 - desconto/100.0)) PERSISTED,
    CONSTRAINT FK_order_items_order FOREIGN KEY (order_id) 
        REFERENCES sales.orders(id) ON DELETE CASCADE,
    CONSTRAINT FK_order_items_product FOREIGN KEY (product_id) 
        REFERENCES sales.products(id)
);
GO

-- 5. Create employees table in hr schema
CREATE TABLE hr.employees (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nome NVARCHAR(100) NOT NULL,
    cargo NVARCHAR(50) NOT NULL,
    departamento NVARCHAR(50) NOT NULL,
    salario DECIMAL(10,2) NOT NULL CHECK (salario > 0),
    data_admissao DATE NOT NULL,
    data_demissao DATE,
    email_corporativo AS (LOWER(REPLACE(nome, ' ', '.')) + '@company.com') PERSISTED,
    gestor_id INT,
    CONSTRAINT FK_employee_manager FOREIGN KEY (gestor_id) 
        REFERENCES hr.employees(id)
);
GO

-- Create useful indexes
CREATE NONCLUSTERED INDEX IX_customers_email ON dbo.customers(email);
CREATE NONCLUSTERED INDEX IX_customers_data_cadastro ON dbo.customers(data_cadastro DESC);
CREATE NONCLUSTERED INDEX IX_products_categoria ON sales.products(categoria, preco);
CREATE NONCLUSTERED INDEX IX_orders_customer_date ON sales.orders(customer_id, data_pedido DESC);
CREATE NONCLUSTERED INDEX IX_orders_status ON sales.orders(status) INCLUDE (valor_total);
CREATE NONCLUSTERED INDEX IX_order_items_order ON sales.order_items(order_id);
CREATE NONCLUSTERED INDEX IX_employees_departamento ON hr.employees(departamento, cargo);
GO

-- Insert sample data

-- Customers
INSERT INTO dbo.customers (nome, email, telefone, data_cadastro, credito_limite) VALUES
('João Silva', 'joao.silva@email.com', '11987654321', '2024-01-15', 5000.00),
('Maria Santos', 'maria.santos@email.com', '11976543210', '2024-01-20', 10000.00),
('Pedro Oliveira', 'pedro.oliveira@email.com', '11965432109', '2024-02-01', 7500.00),
('Ana Costa', 'ana.costa@email.com', '11954321098', '2024-02-15', 15000.00),
('Carlos Ferreira', 'carlos.ferreira@email.com', '11943210987', '2024-03-01', 3000.00),
('Lucia Almeida', 'lucia.almeida@email.com', '11932109876', '2024-03-10', 8000.00),
('Roberto Souza', 'roberto.souza@email.com', '11921098765', '2024-03-15', 12000.00),
('Patricia Lima', 'patricia.lima@email.com', '11910987654', '2024-04-01', 6000.00);
GO

-- Products
INSERT INTO sales.products (nome, descricao, preco, estoque, categoria) VALUES
('Notebook Dell Inspiron', 'Notebook com processador Intel Core i5, 8GB RAM, 256GB SSD', 3500.00, 25, 'Eletrônicos'),
('Mouse Logitech MX Master', 'Mouse sem fio ergonômico com tecnologia Darkfield', 450.00, 50, 'Acessórios'),
('Monitor LG 27"', 'Monitor IPS Full HD com ajuste de altura', 1200.00, 15, 'Eletrônicos'),
('Teclado Mecânico Razer', 'Teclado mecânico RGB com switches Cherry MX', 800.00, 30, 'Acessórios'),
('Headset HyperX Cloud', 'Headset gamer com microfone removível', 350.00, 40, 'Acessórios'),
('SSD Samsung 1TB', 'SSD NVMe M.2 com velocidade de leitura 7000MB/s', 600.00, 60, 'Componentes'),
('Webcam Logitech C920', 'Webcam Full HD 1080p com correção automática de luz', 400.00, 35, 'Acessórios'),
('Cadeira Gamer DXRacer', 'Cadeira ergonômica com apoio lombar ajustável', 1500.00, 10, 'Móveis'),
('Mesa para Escritório', 'Mesa em MDF com gavetas e passa-cabos', 800.00, 20, 'Móveis'),
('Impressora HP LaserJet', 'Impressora laser monocromática com Wi-Fi', 1000.00, 12, 'Eletrônicos');
GO

-- Employees
INSERT INTO hr.employees (nome, cargo, departamento, salario, data_admissao, gestor_id) VALUES
('Carlos Mendes', 'Diretor Geral', 'Diretoria', 25000.00, '2020-01-10', NULL),
('Fernanda Costa', 'Gerente de Vendas', 'Vendas', 12000.00, '2020-03-15', 1),
('Ricardo Alves', 'Gerente de TI', 'Tecnologia', 15000.00, '2020-02-20', 1),
('Juliana Santos', 'Vendedor Senior', 'Vendas', 6000.00, '2021-01-05', 2),
('Marcos Lima', 'Vendedor Pleno', 'Vendas', 4500.00, '2021-06-10', 2),
('Beatriz Rocha', 'Desenvolvedor Senior', 'Tecnologia', 8000.00, '2020-08-01', 3),
('Paulo Martins', 'Desenvolvedor Pleno', 'Tecnologia', 6000.00, '2021-03-15', 3),
('Amanda Silva', 'Analista de Suporte', 'Tecnologia', 3500.00, '2022-01-20', 3),
('Diego Ferreira', 'Vendedor Junior', 'Vendas', 3000.00, '2023-02-01', 2),
('Camila Oliveira', 'Desenvolvedor Junior', 'Tecnologia', 4000.00, '2023-03-10', 3);
GO

-- Orders
INSERT INTO sales.orders (customer_id, data_pedido, valor_total, status, observacoes) VALUES
(1, '2024-04-01 10:30:00', 3950.00, 'ENTREGUE', 'Entrega expressa'),
(2, '2024-04-02 14:15:00', 1200.00, 'ENTREGUE', 'Cliente VIP'),
(3, '2024-04-03 09:45:00', 2150.00, 'ENVIADO', 'Envio para o escritório'),
(1, '2024-04-05 16:20:00', 600.00, 'PROCESSANDO', 'Segunda compra do cliente'),
(4, '2024-04-06 11:00:00', 4300.00, 'PENDENTE', 'Aguardando confirmação de pagamento'),
(5, '2024-04-07 13:30:00', 800.00, 'ENTREGUE', NULL),
(6, '2024-04-08 15:45:00', 1500.00, 'CANCELADO', 'Cliente desistiu da compra'),
(7, '2024-04-09 10:00:00', 2400.00, 'ENVIADO', 'Entrega programada'),
(2, '2024-04-10 12:15:00', 1000.00, 'PROCESSANDO', 'Pedido recorrente');
GO

-- Order Items
INSERT INTO sales.order_items (order_id, product_id, quantidade, preco_unitario, desconto) VALUES
-- Order 1
(1, 1, 1, 3500.00, 0),
(1, 2, 1, 450.00, 0),
-- Order 2
(2, 3, 1, 1200.00, 0),
-- Order 3
(3, 4, 1, 800.00, 0),
(3, 5, 1, 350.00, 0),
(3, 10, 1, 1000.00, 0),
-- Order 4
(4, 6, 1, 600.00, 0),
-- Order 5
(5, 1, 1, 3500.00, 5.00),
(5, 4, 1, 800.00, 0),
-- Order 6
(6, 9, 1, 800.00, 0),
-- Order 7
(7, 8, 1, 1500.00, 0),
-- Order 8
(8, 3, 2, 1200.00, 0),
-- Order 9
(9, 10, 1, 1000.00, 0);
GO

-- Create views

-- View 1: Customer order summary
CREATE VIEW dbo.vw_customer_order_summary AS
SELECT 
    c.id AS customer_id,
    c.nome AS customer_name,
    c.email,
    COUNT(DISTINCT o.id) AS total_orders,
    SUM(o.valor_total) AS total_spent,
    MAX(o.data_pedido) AS last_order_date,
    CASE 
        WHEN SUM(o.valor_total) > 10000 THEN 'Premium'
        WHEN SUM(o.valor_total) > 5000 THEN 'Gold'
        WHEN SUM(o.valor_total) > 1000 THEN 'Silver'
        ELSE 'Bronze'
    END AS customer_tier
FROM dbo.customers c
LEFT JOIN sales.orders o ON c.id = o.customer_id
GROUP BY c.id, c.nome, c.email;
GO

-- View 2: Product sales performance
CREATE VIEW sales.vw_product_performance AS
SELECT 
    p.id AS product_id,
    p.nome AS product_name,
    p.categoria,
    p.preco AS current_price,
    p.estoque AS current_stock,
    COUNT(DISTINCT oi.order_id) AS times_ordered,
    SUM(oi.quantidade) AS total_quantity_sold,
    SUM(oi.valor_total) AS total_revenue,
    AVG(oi.desconto) AS avg_discount_given,
    p.estoque * p.preco AS stock_value
FROM sales.products p
LEFT JOIN sales.order_items oi ON p.id = oi.product_id
LEFT JOIN sales.orders o ON oi.order_id = o.id
WHERE o.status != 'CANCELADO' OR o.status IS NULL
GROUP BY p.id, p.nome, p.categoria, p.preco, p.estoque;
GO

-- Create a stored procedure example
CREATE PROCEDURE sales.sp_update_order_total
    @order_id INT
AS
BEGIN
    UPDATE sales.orders
    SET valor_total = (
        SELECT SUM(valor_total)
        FROM sales.order_items
        WHERE order_id = @order_id
    )
    WHERE id = @order_id;
END;
GO

-- Create a function example
CREATE FUNCTION dbo.fn_calculate_customer_discount(@customer_id INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @total_spent DECIMAL(10,2);
    DECLARE @discount DECIMAL(5,2);
    
    SELECT @total_spent = ISNULL(SUM(valor_total), 0)
    FROM sales.orders
    WHERE customer_id = @customer_id
    AND status = 'ENTREGUE';
    
    SET @discount = CASE
        WHEN @total_spent > 20000 THEN 15.00
        WHEN @total_spent > 10000 THEN 10.00
        WHEN @total_spent > 5000 THEN 5.00
        ELSE 0.00
    END;
    
    RETURN @discount;
END;
GO

-- Create a trigger example
CREATE TRIGGER tr_update_product_timestamp
ON sales.products
AFTER UPDATE
AS
BEGIN
    UPDATE sales.products
    SET ultima_atualizacao = GETDATE()
    FROM sales.products p
    INNER JOIN inserted i ON p.id = i.id;
END;
GO

-- Grant some permissions for testing (adjust usernames as needed)
-- GRANT SELECT ON SCHEMA::dbo TO [test_user];
-- GRANT SELECT, INSERT, UPDATE ON SCHEMA::sales TO [test_user];
-- GRANT SELECT ON SCHEMA::hr TO [test_user];

PRINT 'Sample schema created successfully!';
PRINT 'Schemas: dbo, sales, hr';
PRINT 'Tables: customers (8 records), products (10 records), orders (9 records), order_items (15 records), employees (10 records)';
PRINT 'Views: vw_customer_order_summary, vw_product_performance';
PRINT 'Stored Procedure: sp_update_order_total';
PRINT 'Function: fn_calculate_customer_discount';
PRINT 'Trigger: tr_update_product_timestamp';
GO