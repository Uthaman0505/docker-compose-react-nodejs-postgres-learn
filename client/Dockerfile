# Multi-stage build for optimized production image
FROM node:18-alpine AS base
WORKDIR /app

# Dependencies stage - install production dependencies
FROM base AS deps
RUN apk add --no-cache libc6-compat
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Build stage - build the React application
FROM base AS builder
ARG VITE_SERVER_URL=http://localhost:7999
ENV VITE_SERVER_URL=$VITE_SERVER_URL

RUN apk add --no-cache libc6-compat
COPY package*.json ./
RUN npm ci
COPY . .
# Build the React application
RUN npm run build

# Production stage with Nginx
FROM nginx:alpine AS runner
WORKDIR /usr/share/nginx/html

# Create non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nodejs

# Remove default nginx static assets
RUN rm -rf ./*

# Copy built assets from builder stage
COPY --from=builder /app/dist .

# Copy custom nginx configuration
COPY --from=builder /app/nginx.conf /etc/nginx/conf.d/default.conf 2>/dev/null || echo 'server {
    listen 4173;
    listen [::]:4173;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    
    # Handle client-side routing
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # API proxy (optional)
    location /api/ {
        proxy_pass http://server:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Static assets caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src '\''self'\'' http: https: data: blob: '\''unsafe-inline'\''" always;
}' > /etc/nginx/conf.d/default.conf

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4173/ || exit 1

EXPOSE 4173

# Start nginx
CMD ["nginx", "-g", "daemon off;"]