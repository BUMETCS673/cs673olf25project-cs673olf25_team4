# Full-Stack Hello World App

A simple full-stack application demonstrating React frontend, FastAPI backend, and Docker containerization.

## 🚀 Tech Stack

- **Frontend**: React 18 with Axios for HTTP requests
- **Backend**: FastAPI with Python 3.11
- **Containerization**: Docker and Docker Compose
- **Styling**: Custom CSS with modern gradients and glass-morphism effects

## 📁 Project Structure

```
project-root/
├── docker-compose.yml
├── README.md
├── frontend/
│   ├── Dockerfile
│   ├── package.json
│   ├── public/
│   │   └── index.html
│   └── src/
│       ├── App.js
│       ├── App.css
│       ├── index.js
│       └── index.css
└── backend/
    ├── Dockerfile
    ├── requirements.txt
    └── main.py
```

## 🛠️ Setup Instructions

### Prerequisites
- Docker and Docker Compose installed on your system
- Git (for cloning/version control)

### Quick Start

1. **Create the project structure**:
   ```bash
   mkdir fullstack-hello-world
   cd fullstack-hello-world
   mkdir frontend backend
   mkdir frontend/src frontend/public
   ```

2. **Copy all the provided files** into their respective directories according to the structure above.

3. **Start the application**:
   ```bash
   docker-compose up --build
   ```

4. **Access the application**:
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8000
   - API Documentation: http://localhost:8000/docs

### Development Mode

The Docker setup includes volume mounting for hot reloading:
- Changes to React components will automatically reload the frontend
- Changes to Python files will automatically restart the FastAPI server

## 🔧 API Endpoints

- `GET /` - Root endpoint
- `GET /api/hello` - Simple hello message
- `POST /api/greet` - Personalized greeting (requires JSON: `{"name": "Your Name"}`)
- `GET /api/health` - Health check endpoint

## 🎯 Features

- **Responsive Design**: Works on desktop and mobile devices
- **Real-time Communication**: Frontend communicates with backend via REST API
- **Error Handling**: Graceful error handling for network requests
- **Modern UI**: Glass-morphism design with smooth animations
- **Hot Reloading**: Development-friendly setup with auto-reload
- **Health Checks**: Built-in health monitoring endpoints

## 🐳 Docker Commands

```bash
# Start services
docker-compose up

# Start services in background
docker-compose up -d

# Rebuild and start
docker-compose up --build

# Stop services
docker-compose down

# View logs
docker-compose logs

# View logs for specific service
docker-compose logs frontend
docker-compose logs backend
```

## 🔄 Development Workflow

1. Make changes to your code
2. The containers will automatically reload (thanks to volume mounting)
3. Test your changes in the browser
4. Commit your changes to version control

## 📝 Next Steps for Your Group Project

This baseline provides:
- ✅ Containerized development environment
- ✅ Frontend-backend communication
- ✅ Modern React setup with hooks
- ✅ FastAPI with automatic API documentation
- ✅ CORS configuration for cross-origin requests
- ✅ Error handling patterns
- ✅ Responsive design foundation

### Suggested Enhancements:
- Add a database (PostgreSQL, MongoDB, etc.)
- Implement authentication/authorization
- Add state management (Redux, Zustand)
- Include testing frameworks (Jest, pytest)
- Add environment configuration
- Implement logging and monitoring
- Add CI/CD pipeline

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📚 Learning Resources

- [React Documentation](https://react.dev)
- [FastAPI Documentation](https://fastapi.tiangolo.com)
- [Docker Documentation](https://docs.docker.com)

Happy coding! 🎉