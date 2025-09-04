# Wizard Todo Application

## Overview
A containerized Go web application built for the Wiz technical exercise. This is a simple todo list application that demonstrates cloud-native deployment patterns with intentional security vulnerabilities.

## Application Stack
- **Backend**: Go 1.19 with Gin web framework
- **Frontend**: HTML/CSS/JavaScript (served by Go backend)
- **Database**: MongoDB connection via Go driver
- **Container**: Multi-stage Docker build using Alpine Linux

## Key Files
- **`main.go`**: Application entry point with HTTP routes
- **`controllers/`**: Business logic for users and todos
  - `userController.go`: User registration, authentication, and session management
  - `todoController.go`: Todo CRUD operations with user-based data isolation
- **`models/models.go`**: Data structures for User and Todo entities
- **`assets/`**: Frontend static files (HTML, CSS, JavaScript)
- **`k8s-manifests.yaml`**: Kubernetes deployment configuration
- **`Dockerfile`**: Container build configuration
- **`wizexercise.txt`**: Required file containing "David Guevara"

## Application Features ✅

### 🔐 User Management
- User registration with password hashing (bcrypt)
- JWT-based authentication with HTTP-only cookies
- Session management with configurable expiration
- User isolation (users can only see their own todos)

### 📝 Todo Management
- Create, read, update, delete todos
- User-specific todo lists with access control
- Todo status tracking (pending/completed)
- Persistent storage in MongoDB

### 🌐 Web Interface
- Responsive HTML/CSS/JavaScript frontend
- Login/signup forms with client-side validation
- Real-time todo list management
- Session-based navigation

## Database Schema

### Users Collection (`go-mongodb.user`)
```javascript
{
  "_id": ObjectId("..."),
  "username": "string",
  "email": "string", 
  "password": "bcrypt_hashed_string"
}
```

### Todos Collection (`go-mongodb.todos`)
```javascript
{
  "_id": ObjectId("..."),
  "name": "string",
  "status": "pending|completed",
  "userid": "string" // References user._id
}
```

## API Routes

### Public Routes
- `GET /` - Login/signup page (HTML)
- `POST /signup` - User registration
- `POST /login` - User authentication

### Protected Routes (Require Authentication)
- `GET /todos/:userid` - Get user's todos
- `POST /todo/:userid` - Create new todo
- `GET /todo/:id` - Get specific todo
- `PUT /todo` - Update todo
- `DELETE /todo/:userid/:id` - Delete specific todo
- `DELETE /todos/:userid` - Delete all user's todos

## Environment Configuration

### Required Environment Variables
- `MONGODB_URI`: MongoDB connection string
  - Format: `mongodb://user:password@host:port/database?authSource=admin`
  - Example: `mongodb://wizuser:password@10.100.0.4:27017/go-mongodb?authSource=admin`
- `GIN_MODE`: Gin framework mode (`debug`, `release`, `test`)
- `SECRET_KEY`: JWT signing secret (optional, uses default if not set)

### Kubernetes Configuration
The application expects:
- **ConfigMap**: `wizapp-config` with `MONGODB_URI` key
- **Service Account**: `wizapp-sa` with appropriate permissions
- **Namespace**: `wizapp`

## Container Details

### Multi-stage Docker Build
1. **Build Stage**: Go compilation in full Go image
2. **Runtime Stage**: Minimal Alpine Linux with compiled binary
3. **Security**: Runs as non-root user (`appuser`)
4. **Optimization**: Only includes necessary runtime files

### Container Structure
```
/app/
├── tasky              # Compiled Go binary
├── assets/            # Static web files
│   ├── todo.html
│   ├── login.html
│   ├── css/
│   └── js/
└── wizexercise.txt    # Required exercise file
```

## Deployment

### Kubernetes Deployment
```bash
# Apply the Kubernetes manifests
kubectl apply -f k8s-manifests.yaml

# Check deployment status
kubectl get pods -n wizapp
kubectl get svc -n wizapp
```

### Local Development
```bash
# Set environment variables
export MONGODB_URI="mongodb://localhost:27017/go-mongodb"
export GIN_MODE="debug"

# Run the application
go run main.go

# Access at http://localhost:8080
```

## Authentication Flow

1. **User Registration**:
   ```
   POST /signup → Create user → Generate JWT → Set cookies → Redirect
   ```

2. **User Login**:
   ```
   POST /login → Verify credentials → Generate JWT → Set cookies → Redirect
   ```

3. **Protected Requests**:
   ```
   Request → Check JWT cookie → Validate token → Allow/Deny access
   ```

## Security Features (Application Level)

### ✅ Implemented Security
- Password hashing with bcrypt (cost factor 14)
- JWT tokens with expiration
- HTTP-only cookies (prevents XSS token theft)
- User data isolation by userid
- Input validation and sanitization
- Authentication required for all todo operations

### ⚠️ Intentional Vulnerabilities (For Wiz Exercise)
- No CSRF protection
- No rate limiting on authentication endpoints
- JWT secret uses default value if not provided
- No input length limits
- No account lockout after failed attempts
- Session cookies without secure/SameSite flags

## Troubleshooting

### Common Issues

**1. Database Connection Errors**
```bash
# Check MongoDB URI format
kubectl get configmap wizapp-config -n wizapp -o yaml

# Verify network connectivity
kubectl exec -n wizapp deployment/wizapp-deployment -- nc -zv <mongodb-host> 27017
```

**2. Authentication Not Working**
```bash
# Check application logs
kubectl logs -n wizapp deployment/wizapp-deployment

# Verify MongoDB user collection
mongo -u <user> -p <password> --authenticationDatabase admin
> use go-mongodb
> db.user.find()
```

**3. Container Won't Start**
```bash
# Check pod events
kubectl describe pod -n wizapp <pod-name>

# Verify wizexercise.txt exists
kubectl exec -n wizapp deployment/wizapp-deployment -- cat /app/wizexercise.txt
```

## Development Notes

### Code Structure
- **MVC Pattern**: Controllers handle HTTP, models define data structures
- **Middleware**: JWT validation for protected routes
- **Error Handling**: JSON error responses for API endpoints
- **Database**: MongoDB with Go official driver

### Testing the Application
1. Navigate to application URL
2. Create a user account via signup
3. Login with credentials
4. Create/manage todos
5. Verify data persistence in MongoDB

---

**Status**: ✅ Fully functional  
**Last Updated**: August 2025  
**Database**: Uses `go-mongodb` database, not `wizapp` database  
**Validation**: Application tested with user signup, login, and todo management