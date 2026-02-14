# Multi-stage build para optimizar tamaño de imagen
FROM node:20-bullseye-slim AS base

# Instalar dependencias del sistema para FFmpeg
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Instalar FFmpeg estático
RUN wget -O /tmp/ffmpeg.tar.xz https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz \
    && mkdir -p /opt/ffmpeg \
    && tar -xf /tmp/ffmpeg.tar.xz -C /opt/ffmpeg --strip-components=1 \
    && ln -s /opt/ffmpeg/bin/ffmpeg /usr/local/bin/ffmpeg \
    && ln -s /opt/ffmpeg/bin/ffprobe /usr/local/bin/ffprobe \
    && rm /tmp/ffmpeg.tar.xz

# Instalar dependencias de Puppeteer/Chromium
RUN apt-get update && apt-get install -y \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libgbm1 \
    libgcc1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    lsb-release \
    wget \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Instalar Chromium
RUN apt-get update \
    && apt-get install -y chromium \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/chromium /usr/bin/chromium-browser

# Stage de construcción
FROM base AS builder

WORKDIR /app

# Copiar archivos de configuración de paquetes
COPY package*.json ./
COPY lerna.json ./

# Copiar paquetes individuales
COPY packages packages

# Instalar dependencias
RUN npm ci

# Construir todos los paquetes
RUN npx lerna run build

# Stage final - imagen de producción
FROM base AS final

WORKDIR /app

# Copiar desde builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/lerna.json ./

# Crear directorios necesarios
RUN mkdir -p /app/projects /app/output

# Puerto del servidor
EXPOSE 4000

# Variables de entorno
ENV NODE_ENV=production
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV DISABLE_TELEMETRY=true

# Iniciar servidor
CMD ["node", "packages/cli/dist/index.js", "serve", \
     "--projectFile", "/app/projects/default/src/project.ts", \
     "--port", "4000"]
