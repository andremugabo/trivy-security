# Use official Node.js Alpine image (smaller and more secure)
FROM node:18-alpine

# Set secure defaults
ENV NODE_ENV=production

# Create app directory and non-root user in one layer
RUN mkdir -p /usr/src/app && \
    addgroup -g 1001 appuser && \
    adduser -S -u 1001 -G appuser appuser

WORKDIR /usr/src/app

# Install production dependencies first (security best practice)
COPY package*.json ./
RUN npm ci --omit=dev && \
    npm install cross-spawn@7.0.5 && \
    npm cache clean --force

# Create server.js using a here-doc (most reliable method)
RUN cat <<'EOF' > server.js
const http = require('http');
const spawn = require('cross-spawn');
const server = http.createServer((req, res) => {
  res.writeHead(200, {
    'Content-Type': 'text/plain',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Strict-Transport-Security': 'max-age=63072000; includeSubDomains; preload'
  });
  res.end('Hello from secure container\n');
});

server.listen(3000, '0.0.0.0', () => {
  console.log('Server running at http://localhost:3000/');
});
EOF

# Verify file permissions and content
RUN chown -R appuser:appuser /usr/src/app && \
    chmod -R 750 /usr/src/app && \
    find /usr/src/app -type d -exec chmod 550 {} \; && \
    cat server.js

USER appuser

# Secure health check with timeout
HEALTHCHECK --interval=30s --timeout=5s \
  CMD curl -fsS http://localhost:3000/ || exit 1

# Secure runtime flags for Node.js
EXPOSE 3000
CMD ["node", "--no-deprecation", "--disallow-code-generation-from-strings", "--unhandled-rejections=strict", "server.js"]