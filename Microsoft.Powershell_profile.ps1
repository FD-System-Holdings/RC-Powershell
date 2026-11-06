function Start-Venv {
    <#
    .Synopsis
        Starts (activates) a Python virtual environment.
    .Description
        Finds and activates a Python virtual environment. If a path is provided,
        it activates the environment at that path. If no path is provided, it searches
        the current working directory for common virtual environment folders (.venv, venv, env, .env).
        If no environment is found, it can create one using the -Create switch or via interactive prompt.
    .Parameter Path
        Optional path or folder name of the virtual environment to activate.
    .Parameter Create
        If specified and the virtual environment does not exist, automatically creates it using python/python3.
    .Example
        Start-Venv
        Activates .venv or venv in the current directory.
    .Example
        Start-Venv myenv
        Activates 'myenv' in the current directory.
    .Example
        Start-Venv -Create
        Creates and activates .venv in the current directory if one does not already exist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path,

        [switch]$Create
    )

    $candidateNames = @('.venv', 'venv', 'env', '.env')
    $targetDir = $null
    $activateScript = $null

    # Helper script locator for cross-platform support (Unix: bin/, Windows: Scripts/)
    $findActivate = {
        param([string]$dir)
        $scripts = @(
            Join-Path $dir 'bin' 'Activate.ps1'
            Join-Path $dir 'Scripts' 'Activate.ps1'
        )
        foreach ($s in $scripts) {
            if (Test-Path -Path $s -PathType Leaf) {
                return $s
            }
        }
        return $null
    }

    if ($Path) {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $act = & $findActivate $resolved
        if ($act) {
            $targetDir = $resolved
            $activateScript = $act
        } elseif (Test-Path -Path $resolved) {
            Write-Error "Directory '$Path' exists, but no Activate.ps1 script was found inside bin/ or Scripts/."
            return
        } elseif ($Create) {
            $targetDir = $resolved
        } else {
            Write-Warning "Virtual environment '$Path' not found."
            $answer = Read-Host "Would you like to create and start a virtual environment at '$Path'? [y/N]"
            if ($answer -match '^(y|yes)$') {
                $targetDir = $resolved
                $Create = $true
            } else {
                return
            }
        }
    } else {
        foreach ($name in $candidateNames) {
            $checkPath = Join-Path (Get-Location) $name
            $act = & $findActivate $checkPath
            if ($act) {
                $targetDir = $checkPath
                $activateScript = $act
                break
            }
        }

        if (-not $activateScript) {
            if ($Create) {
                $targetDir = Join-Path (Get-Location) '.venv'
            } else {
                Write-Warning "No virtual environment found (.venv, venv, env, .env)."
                $answer = Read-Host "Would you like to create and start a new virtual environment at ./.venv? [y/N]"
                if ($answer -match '^(y|yes)$') {
                    $targetDir = Join-Path (Get-Location) '.venv'
                    $Create = $true
                } else {
                    return
                }
            }
        }
    }

    # Create virtual environment if requested
    if ($Create -and -not $activateScript) {
        $pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' }
                     elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' }
                     else { $null }

        if (-not $pythonCmd) {
            Write-Error "Python executable ('python3' or 'python') not found in PATH."
            return
        }

        Write-Host "Creating virtual environment at '$targetDir' using $pythonCmd..." -ForegroundColor Cyan
        & $pythonCmd -m venv $targetDir
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -Path $targetDir)) {
            Write-Error "Failed to create virtual environment at '$targetDir'."
            return
        }

        $activateScript = & $findActivate $targetDir
        if (-not $activateScript) {
            Write-Error "Virtual environment was created, but Activate.ps1 could not be located in '$targetDir'."
            return
        }
    }

    if ($activateScript) {
        . $activateScript
        Write-Host "Activated virtual environment: $targetDir" -ForegroundColor Green
    }
}

function Stop-Venv {
    <#
    .Synopsis
        Ends (deactivates) the currently active Python virtual environment.
    .Description
        Invokes the global deactivate function created by Activate.ps1 to restore
        the environment variables (PATH, PYTHONHOME, VIRTUAL_ENV) and prompt back to normal.
    .Example
        Stop-Venv
    #>
    [CmdletBinding()]
    param()

    if (Get-Command -Name 'deactivate' -CommandType Function -ErrorAction SilentlyContinue) {
        $prevVenv = $env:VIRTUAL_ENV
        deactivate
        if ($prevVenv) {
            Write-Host "Deactivated virtual environment: $prevVenv" -ForegroundColor Green
        } else {
            Write-Host "Virtual environment deactivated." -ForegroundColor Green
        }
    } elseif ($env:VIRTUAL_ENV) {
        $prevVenv = $env:VIRTUAL_ENV
        Remove-Item -Path Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
        Write-Host "Stopped virtual environment: $prevVenv" -ForegroundColor Green
    } else {
        Write-Warning "No active Python virtual environment detected."
    }
}
