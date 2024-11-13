CREATE TABLE IF NOT EXISTS users
(
    id INT(11) PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(255) DEFAULT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active TINYINT(1) DEFAULT 1,
    custom_fields LONGTEXT CHECK (json_valid(custom_fields))
);

CREATE TABLE IF NOT EXISTS roles
(
    id INT(11) PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active TINYINT(1) DEFAULT 1,
    custom_fields LONGTEXT CHECK (json_valid(custom_fields))
);

CREATE TABLE IF NOT EXISTS user_roles
(
    id INT(11) PRIMARY KEY AUTO_INCREMENT,
    user_id INT(11),
    rol_id INT(11),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active TINYINT(1) DEFAULT 1,
    FOREIGN KEY (user_id) REFERENCES users (id),
    FOREIGN KEY (rol_id) REFERENCES roles (id)
);

CREATE TABLE IF NOT EXISTS sessions
(
    id INT(20) PRIMARY KEY AUTO_INCREMENT,
    user_id INT(11) NOT NULL,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    browser_info VARCHAR(255) DEFAULT NULL,
    device_name VARCHAR(255) DEFAULT NULL,
    ip_address VARCHAR(39) DEFAULT NULL,
    last_activity DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_active TINYINT(1) DEFAULT 1,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    INDEX (session_token)
);

CREATE TABLE IF NOT EXISTS device_logs
(
    id INT(11) PRIMARY KEY AUTO_INCREMENT,
    user_id INT(20) NOT NULL,
    device_name VARCHAR(255) NOT NULL,
    device_battery_level INT DEFAULT NULL,
    sync_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    sync_status ENUM('success', 'failure') DEFAULT 'success',
    custom_fields LONGTEXT CHECK (json_valid(custom_fields)),
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX (sync_status)
);

CREATE TABLE IF NOT EXISTS categories
(
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active TINYINT(1) DEFAULT 1,
    custom_fields LONGTEXT CHECK (json_valid(custom_fields))
);

