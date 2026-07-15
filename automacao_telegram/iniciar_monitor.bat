@echo off
TITLE Monitor de Pipeline - SMTR
SETLOCAL

:: ==============================================================================
:: CONFIGURAÇÃO DO CAMINHO DO R
:: ==============================================================================
:: Caminho atualizado com base na sua instalação
SET R_PATH="C:\Users\02626810\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe"

:: Caminho do script de monitoramento
SET SCRIPT_PATH="C:\github_repositories\Monitoramento_Fluxo_Embarques_RedeOnibus\automacao_telegram\monitor_clock.R"
:: ==============================================================================

echo ============================================================
echo        INICIANDO O MONITOR DE EXECUÇÃO DIÁRIA
echo ============================================================
echo Script: %SCRIPT_PATH%
echo Data: %date% %time%
echo.
echo Mantenha esta janela aberta para o monitor funcionar.
echo Para encerrar, feche esta janela ou pressione Ctrl+C.
echo ============================================================
echo.

%R_PATH% %SCRIPT_PATH%

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERRO] Ocorreu um erro ao tentar iniciar o Rscript.
    echo Verifique se o caminho abaixo está correto:
    echo %R_PATH%
    echo.
)

pause
