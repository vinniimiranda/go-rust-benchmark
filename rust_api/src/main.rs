use actix_web::{web, App, HttpServer, HttpResponse, Responder, post};
use serde::Deserialize;
use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;
use dotenv::dotenv;
use std::env;
use sqlx::Row;


#[derive(Deserialize)]
struct TransactionRequest {
    amount: f64,
    description: String,
}

#[post("/transaction")]
async fn create_transaction(
    pool: web::Data<PgPool>,
    transaction: web::Json<TransactionRequest>,
) -> impl Responder {
    // Inicia uma transação diretamente do pool
    let mut tx = pool.begin().await.unwrap();
    let query = "INSERT INTO transactions (amount, description, source) VALUES ($1, $2, $3) RETURNING id";
    let result = sqlx::query(query)
        .bind(transaction.amount)
        .bind(&transaction.description)
        .bind("Rust")
        .fetch_one(&mut tx)
        .await;

    match result {
        Ok(row) => {
            let id: i32 = row.get("id");
            if let Err(err) = tx.commit().await {
                eprintln!("Erro ao confirmar a transação: {}", err);
                return HttpResponse::InternalServerError().body("Erro ao confirmar transação");
            }

            HttpResponse::Created().json(serde_json::json!({
                "message": "Transação criada com sucesso",
                "id": id,
            }))
        }
        Err(err) => {
            eprintln!("Erro ao inserir dados: {}", err);
            let _ = tx.rollback().await;
            HttpResponse::InternalServerError().body("Erro ao inserir os dados no banco")
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();
    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL não configurado no .env");
    println!("Conectando ao banco de dados...");
    let pool = PgPoolOptions::new()
        .max_connections(30)
        .connect(&database_url)
        .await
        .expect("Erro ao conectar ao banco de dados");


    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(pool.clone()))
            .service(create_transaction)
    })
    .bind(("0.0.0.0", 8080))?
    .run()
    .await

}
