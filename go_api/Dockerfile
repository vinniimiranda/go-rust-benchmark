FROM golang:1.22.5-alpine as builder

# Set the working directory
WORKDIR /app

# Copy the code into the container
COPY . .

# Build the application
RUN go build -o app .

# Create a new container for the final application
FROM alpine:latest

# Set the working directory
WORKDIR /app

# Copy the application from the builder
COPY --from=builder /app/app .

# Expose the port
EXPOSE 8080

# Run the application
CMD ["./app"]
