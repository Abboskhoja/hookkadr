# HOOKKADR API — runs TypeScript directly on Node (type stripping), no build step.
FROM node:26-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src
# Cloud Run sets PORT; credits DB should live on a mounted volume or move to Postgres.
ENV DB_PATH=/data/hookkadr.db
USER node
EXPOSE 8080
CMD ["node", "src/server.ts"]
