# FluQuery Backend API

A simple REST API backend for testing the FluQuery Flutter package.

## Features

- In-memory database (no external dependencies)
- CORS enabled for Flutter web
- Simulated network delays (200-800ms)
- Full CRUD operations

## Running Locally

### With Dart

```bash
cd backend
dart pub get
dart run bin/server.dart
```

### With Docker

```bash
cd backend
docker-compose up --build
```

Or build and run manually:

```bash
docker build -t fluquery-backend .
docker run -p 8080:8080 fluquery-backend
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/api/todos` | Get all todos |
| GET | `/api/todos/:id` | Get todo by ID |
| POST | `/api/todos` | Create todo |
| PUT | `/api/todos/:id` | Update todo |
| DELETE | `/api/todos/:id` | Delete todo |
| GET | `/api/posts?page=1&limit=10` | Get paginated posts |
| GET | `/api/posts/:id` | Get post by ID |
| GET | `/api/users` | Get all users |
| GET | `/api/users/:id` | Get user by ID |
| GET | `/api/users/:id/posts` | Get user's posts |
| GET | `/api/users/search?q=query` | Search users by name/email |
| GET | `/api/time` | Get server time |
| GET | `/api/posts/:id/comments` | Get post comments |
| POST | `/api/posts/:id/comments` | Add comment |

## Example Requests

### Create Todo
```bash
curl -X POST http://localhost:8080/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "New Todo", "completed": false}'
```

### Get Paginated Posts
```bash
curl "http://localhost:8080/api/posts?page=1&limit=10"
```

### Update Todo
```bash
curl -X PUT http://localhost:8080/api/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'
```

