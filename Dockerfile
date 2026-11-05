# Imagem Node.js 22 LTS em Alpine Linux (Ultra leve ~140MB)
FROM node:22-alpine

# Define fuso horário padrão (Horário de Brasília)
ENV TZ=America/Sao_Paulo
RUN apk add --no-cache tzdata

WORKDIR /app

# Cria diretório de persistência de dados do SQLite
RUN mkdir -p /app/data

# Copia os arquivos da aplicação
COPY index.html ./
COPY css ./css
COPY js ./js
COPY server ./server
COPY server.js ./

# Variáveis de ambiente de produção
ENV NODE_ENV=production
ENV PORT=3000
ENV DB_PATH=/app/data/smartcenter.db

EXPOSE 3000

# Healthcheck nativo
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "require('node:http').get('http://localhost:3000/api/status', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

CMD ["node", "server.js"]

