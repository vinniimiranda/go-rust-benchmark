# Use the official Rust image as a parent image
FROM rust:latest as builder

# Set the working directory
WORKDIR /app

# Copy the source code into the container
COPY . .

# Build the application
RUN cargo build --release

# Create a new stage for the final image
FROM gcr.io/distroless/cc-debian12


# Set the working directory
WORKDIR /app

# Copy the compiled application from the builder stage
COPY --from=builder /app/target/release/rust_api .

# Expose the port the app runs on
EXPOSE 8080

# Define the command to run the application
CMD ["./rust_api"]

