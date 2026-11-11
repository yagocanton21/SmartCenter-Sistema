#!/bin/sh
set -eu

# Build before stopping the current application. Never delete a data volume.
docker compose build
backup_dir="$PWD/backups/deploy-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$backup_dir"
if docker inspect smartcenter-app >/dev/null 2>&1; then
  docker stop smartcenter-app >/dev/null
  # The persistent production database is located in the smartcenter-data volume at /app/data/smartcenter.db.
  source_path=/app/data/smartcenter.db
  if ! docker cp "smartcenter-app:$source_path" "$backup_dir/smartcenter.db" 2>/dev/null; then
    source_path=/app/smartcenter.db
    if ! docker cp "smartcenter-app:$source_path" "$backup_dir/smartcenter.db"; then
      docker start smartcenter-app >/dev/null
      echo 'Backup não criado; implantação interrompida.' >&2
      exit 1
    fi
  fi
  for suffix in -wal -shm .key; do
    docker cp "smartcenter-app:$source_path$suffix" "$backup_dir/smartcenter.db$suffix" 2>/dev/null || true
  done
  # Import only into an empty volume. The old stopped container is still available.
  if ! docker compose run --rm --no-deps --user root -v "$backup_dir:/import:ro" --entrypoint node smartcenter -e '
    const fs=require("node:fs");
    if(!fs.existsSync("/app/data/smartcenter.db")) {
      for(const name of fs.readdirSync("/import")) {
        const target="/app/data/"+name;
        fs.copyFileSync("/import/"+name,target);fs.chownSync(target,1000,1000);
      }
      fs.chownSync("/app/data",1000,1000);
    }'; then
    docker start smartcenter-app >/dev/null
    exit 1
  fi
fi
if ! docker compose up -d --wait --wait-timeout 90; then
  echo "Falha no healthcheck. Backup preservado em $backup_dir. Consulte README.md para recuperação." >&2
  exit 1
fi
docker compose exec -T smartcenter node -e '
  (async()=>{
    const base="http://127.0.0.1:3000";
    for(const [url,status] of [["/api/status",200],["/api/db",401],["/smartcenter.db",404],["/server.js",404]]) {
      const response=await fetch(base+url);
      if(response.status!==status)throw new Error(url+": "+response.status);
    }
  })().catch(error=>{console.error(error);process.exit(1)});'
echo "Implantação validada. Backup anterior: $backup_dir"
