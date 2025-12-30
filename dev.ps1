$ScriptRoot = $PSScriptRoot

# Start Backend
Write-Host "Starting Backend..."
Start-Process -FilePath "powershell" -ArgumentList "-NoExit", "-Command", "cd rin_agent; cargo run dev" -WorkingDirectory $ScriptRoot

# Start Frontend
Write-Host "Starting Frontend..."
Start-Process -FilePath "powershell" -ArgumentList "-NoExit", "-Command", "cd rin_agent_front; bun run dev" -WorkingDirectory $ScriptRoot
