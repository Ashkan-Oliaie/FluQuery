FROM dart:stable AS build

WORKDIR /app

# Copy pubspec files
COPY pubspec.* ./
RUN dart pub get

# Copy source code
COPY . .

# Compile
RUN dart compile exe bin/server.dart -o bin/server

# Build runtime image
FROM debian:bookworm-slim

WORKDIR /app

# Install certificates for HTTPS
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy compiled binary
COPY --from=build /app/bin/server /app/bin/server

# Expose port
EXPOSE 8080

# Run server
CMD ["/app/bin/server"]

