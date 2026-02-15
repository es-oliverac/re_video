FROM node:20-bullseye-slim AS base

RUN apt-get update && apt-get install -y wget gnupg xz-utils && rm -rf /var/lib/apt/lists/*

RUN wget -O /tmp/ffmpeg.tar.xz https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz \
    && mkdir -p /opt/ffmpeg \
    && tar -xf /tmp/ffmpeg.tar.xz -C /opt/ffmpeg --strip-components=1 \
    && ln -s /opt/ffmpeg/bin/ffmpeg /usr/local/bin/ffmpeg \
    && ln -s /opt/ffmpeg/bin/ffprobe /usr/local/bin/ffprobe \
    && rm /tmp/ffmpeg.tar.xz

RUN apt-get update && apt-get install -y \
    ca-certificates fonts-liberation libasound2 libatk-bridge2.0-0 libatk1.0-0 \
    libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgbm1 \
    libgcc1 libglib2.0-0 libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 \
    libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 \
    libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 \
    libxss1 libxtst6 lsb-release xdg-utils chromium \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/chromium /usr/bin/chromium-browser

FROM base AS builder
WORKDIR /app
COPY package*.json ./
COPY lerna.json ./
COPY packages packages
RUN npm ci
RUN mkdir -p /app/node_modules/@ffmpeg-installer/linux-x64 \
    && ln -s /usr/local/bin/ffmpeg /app/node_modules/@ffmpeg-installer/linux-x64/ffmpeg
RUN npx lerna run build

FROM base AS final
WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/lerna.json ./

# Parchear @ffmpeg-installer/linux-x64
RUN mkdir -p /app/node_modules/@ffmpeg-installer/linux-x64 \
    && rm -f /app/node_modules/@ffmpeg-installer/linux-x64/ffmpeg \
    && cp /opt/ffmpeg/bin/ffmpeg /app/node_modules/@ffmpeg-installer/linux-x64/ffmpeg \
    && chmod +x /app/node_modules/@ffmpeg-installer/linux-x64/ffmpeg \
    && echo '{"name":"@ffmpeg-installer/linux-x64","version":"4.1.0","main":"index.js","os":["linux"],"cpu":["x64"]}' > /app/node_modules/@ffmpeg-installer/linux-x64/package.json \
    && echo 'module.exports = { path: require("path").join(__dirname, "ffmpeg"), version: "7.0", url: "local" };' > /app/node_modules/@ffmpeg-installer/linux-x64/index.js

# Parchear @ffprobe-installer/linux-x64
RUN mkdir -p /app/node_modules/@ffprobe-installer/linux-x64 \
    && cp /opt/ffmpeg/bin/ffprobe /app/node_modules/@ffprobe-installer/linux-x64/ffprobe \
    && chmod +x /app/node_modules/@ffprobe-installer/linux-x64/ffprobe \
    && echo '{"name":"@ffprobe-installer/linux-x64","version":"2.1.0","main":"index.js","os":["linux"],"cpu":["x64"]}' > /app/node_modules/@ffprobe-installer/linux-x64/package.json \
    && echo 'module.exports = require("path").join(__dirname, "ffprobe");' > /app/node_modules/@ffprobe-installer/linux-x64/index.js

# Parchear @revideo/2d exports
RUN node -e "var p=require('/app/packages/2d/package.json');p.exports={'.':'./lib/index.js','./jsx-runtime':'./lib/jsx-runtime.js','./jsx-dev-runtime':'./lib/jsx-dev-runtime.js','./*':'./lib/*.js'};require('fs').writeFileSync('/app/packages/2d/package.json',JSON.stringify(p,null,2))"

# Parchear @revideo/core exports
RUN node -e "var p=require('/app/packages/core/package.json');p.exports={'.':'./lib/index.js','./*':'./lib/*.js'};require('fs').writeFileSync('/app/packages/core/package.json',JSON.stringify(p,null,2))"

# Parchear Puppeteer --no-sandbox en renderer
RUN node -e "const fs=require('fs');const p='/app/packages/renderer/lib/server/render-video.js';let c=fs.readFileSync(p,'utf8');const idx=c.indexOf('const args = settings.puppeteer?.args ??');if(idx!==-1){const end=c.indexOf('\\n',idx);c=c.substring(0,idx)+\"const args = settings.puppeteer?.args ?? [];\\n  args.includes('--no-sandbox') || args.push('--no-sandbox');\\n  args.includes('--disable-setuid-sandbox') || args.push('--disable-setuid-sandbox');\\n  \"+c.substring(end);fs.writeFileSync(p,c);}"

RUN mkdir -p /app/projects /app/output

EXPOSE 4000

ENV NODE_ENV=production
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PUPPETEER_LAUNCH_ARGS="--no-sandbox --disable-setuid-sandbox"
ENV CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox"
ENV DISABLE_TELEMETRY=true

CMD ["node", "packages/cli/dist/index.js", "serve", "--projectFile", "/app/projects/default/src/project.ts", "--port", "4000"]