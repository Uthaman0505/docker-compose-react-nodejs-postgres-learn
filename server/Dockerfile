# Multi-stage build for optimized production image
FROM node:18-alpine AS base
WORKDIR /app

# Dependencies stage - install production dependencies
FROM base AS deps
RUN apk add --no-cache libc6-compat openssl
COPY package*.json ./
# Install dependencies and clean cache
RUN npm ci --only=production && npm cache clean --force

# Build stage - install all dependencies and generate Prisma client
FROM base AS builder
RUN apk add --no-cache libc6-compat openssl
COPY package*.json ./
RUN npm ci
COPY . .
# Generate Prisma client
RUN npx prisma generate

# Production stage - minimal runtime image
FROM node:18-alpine AS runner
WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache openssl

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nodejs

# Copy production dependencies
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules
# Copy application code and generated Prisma client
COPY --from=builder --chown=nodejs:nodejs /app/src ./src
COPY --from=builder --chown=nodejs:nodejs /app/prisma ./prisma
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

# Switch to non-root user
USER nodejs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8000/users/all?page=1\&limit=1 || exit 1

EXPOSE 8000

CMD ["npm", "start"]