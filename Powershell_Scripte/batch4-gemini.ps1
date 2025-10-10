# --- Einstellungen ---
$cleanFolder = "C:\Users\peter\Downloads\URL_Block_Listen"
$finalFile   = "C:\Users\peter\Downloads\endlist.txt"

if (-not (Test-Path $cleanFolder)) {
    Throw "Ordner nicht gefunden: $cleanFolder"
}

# --- Vorbereitung ---
if (Test-Path $finalFile) { Remove-Item -LiteralPath $finalFile -Force }

$files = Get-ChildItem -Path $cleanFolder -Filter *.txt -File | Sort-Object Name
if ($files.Count -eq 0) {
    Write-Host "Keine .txt-Dateien gefunden in: $cleanFolder" -ForegroundColor Yellow
    exit 0
}

# --- Thread-Konfiguration ---
$maxThreads = [Environment]::ProcessorCount
Write-Host "Starte Runspace-Zusammenführung mit bis zu $maxThreads Threads..." -ForegroundColor Cyan

# --- Thread-sichere globale Sammlung (ConcurrentBag) ---
$bagType = [System.Collections.Concurrent.ConcurrentBag[string]]
$bag = [Activator]::CreateInstance($bagType)

# --- Phase 1: Paralleles Einlesen & Vorbereinigen mit Runspaces ---

# 1. Benötigte Klassen laden
Add-Type -AssemblyName System.Management.Automation

# 2. Runspace Pool einrichten
$runspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $maxThreads)
$runspacePool.Open()

$scripts = @()
$syncHash = [hashtable]::Synchronized(@{}) # Für die Übergabe thread-sicherer Variablen

# 3. Variablen an Runspaces übergeben
$syncHash.Add("bag", $bag)

# 4. Skriptblock definieren (die eigentliche Arbeit)
$scriptBlock = {
    param($filePath, $syncHash) # Der Pfad wird als Argument übergeben
    
    # Zugriff auf die thread-sichere Variable über den Hash
    $bag = $syncHash["bag"] 
    
    try {
        $lines = [System.IO.File]::ReadLines($filePath)

        foreach ($ln in $lines) {
            if ([string]::IsNullOrWhiteSpace($ln)) { continue }
            if ($ln -match '^\s*#') { continue }
            
            $bag.Add($ln)
        }

        $fileName = [System.IO.Path]::GetFileName($filePath)
        return "OK: $fileName"
    }
    catch {
        $fileName = [System.IO.Path]::GetFileName($filePath)
        return "ERROR: $fileName – $($_.Exception.Message)"
    }
}

# 5. Pipeline für jede Datei erstellen und asynchron starten
foreach ($file in $files) {
    $powershell = [System.Management.Automation.PowerShell]::Create()
    $powershell.RunspacePool = $runspacePool
    
    # Argumente: Der Pfad und der Hash-Tabelle
    [void]$powershell.AddScript($scriptBlock).AddArgument($file.FullName).AddArgument($syncHash)
    
    # Asynchron starten
    $scripts += [PSCustomObject]@{
        Handle = $powershell.BeginInvoke()
        PowerShell = $powershell
    }
}

# 6. Auf Abschluss warten und Ergebnisse auslesen
Write-Host "Warte auf Threads..."
foreach ($script in $scripts) {
    $script.PowerShell.EndInvoke($script.Handle) | ForEach-Object { Write-Host $_ }
    $script.PowerShell.Dispose()
}

$runspacePool.Close()
$runspacePool.Dispose()

# --------------------------------------------------------------------------------------------------

# --- Phase 2: Globale Deduplizierung & Sortierung (im Speicher) ---
Write-Host "`nErstelle finale, deduplizierte und sortierte Liste..." -ForegroundColor Cyan

# Die $bag enthält nun die gesammelten Daten.
# 1. Globale Deduplizierung
$seenGlobal = [System.Collections.Generic.HashSet[string]]::new($bag)

# 2. Sortierung
$result = [System.Collections.Generic.List[string]]::new($seenGlobal)
$result.Sort() 

Write-Host "Deduplizierung und Sortierung abgeschlossen."

# --------------------------------------------------------------------------------------------------

# --- Phase 3: Ausgabe ---
Write-Host "`nSchreibe Ergebnis in Datei..." -ForegroundColor Cyan

[System.IO.File]::WriteAllLines($finalFile, $result, [System.Text.UTF8Encoding]::new($false))

Write-Host "`nZusammenführung abgeschlossen: $finalFile" -ForegroundColor Green
Write-Host ("Zeilen insgesamt: {0:N0}" -f $result.Count)