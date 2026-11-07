# Imagem Node.js 24 em Alpine Linux
FROM node:24-alpine

# Define fuso horário padrão (Horário de Brasília)
ENV TZ=America/Sao_Paulo
RUN apk add --no-cache tzdata

WORKDIR /app

# Cria diretório de persistência de dados do SQLite
RUN mkdir -p /app/data && chown node:node /app/data

# Copia os arquivos da aplicação
COPY index.html ./
COPY css ./css
COPY js ./js
COPY server ./server
COPY server.js ./
COPY package.json ./
COPY scripts ./scripts

# Variáveis de ambiente de produção
ENV NODE_ENV=production
ENV PORT=3000
ENV DB_PATH=/app/data/smartcenter.db

EXPOSE 3000
USER node

# Healthcheck nativo
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "const q=require('node:http').get('http://127.0.0.1:3000/api/status',r=>process.exit(r.statusCode===200?0:1));q.setTimeout(4000,()=>process.exit(1));q.on('error',()=>process.exit(1))"

CMD ["node", "server.js"]

