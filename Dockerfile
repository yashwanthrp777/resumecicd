# =============================================================
# AI Resume Analyzer — Production Multi-Stage Dockerfile
# =============================================================
# Stage 1: Install ALL dependencies (dev + prod) and build
# Stage 2: Install ONLY production dependencies
# Stage 3: Minimal runtime image with build output
# =============================================================

# ---- Stage 1: Builder ----
FROM node:20-alpine AS builder

WORKDIR /app

# Install native build dependencies needed by some npm packages
RUN apk add --no-cache libc6-compat

# Copy dependency manifests first (Docker layer caching optimization)
COPY package.json package-lock.json ./

# Install all dependencies including devDependencies for build
RUN npm ci

# Copy entire source code
COPY . .

# Build the React Router SSR application
RUN npm run build

# ---- Stage 2: Production Dependencies ----
FROM node:20-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./

# Install only production dependencies (no devDependencies)
RUN npm ci --omit=dev

# ---- Stage 3: Runner (Final Production Image) ----
FROM node:20-alpine AS runner

WORKDIR /app

# Set production environment
ENV NODE_ENV=production
ENV PORT=3000

# Create non-root user for security (never run containers as root)
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 apprunner

# Copy build artifacts from builder stage
COPY --from=builder /app/build ./build

# Copy production-only node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy package.json (needed by react-router-serve start script)
COPY --from=builder /app/package.json ./package.json

# Copy public assets (favicons, images, pdf worker, etc.)
COPY --from=builder /app/public ./public

# Set ownership to non-root user
RUN chown -R apprunner:nodejs /app

# Switch to non-root user
USER apprunner

# Expose application port
EXPOSE 3000

# Health check — ensures container is serving traffic
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

# Start the production server
CMD ["npm", "run", "start"]