CREATE TABLE IF NOT EXISTS users (
    username VARCHAR(50) PRIMARY KEY,
    password VARCHAR(255) NOT NULL
);

INSERT INTO users (username, password) VALUES
('admin', 'password123'),
('user', 'mypassword')
ON CONFLICT (username) DO NOTHING;

-- Table for storing reports
CREATE TABLE IF NOT EXISTS reports (
    report_id SERIAL PRIMARY KEY,
    title VARCHAR(100) UNIQUE NOT NULL,
    details TEXT NOT NULL
);

-- Mapping users to reports they can access
CREATE TABLE IF NOT EXISTS user_report_access (
    username VARCHAR(50) NOT NULL,
    report_id INT NOT NULL,
    PRIMARY KEY (username, report_id),
    FOREIGN KEY (username) REFERENCES users(username),
    FOREIGN KEY (report_id) REFERENCES reports(report_id)
);

-- Insert sample reports
INSERT INTO reports (title, details) VALUES
('Monthly Sales Summary', 'Sales increased by 8% last month in total revenue.'),
('Confidential Strategy Document', 'Expansion plan includes entering three new markets in Q3.')
ON CONFLICT (title) DO NOTHING;

-- Map normal user to access only "Monthly Sales Summary" report
-- Map admin to access both reports

INSERT INTO user_report_access (username, report_id) VALUES
('user', 1),
('admin', 1),
('admin', 2)
ON CONFLICT DO NOTHING;