
#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

# Project directory
APP_DIR="/home/ubuntu/backend/Codepipeline-Task"
CONTAINER_NAME="mysefaty-backend"
IMAGE_NAME="mysefaty-backend"
APP_PORT="4000"

echo "Starting Docker deployment..."

# Install Docker if missing
if ! command -v docker >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y docker.io
fi

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Check project directory
if [ ! -d "$APP_DIR" ]; then
    echo "ERROR: Project directory not found: $APP_DIR"
    exit 1
fi

cd "$APP_DIR"

# Check required files
if [ ! -f Dockerfile ]; then
    echo "ERROR: Dockerfile not found in $APP_DIR"
    exit 1
fi

if [ ! -f .env ]; then
    echo "ERROR: .env file not found in $APP_DIR"
    exit 1
fi

# Build Docker image
echo "Building Docker image..."
docker build -t "$IMAGE_NAME" .

# Remove old container if it exists
echo "Removing old container..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Start new container
echo "Starting new container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --env-file "$APP_DIR/.env" \
    -p "$APP_PORT:$APP_PORT" \
    "$IMAGE_NAME"

# Configure Nginx
apt-get install -y nginx

cat > /etc/nginx/sites-available/mysafety-backend <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:4000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/mysafety-backend /etc/nginx/sites-enabled/mysafety-backend
rm -f /etc/nginx/sites-enabled/default

# Validate and restart Nginx
nginx -t
systemctl enable nginx
systemctl restart nginx

# Show deployment status
echo "Checking Docker container..."
docker ps

echo "Docker deployment completed successfully!"
