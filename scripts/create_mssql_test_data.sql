-- Script para criar dados de teste no MSSQL

-- Database DevDB1
USE DevDB1;
GO

-- Tabela de Clientes
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY IDENTITY(1,1),
    Name NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) UNIQUE,
    Phone NVARCHAR(20),
    CreatedAt DATETIME DEFAULT GETDATE()
);
GO

-- Tabela de Produtos
CREATE TABLE Products (
    ProductID INT PRIMARY KEY IDENTITY(1,1),
    ProductName NVARCHAR(100) NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    Stock INT DEFAULT 0,
    CategoryID INT,
    CreatedAt DATETIME DEFAULT GETDATE()
);
GO

-- Tabela de Pedidos
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY IDENTITY(1,1),
    CustomerID INT FOREIGN KEY REFERENCES Customers(CustomerID),
    OrderDate DATETIME DEFAULT GETDATE(),
    TotalAmount DECIMAL(10,2),
    Status NVARCHAR(20) DEFAULT 'Pending'
);
GO

-- Inserir dados de exemplo em Customers
INSERT INTO Customers (Name, Email, Phone) VALUES
('João Silva', 'joao@email.com', '11999999999'),
('Maria Santos', 'maria@email.com', '11888888888'),
('Pedro Oliveira', 'pedro@email.com', '11777777777');
GO

-- Inserir dados de exemplo em Products
INSERT INTO Products (ProductName, Price, Stock, CategoryID) VALUES
('Notebook Dell', 3500.00, 10, 1),
('Mouse Logitech', 150.00, 50, 2),
('Teclado Mecânico', 450.00, 25, 2),
('Monitor 24"', 1200.00, 15, 3);
GO

-- Database DevDB2
USE DevDB2;
GO

-- Tabela de Funcionários
CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY IDENTITY(1,1),
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Department NVARCHAR(50),
    Salary DECIMAL(10,2),
    HireDate DATE,
    Active BIT DEFAULT 1
);
GO

-- Tabela de Departamentos
CREATE TABLE Departments (
    DepartmentID INT PRIMARY KEY IDENTITY(1,1),
    DepartmentName NVARCHAR(100) NOT NULL,
    ManagerID INT,
    Budget DECIMAL(12,2)
);
GO

-- Tabela de Projetos
CREATE TABLE Projects (
    ProjectID INT PRIMARY KEY IDENTITY(1,1),
    ProjectName NVARCHAR(200) NOT NULL,
    StartDate DATE,
    EndDate DATE,
    Budget DECIMAL(12,2),
    Status NVARCHAR(20) DEFAULT 'Active'
);
GO

-- Tabela de Log de Auditoria
CREATE TABLE AuditLog (
    LogID BIGINT PRIMARY KEY IDENTITY(1,1),
    TableName NVARCHAR(100),
    Action NVARCHAR(20),
    UserName NVARCHAR(100),
    ActionTime DATETIME DEFAULT GETDATE(),
    Details NVARCHAR(MAX)
);
GO

-- Inserir dados de exemplo em Employees
INSERT INTO Employees (FirstName, LastName, Department, Salary, HireDate) VALUES
('Carlos', 'Mendes', 'TI', 8500.00, '2023-01-15'),
('Ana', 'Costa', 'RH', 6500.00, '2023-03-20'),
('Roberto', 'Lima', 'Vendas', 7200.00, '2023-02-10'),
('Juliana', 'Ferreira', 'TI', 9200.00, '2022-11-05');
GO

-- Inserir dados de exemplo em Departments
INSERT INTO Departments (DepartmentName, ManagerID, Budget) VALUES
('Tecnologia da Informação', 1, 500000.00),
('Recursos Humanos', 2, 200000.00),
('Vendas', 3, 750000.00),
('Marketing', NULL, 300000.00);
GO

-- Inserir dados de exemplo em Projects
INSERT INTO Projects (ProjectName, StartDate, EndDate, Budget) VALUES
('Migração Cloud', '2024-01-01', '2024-12-31', 150000.00),
('Sistema ERP', '2024-03-01', '2025-03-01', 450000.00),
('Portal do Cliente', '2024-06-01', '2024-11-30', 80000.00);
GO

-- Criar usuário de teste no DevDB1
USE DevDB1;
GO
CREATE USER admin_mssql FOR LOGIN admin_mssql;
GO
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO admin_mssql;
GO

-- Criar usuário de teste no DevDB2
USE DevDB2;
GO
CREATE USER admin_mssql FOR LOGIN admin_mssql;
GO
GRANT SELECT ON SCHEMA::dbo TO admin_mssql;
GO

PRINT 'Databases de desenvolvimento criadas com sucesso!';
GO