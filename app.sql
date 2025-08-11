-- Database Migration for District Judiciary Copy Application System

-- Create custom types
CREATE TYPE application_type_enum AS ENUM ('copy', 'third_party');
CREATE TYPE case_type_enum AS ENUM ('civil', 'criminal');
CREATE TYPE priority_enum AS ENUM ('normal', 'emergent');
CREATE TYPE status_enum AS ENUM ('submitted', 'a_register', 'sent_to_court', 'court_replied', 'superintendent_received', 'call_for_notice', 'payment_received', 'xerox_assigned', 'ready', 'delivered', 'struck_off');

-- Applications table
CREATE TABLE applications (
    id SERIAL PRIMARY KEY,
    g_number VARCHAR(20) UNIQUE NOT NULL,
    application_type application_type_enum NOT NULL,
    case_type case_type_enum NOT NULL,
    priority priority_enum DEFAULT 'normal',
    base_fee DECIMAL(5,2) NOT NULL,
    applicant_name VARCHAR(255) NOT NULL,
    applicant_address TEXT,
    advocate_name VARCHAR(255),
    case_number VARCHAR(100),
    case_year INTEGER,
    case_details TEXT,
    documents_required TEXT,
    status status_enum DEFAULT 'submitted',
    deadline_date DATE,
    strike_off_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- A Register (Initial Review)
CREATE TABLE a_register (
    id SERIAL PRIMARY KEY,
    application_id INTEGER REFERENCES applications(id) ON DELETE CASCADE,
    received_date DATE DEFAULT CURRENT_DATE,
    remarks TEXT,
    returned_date DATE,
    clerk_initials VARCHAR(10),
    processing_days INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- B Register (Court Review)
CREATE TABLE b_register (
    id SERIAL PRIMARY KEY,
    application_id INTEGER REFERENCES applications(id) ON DELETE CASCADE,
    sent_to_court_date DATE DEFAULT CURRENT_DATE,
    court_name VARCHAR(255),
    court_remarks TEXT,
    returned_date DATE,
    compliance_status BOOLEAN DEFAULT FALSE,
    clerk_initials VARCHAR(10),
    processing_days INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Call for Notice
CREATE TABLE call_for_notice (
    id SERIAL PRIMARY KEY,
    application_id INTEGER REFERENCES applications(id) ON DELETE CASCADE,
    notice_date DATE DEFAULT CURRENT_DATE,
    grace_period_end DATE,
    pages_estimated INTEGER,
    fee_calculated DECIMAL(8,2),
    is_struck_off BOOLEAN DEFAULT FALSE,
    struck_off_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Payment Tracking
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    application_id INTEGER REFERENCES applications(id) ON DELETE CASCADE,
    amount DECIMAL(8,2) NOT NULL,
    pages_count INTEGER NOT NULL,
    per_page_rate DECIMAL(5,2),
    payment_date DATE DEFAULT CURRENT_DATE,
    payment_method VARCHAR(50),
    receipt_number VARCHAR(100),
    advocate_name VARCHAR(255),
    recorded_by VARCHAR(100),
    remarks TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Xerox Operations
CREATE TABLE xerox_operations (
    id SERIAL PRIMARY KEY,
    application_id INTEGER REFERENCES applications(id) ON DELETE CASCADE,
    assigned_date DATE DEFAULT CURRENT_DATE,
    operator_name VARCHAR(100),
    pages_copied INTEGER,
    completed_date DATE,
    remarks TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Status History
CREATE TABLE status_history (
    id SERIAL PRIMARY KEY,
    application_id INTEGER REFERENCES applications(id) ON DELETE CASCADE,
    old_status status_enum,
    new_status status_enum NOT NULL,
    remarks TEXT,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users table for system access
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL, -- clerk, superintendent, xerox_operator, admin
    initials VARCHAR(10),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- G Number sequence table
CREATE TABLE g_number_sequence (
    id SERIAL PRIMARY KEY,
    year INTEGER NOT NULL,
    sequence_number INTEGER DEFAULT 0,
    UNIQUE(year)
);

-- Create indexes for performance
CREATE INDEX idx_applications_g_number ON applications(g_number);
CREATE INDEX idx_applications_status ON applications(status);
CREATE INDEX idx_applications_created_at ON applications(created_at);
CREATE INDEX idx_applications_case_type ON applications(case_type);
CREATE INDEX idx_status_history_application_id ON status_history(application_id);
CREATE INDEX idx_payments_application_id ON payments(application_id);

-- Function to generate G Number
CREATE OR REPLACE FUNCTION generate_g_number()
RETURNS TEXT AS $$
DECLARE
    current_year INTEGER := EXTRACT(YEAR FROM CURRENT_DATE);
    next_sequence INTEGER;
    g_num TEXT;
BEGIN
    -- Insert or update sequence for current year
    INSERT INTO g_number_sequence (year, sequence_number)
    VALUES (current_year, 1)
    ON CONFLICT (year)
    DO UPDATE SET sequence_number = g_number_sequence.sequence_number + 1;
    
    -- Get the sequence number
    SELECT sequence_number INTO next_sequence
    FROM g_number_sequence
    WHERE year = current_year;
    
    -- Format: YYYY/NNNN
    g_num := current_year || '/' || LPAD(next_sequence::TEXT, 4, '0');
    
    RETURN g_num;
END;
$$ LANGUAGE plpgsql;

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER applications_updated_at
    BEFORE UPDATE ON applications
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER a_register_updated_at
    BEFORE UPDATE ON a_register
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER b_register_updated_at
    BEFORE UPDATE ON b_register
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- Function to calculate processing days
CREATE OR REPLACE FUNCTION calculate_processing_days(start_date DATE, end_date DATE)
RETURNS INTEGER AS $$
BEGIN
    -- Simple calculation - can be enhanced to exclude weekends/holidays
    RETURN (end_date - start_date);
END;
$$ LANGUAGE plpgsql;

-- Insert default admin user (password should be hashed)
INSERT INTO users (username, password, full_name, role, initials) 
VALUES ('admin', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'System Administrator', 'admin', 'ADM');

-- Insert current year sequence
INSERT INTO g_number_sequence (year, sequence_number) VALUES (EXTRACT(YEAR FROM CURRENT_DATE), 0);