CREATE TABLE IF NOT EXISTS products
(
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT NULL,
    price DECIMAL(20, 2) DEFAULT 0.0,
    stock INT(11) DEFAULT 0,
    image LONGTEXT DEFAULT NULL,
    category_id INT(11) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active TINYINT(1) DEFAULT 1,
    custom_fields LONGTEXT CHECK (json_valid(custom_fields)),
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

CREATE TABLE IF NOT EXISTS daily_assignments (
    id INT(11) PRIMARY KEY AUTO_INCREMENT,
    user_id INT(11) NOT NULL,
    product_id INT(11) NOT NULL,
    date DATE NOT NULL,
    assigned_quantity INT(11) DEFAULT 0,
    returned_boxes INT(11) DEFAULT 0,               -- Nueva columna para las cajas devueltas
    returned_units INT(11) DEFAULT 0,               -- Nueva columna para las unidades devueltas
    total_sold_units INT(11) DEFAULT 0,             -- Nueva columna para las unidades totales vendidas
    total_revenue DECIMAL(20, 2) DEFAULT 0.0,       -- Nueva columna para el total recaudado
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active TINYINT(1) DEFAULT 1,
    custom_fields LONGTEXT CHECK (json_valid(custom_fields)),
    FOREIGN KEY (user_id) REFERENCES users (id),
    FOREIGN KEY (product_id) REFERENCES products (id)
);

CREATE TABLE IF NOT EXISTS sales
(
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    sale_date DATE NOT NULL,
    total_amount DECIMAL(20, 2) DEFAULT 0.0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active TINYINT(1) DEFAULT 1,
    custom_fields LONGTEXT CHECK (json_valid(custom_fields)),
    FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE TABLE IF NOT EXISTS sale_details
(
    id INT(11) PRIMARY KEY AUTO_INCREMENT,
    sale_id INT(11) NOT NULL,
    product_id INT(11) NOT NULL,
    quantity_sold INT(11) NOT NULL,
    unit_price DECIMAL(20, 2) NOT NULL,
    total_price DECIMAL(20, 2),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active TINYINT(1) DEFAULT 1,
    custom_fields LONGTEXT CHECK (json_valid(custom_fields)),
    FOREIGN KEY (sale_id) REFERENCES sales(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- Trigger to update the product stock when a sale is made
DELIMITER //
CREATE TRIGGER after_sale_details_insert
AFTER INSERT ON sale_details
FOR EACH ROW
BEGIN
    UPDATE products
    SET stock = stock - NEW.quantity_sold
    WHERE id = NEW.product_id;
END;
//
DELIMITER ;

-- Trigger to revert the product stock if a sale is deleted
DELIMITER //
CREATE TRIGGER after_sale_details_delete
AFTER DELETE ON sale_details
FOR EACH ROW
BEGIN
    UPDATE products
    SET stock = stock + OLD.quantity_sold
    WHERE id = OLD.product_id;
END;
//
DELIMITER ;

-- Trigger to revert the product stock if a sale is marked as inactive (soft delete)
DELIMITER //
CREATE TRIGGER after_sale_details_update
AFTER UPDATE ON sale_details
FOR EACH ROW
BEGIN
    IF OLD.is_active = 1 AND NEW.is_active = 0 THEN
        -- If sale is being soft-deleted, revert the stock
        UPDATE products
        SET stock = stock + OLD.quantity_sold
        WHERE id = OLD.product_id;
    ELSEIF OLD.is_active = 0 AND NEW.is_active = 1 THEN
        -- If sale is being re-activated, deduct the stock again
        UPDATE products
        SET stock = stock - NEW.quantity_sold
        WHERE id = NEW.product_id;
    END IF;
END;
//
DELIMITER ;

-- Modificación de la tabla sale_details para incluir cantidades de cajas y unidades
ALTER TABLE sale_details
ADD COLUMN box_quantity INT(11) DEFAULT 0, -- Cantidad de cajas vendidas
ADD COLUMN unit_quantity INT(11) DEFAULT 0, -- Cantidad de unidades individuales vendidas (opcional),
ADD COLUMN total_units_sold INT(11) DEFAULT 0; -- Total de unidades vendidas

-- Trigger para calcular el total de unidades vendidas antes de insertar un registro en sale_details
DELIMITER //

CREATE TRIGGER before_sale_details_insert
BEFORE INSERT ON sale_details
FOR EACH ROW
BEGIN
    DECLARE units_in_box INT;
    SET units_in_box = (SELECT units_per_box FROM product_boxes WHERE product_boxes.product_id = NEW.product_id);
    SET NEW.total_units_sold = NEW.box_quantity * units_in_box + NEW.unit_quantity;
END;
//

-- Trigger para recalcular el total de unidades vendidas antes de actualizar un registro en sale_details
CREATE TRIGGER before_sale_details_update
BEFORE UPDATE ON sale_details
FOR EACH ROW
BEGIN
    DECLARE units_in_box INT;
    SET units_in_box = (SELECT units_per_box FROM product_boxes WHERE product_boxes.product_id = NEW.product_id);
    SET NEW.total_units_sold = NEW.box_quantity * units_in_box + NEW.unit_quantity;
END;
//

DELIMITER ;

-- Tabla de Proveedores
CREATE TABLE IF NOT EXISTS providers (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL UNIQUE,
    contact_info VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active TINYINT(1) DEFAULT 1,
    custom_fields JSON DEFAULT NULL CHECK (json_valid(custom_fields))
);

-- Relación entre proveedores y cajas de productos
CREATE TABLE IF NOT EXISTS product_box_supplies (
    id INT PRIMARY KEY AUTO_INCREMENT,
    provider_id INT NOT NULL,
    product_id INT NOT NULL,
    box_quantity INT DEFAULT 0, -- Cantidad de cajas proporcionadas por el proveedor
    units_per_box INT DEFAULT 0,
    box_price DECIMAL(20, 2) DEFAULT 0.0, -- Precio de la caja suministrada
    supply_date DATE DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active TINYINT(1) DEFAULT 1,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
);