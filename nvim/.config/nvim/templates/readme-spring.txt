# Project Name

Brief description of your Spring Boot application.

## 🚀 Technologies

- Java 21
- Spring Boot 3.x
- PostgreSQL / MySQL
- Docker
- Maven

## 📋 Prerequisites

- Java 21+
- Maven 3.9+
- Docker & Docker Compose
- PostgreSQL 16 / MySQL 8.0

## 🔧 Installation

### 1. Clone the repository
```bash
git clone <repository-url>
cd <project-name>
```

### 2. Configure environment variables
```bash
cp .env.example .env
# Edit .env with your configuration
```

### 3. Start database (Docker)
```bash
docker-compose up -d
```

### 4. Run the application
```bash
mvn spring-boot:run
```

Or build and run:
```bash
mvn clean package
java -jar target/*.jar
```

## 🐳 Docker

### Build image
```bash
docker build -t myapp:latest .
```

### Run with Docker Compose
```bash
docker-compose up
```

## 📚 API Documentation

Once the application is running, visit:
- Swagger UI: http://localhost:8080/swagger-ui.html
- API Docs: http://localhost:8080/v3/api-docs

## 🧪 Testing
```bash
mvn test
```

## 📁 Project Structure
```
src/
├── main/
│   ├── java/
│   │   └── com/example/myapp/
│   │       ├── config/
│   │       ├── controller/
│   │       ├── dto/
│   │       ├── entity/
│   │       ├── repository/
│   │       ├── service/
│   │       └── MyAppApplication.java
│   └── resources/
│       ├── application.yml
│       └── application-dev.yml
└── test/
```

## 🌍 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOST` | Database host | localhost |
| `DB_PORT` | Database port | 5432 |
| `DB_NAME` | Database name | mydb |
| `DB_USER` | Database user | user |
| `DB_PASSWORD` | Database password | password |

## 🤝 Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License.

## 👤 Author

Your Name - [@yourhandle](https://twitter.com/yourhandle)
