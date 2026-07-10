#!/bin/bash
set -euo pipefail

# Install Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu

# Install Docker Compose plugin
apt-get install -y docker-compose-plugin

# Create application directory
mkdir -p /opt/unimart/nginx
chown -R ubuntu:ubuntu /opt/unimart

# Create docker-compose.prod.yml
cat > /opt/unimart/docker-compose.prod.yml << 'COMPOSE'
services:
  backend:
    image: ${docker_username}/unimart-backend:latest
    env_file: .env.production
    restart: always
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  frontend:
    image: ${docker_username}/unimart-frontend:latest
    restart: always

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - backend
      - frontend
    restart: always
COMPOSE

# Create Nginx config
cat > /opt/unimart/nginx/nginx.conf << 'NGINXCONF'
events {
    worker_connections 1024;
}

http {
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    upstream backend {
        server backend:3000;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://frontend:80;
        }

        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://backend:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /socket.io/ {
            proxy_pass http://backend:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
        }

        location /health {
            proxy_pass http://backend:3000/health;
        }
    }
}
NGINXCONF

# Enable Docker to start on boot
systemctl enable docker
systemctl start docker

echo "UniMart EC2 bootstrap complete!"
