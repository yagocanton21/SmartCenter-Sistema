@echo off
chcp 65001 >nul
title SmartCenter - Servidor SQLite
cd /d "%~dp0"

echo ======================================================
echo    SMARTCENTER - ASSISTENCIA TECNICA (SQLITE)
echo ======================================================
echo.

where node >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ATENÇÃO] O Node.js não foi encontrado no seu computador.
    echo.
    echo Para usar com banco de dados SQLite, instale o Node.js em:
    echo https://nodejs.org/
    echo.
    echo Abrindo o sistema em modo navegador local (localStorage)...
    start index.html
    pause
    exit /b
)

echo Iniciando o servidor SQLite em smartcenter.db...
echo O navegador será aberto automaticamente em alguns instantes.
echo.

start "" "http://localhost:3000"

node server.js
pause

