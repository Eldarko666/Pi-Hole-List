# --- Einstellungen ---
$finalFile = "C:\Users\peter\Downloads\endlist.txt"
$whiteListFile = "C:\Users\peter\Downloads\whitelist.txt"
$backupFile = "C:\Users\peter\Downloads\endlist_backup_$(Get-Date -Format yyyyMMddHHmmss).txt"

# --- 1. Vorab-Prüfung ---
Write-Host "Starte Whitelist-Anwendung..." -ForegroundColor Cyan

if (-not (Test-Path $finalFile)) {
    Throw "Endliste nicht gefunden: $finalFile. Bitte zuerst das Zusammenführungs-Skript ausführen."
}

if (-not (Test-Path $whiteListFile)) {
    Write-Host "WARNUNG: Whitelist-Datei nicht gefunden: $whiteListFile" -ForegroundColor Yellow
    Write-Host "Es wurden keine Einträge entfernt. Skript wird beendet."
    exit 0
}

# --- 2. Whitelist laden und bereinigen ---

# Das Laden in ein HashSet macht das spätere Suchen extrem schnell (O(1) Zeitkomplexität).
Write-Host "Lade und bereinige Whitelist-Einträge..." -ForegroundColor Yellow
$whiteListSet = [System.Collections.Generic.HashSet[string]]::new()
$removedCount = 0

try {
    # Zeilen aus der Whitelist laden
    $whiteLines = [System.IO.File]::ReadLines($whiteListFile)
    
    foreach ($ln in $whiteLines) {
        # Bereinigung: Leere Zeilen und Kommentare ignorieren (wie im ersten Skript)
        if ([string]::IsNullOrWhiteSpace($ln)) { continue }
        if ($ln -match '^\s*#') { continue }
        
        # Füge nur eindeutige, bereinigte Einträge dem HashSet hinzu
        $whiteListSet.Add($ln) | Out-Null
    }

    Write-Host ("Eindeutige Whitelist-Einträge geladen: {0:N0}" -f $whiteListSet.Count)
    
} catch {
    Throw "Fehler beim Lesen der Whitelist: $($_.Exception.Message)"
}

# --- 3. Endliste verarbeiten und filtern ---

Write-Host "Erstelle Backup der Original-Endliste..." -ForegroundColor Cyan
Copy-Item -Path $finalFile -Destination $backupFile -Force | Out-Null
Write-Host "Backup erstellt: $backupFile" -ForegroundColor DarkCyan

Write-Host "Filtere Endliste anhand der Whitelist..." -ForegroundColor Cyan

# Lade die zu filternde Endliste in eine veränderbare Liste
$finalLines = [System.IO.File]::ReadAllLines($finalFile)
$initialCount = $finalLines.Count

# Erstelle eine neue Liste für die gefilterten Ergebnisse
$filteredList = [System.Collections.Generic.List[string]]::new()

foreach ($line in $finalLines) {
    # Prüfe extrem schnell, ob der Eintrag in unserem HashSet der Whitelist enthalten ist
    if ($whiteListSet.Contains($line)) {
        $removedCount++
        continue # Eintrag ist auf der Whitelist, überspringe ihn (wird entfernt)
    }
    
    # Eintrag ist nicht auf der Whitelist, füge ihn zur neuen Liste hinzu
    $filteredList.Add($line)
}

# --- 4. Ergebnis ausgeben ---
Write-Host "`nSchreibe die gefilterte Liste zurück in die Datei..." -ForegroundColor Cyan

# Überschreibe die ursprüngliche endlist.txt mit der gefilterten Liste
[System.IO.File]::WriteAllLines($finalFile, $filteredList, [System.Text.UTF8Encoding]::new($false))

Write-Host "`nWhitelist-Anwendung abgeschlossen!" -ForegroundColor Green
Write-Host ("Zeilen ursprünglich: {0:N0}" -f $initialCount)
Write-Host ("Zeilen entfernt (Whitelisted): {0:N0}" -f $removedCount)
Write-Host ("Zeilen final: {0:N0}" -f $filteredList.Count)