package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	_ "github.com/lib/pq"
)

type Config struct {
	DBUser     string
	DBPassword string
	DBName     string
	DBHost     string
	DBPort     string
}

type Transaction struct {
	Amount      float64 `json:"amount"`
	Description string  `json:"description"`
}


var db *sql.DB

func main() {

	dbUser := os.Getenv("DB_USER")
	dbPassword := os.Getenv("DB_PASSWORD")
	dbName := os.Getenv("DB_NAME")
	dbHost := os.Getenv("DB_HOST")
	dbPort := os.Getenv("DB_PORT")

	config := Config{
		DBUser:     dbUser,
		DBPassword: dbPassword,
		DBName:     dbName,
		DBHost:     dbHost,
		DBPort:     dbPort,
	}

	// Conectar ao banco de dados
	var err error
	db, err = connectDB(config)
	if err != nil {
		log.Fatalf("Erro ao conectar ao banco de dados: %v", err)
	}
	defer db.Close()

	http.HandleFunc("/transaction", handleTransaction)
	fmt.Println("API rodando na porta 8080...")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

// Conectar ao banco de dados PostgreSQL
func connectDB(config Config) (*sql.DB, error) {
	connStr := fmt.Sprintf("user=%s password=%s dbname=%s host=%s port=%s sslmode=disable",
		config.DBUser, config.DBPassword, config.DBName, config.DBHost, config.DBPort)
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, err
	}

	db.SetMaxIdleConns(5) // Pool de conex o com 50 clientes
	db.SetMaxOpenConns(10)

	return db, nil
}

// Manipulador para realizar transação
func handleTransaction(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Método não permitido", http.StatusMethodNotAllowed)
		return
	}

	var t Transaction
		if err := json.NewDecoder(r.Body).Decode(&t); err != nil {
			http.Error(w, "Erro ao decodificar JSON", http.StatusBadRequest)
			return
		}

	// Iniciar uma transação

	tx, err := db.Begin()
		if err != nil {
			http.Error(w, "Erro ao iniciar a transação", http.StatusInternalServerError)
			return
		}

		// Inserir os dados no banco
		query := "INSERT INTO transactions (amount, description, source) VALUES ($1, $2, $3) RETURNING id"
		var id int
		err = tx.QueryRow(query, t.Amount, t.Description, "Go").Scan(&id)
		if err != nil {
			tx.Rollback()
			http.Error(w, "Erro ao inserir os dados no banco", http.StatusInternalServerError)
			return
		}

		// Commit da transação
		if err := tx.Commit(); err != nil {
			http.Error(w, "Erro ao confirmar a transação", http.StatusInternalServerError)
			return
		}

		// Retornar a resposta
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"message": "Transação criada com sucesso",
			"id":      id,
		})
}
