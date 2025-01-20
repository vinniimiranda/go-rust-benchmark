CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    amount NUMERIC(10, 2) NOT NULL,
    description TEXT NOT NULL,
    source TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
