const express = require('express');
const app = express();
const { Pool } = require('pg');
require('dotenv/config');

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

console.log('Conectado ao banco de dados PostgreSQL');
app.use(express.json());

app.post('/transaction', async (req, res) => {
  const { amount, description } = req.body;
  const query = {
    text: 'INSERT INTO transactions (amount, description, source) VALUES ($1, $2, $3) RETURNING id',
    values: [amount, description, 'Node'],
  };

  try {
    await pool.query('BEGIN');
    const result = await pool.query(query);
    await pool.query('COMMIT');
    res.status(201).json({ message: 'Transaction created successfully', id: result.rows[0].id });
  } catch (error) {
    console.error(error);
    await pool.query('ROLLBACK');
    res.status(500).json({ message: 'Error storing transaction' });
  }
});

app.listen(process.env.PORT || 3333, () => {
  console.log('Server listening on port 3333');
});
