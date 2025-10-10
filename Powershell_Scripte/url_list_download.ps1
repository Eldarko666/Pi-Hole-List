# Pfad zur URL-Liste
$urlListPath = "url.txt"

# Zielordner
$targetFolder = "blacklist"

# Ordner erstellen, falls nicht vorhanden
if (!(Test-Path -Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder | Out-Null
}

# URLs aus der Datei lesen
$urls = Get-Content $urlListPath

# Jede URL verarbeiten
foreach ($url in $urls) {
    try {
        # Dateiname aus URL extrahieren
        $fileName = Split-Path -Path $url -Leaf

        # Zielpfad
        $destination = Join-Path -Path $targetFolder -ChildPath $fileName

        # Datei herunterladen
        Invoke-WebRequest -Uri $url -OutFile $destination
        Write-Host "Heruntergeladen: $fileName"
    }
    catch {
        Write-Warning "Fehler beim Herunterladen von ${url}"
    }
}
