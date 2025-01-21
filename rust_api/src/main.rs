use actix_web::{web, App, HttpServer, HttpResponse, Responder, post};
use serde::Deserialize;
use tokio_postgres::{NoTls, Client, Error as PgError};
use dotenv::dotenv;
use std::env;
use std::sync::Arc;
use rust_decimal::Decimal;
use postgres_types::ToSql;

#[derive(Deserialize)]
struct TransactionRequest {
    amount: Decimal,
    description: String,
}

#[post("/transaction")]
async fn create_transaction(
    client: web::Data<Arc<Client>>,
    transaction: web::Json<TransactionRequest>,
) -> impl Responder {
    let query = "INSERT INTO transactions (amount, description, source) VALUES ($1::numeric, $2, $3) RETURNING id";
    
    match client.query_one(
        query,
        &[
            &transaction.amount,
            &transaction.description,
            &"Rust"
        ],
    ).await {
        Ok(row) => {
            let id: i32 = row.get(0);
            HttpResponse::Created().json(serde_json::json!({
                "message": "Transação criada com sucesso",
                "id": id,
            }))
        }
        Err(err) => {
            eprintln!("Erro ao inserir dados: {}", err);
            HttpResponse::InternalServerError().body("Erro ao inserir os dados no banco")
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();
    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL não configurado no .env");
    println!("Conectando ao banco de dados...");

    // Estabelece a conexão com o banco de dados
    let (client, connection) = tokio_postgres::connect(&database_url, NoTls)
        .await
        .expect("Erro ao conectar ao banco de dados");

    // Gerencia a conexão em uma task separada
    tokio::spawn(async move {
        if let Err(e) = connection.await {
            eprintln!("Erro na conexão: {}", e);
        }
    });

    let client = Arc::new(client);

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(client.clone()))
            .service(create_transaction)
    })
    .bind(("0.0.0.0", 8080))?
    .run()
    .await
}
