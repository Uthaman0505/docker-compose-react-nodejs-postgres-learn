# Production Deployment Guide

This guide explains how to deploy your React + Node.js + PostgreSQL application using Docker Compose on a production server.

## 📋 Prerequisites

- Linux server (VPS/cloud instance) with Docker and Docker Compose installed
- Domain name (optional, for public access)
- SSH access to the server

## 🚀 Deployment Steps

### 1. Server Setup

**Install Docker and Docker Compose:**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again for group changes to take effect
```

### 2. Deploy Application

**Clone and setup your application:**
```bash
# Clone your repository
git clone <your-repository-url>
cd docker-compose-react-nodejs-postgres

# Copy production environment file
cp .env.production .env

# Edit environment variables for your server
nano .env
```

**Update `.env` file with your production values:**
```env
# PostgreSQL Database Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_production_password_here
POSTGRES_DB=production_db

# Server Configuration  
SERVER_PORT=8000
NODE_ENV=production

# Database URL for Prisma (Docker internal networking)
DATABASE_URL=postgresql://postgres:your_secure_production_password_here@postgres:5432/production_db?schema=public

# React Client Configuration
VITE_SERVER_URL=http://your-domain.com:7999
```

### 3. Start the Application

**Build and start all services:**
```bash
# Build and start in detached mode
docker compose up --build -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

### 4. Configure Firewall (if needed)

```bash
# Allow HTTP traffic
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 7999  # API port
sudo ufw allow 4172  # Client port
```

### 5. Setup Reverse Proxy (Optional)

For production, you may want to use Nginx as a reverse proxy:

**Install Nginx:**
```bash
sudo apt install nginx
```

**Create Nginx configuration:**
```bash
sudo nano /etc/nginx/sites-available/your-app
```

**Nginx config example:**
```nginx
server {
    listen 80;
    server_name your-domain.com;

    # Serve React app
    location / {
        proxy_pass http://localhost:4172;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Proxy API requests
    location /api/ {
        proxy_pass http://localhost:7999/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Enable the site:**
```bash
sudo ln -s /etc/nginx/sites-available/your-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## 🔧 Management Commands

### Application Management
```bash
# Stop application
docker compose down

# Start application
docker compose up -d

# Restart application
docker compose restart

# Update application (after code changes)
git pull
docker compose up --build -d

# View logs
docker compose logs -f [service-name]
```

### Database Management
```bash
# Connect to database
docker exec -it database psql -U postgres -d production_db

# Backup database
docker exec database pg_dump -U postgres production_db > backup.sql

# Restore database
docker exec -i database psql -U postgres production_db < backup.sql

# Run migrations manually
docker exec server npx prisma migrate deploy
```

## 🔒 Security Considerations

1. **Change default passwords** in `.env` file
2. **Use strong passwords** for database
3. **Configure firewall** to only allow necessary ports
4. **Use HTTPS** in production (Let's Encrypt with Certbot)
5. **Regular backups** of database
6. **Keep Docker images updated**

## 📊 Monitoring

### Health Checks
```bash
# Check if all services are healthy
docker compose ps

# Test API endpoint
curl http://localhost:7999/users/all?page=1&limit=5

# Test client
curl http://localhost:4172
```

### Resource Usage
```bash
# Monitor resource usage
docker stats

# Check disk usage
docker system df
```

## 🐛 Troubleshooting

### Common Issues

**Database connection errors:**
- Check if PostgreSQL container is running: `docker compose ps`
- Verify environment variables in `.env` file
- Check database logs: `docker compose logs database`

**API not responding:**
- Check server logs: `docker compose logs server`
- Verify DATABASE_URL is correct for Docker networking
- Ensure PostgreSQL is healthy before server starts

**Client not loading:**
- Check client logs: `docker compose logs client`
- Verify VITE_SERVER_URL points to correct API endpoint
- Ensure server is running and accessible

### Log Analysis
```bash
# View all logs
docker compose logs

# Follow logs in real-time
docker compose logs -f

# View specific service logs
docker compose logs server
docker compose logs database
docker compose logs client
```

## 🔄 Environment Differences

### Local Development
- Uses hardcoded defaults in `app.js`
- PostgreSQL on localhost:5431
- Run with: `npm run dev`

### Production Deployment
- Uses environment variables from `.env`
- PostgreSQL via Docker internal networking
- Run with: `docker compose up`

The application automatically detects the environment and configures itself accordingly.

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review Docker Compose logs
3. Verify environment variable configuration
4. Ensure all prerequisites are met
