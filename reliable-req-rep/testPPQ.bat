start cmd.exe /k ppqueue
for %%i in (1,2) do (
    start cmd.exe /k ppworker
    sleep 1
)
start cmd.exe /k lazyPirateClient
