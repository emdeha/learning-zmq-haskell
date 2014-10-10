start cmd.exe /k spworker
start cmd.exe /k spworker
start cmd.exe /k spworker

if "%1"=="c" goto client
if "%1"=="q" goto all

:all 
    start cmd.exe /k spqueue
    start cmd.exe /k lazyPirateClient

:client start cmd.exe /k lazyPirateClient
