# Imposta la cartella di destinazione
$env:USERPROFILE
$baseFolder = Join-Path $env:USERPROFILE "Desktop\midi\vittoriain"
New-Item -ItemType Directory -Path $baseFolder -Force | Out-Null

# Scarica l'indice principale
$page = Invoke-WebRequest -Uri "http://www.vittoriain.it/basi_karaoke.htm" -UseBasicParsing

# Trova tutti i link ai file .mid
$midLinks = ($page.Links | Where-Object { $_.href -match '\.mid$' })

# Liste per tracciare i file scaricati e gli errori
$scaricati = @()
$errori = @()

# Scarica ogni file
foreach ($link in $midLinks) {
    $relativePath = $link.href.TrimStart("/")
    $url = "http://www.vittoriain.it/$relativePath"

    # Estrae il nome della cartella e del file
    $parts = $relativePath -split "/"
    if ($parts.Length -lt 3) { continue }  # Esclude link strani
    $folderName = $parts[1] -replace '[\\/:*?"<>|]', '_'
    $fileName   = $parts[2] -replace '[\\/:*?"<>|]', '_'

    # Crea la cartella di destinazione
    $targetFolder = Join-Path $baseFolder $folderName
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null

    # Percorso completo del file
    $targetFile = Join-Path $targetFolder $fileName

    # Scarica il file se non esiste già
    if (-not (Test-Path $targetFile)) {
        Write-Host "Scarico: $fileName in $folderName"
        try {
            Invoke-WebRequest -Uri $url -OutFile $targetFile -UseBasicParsing -ErrorAction Stop
            $scaricati += "$folderName\$fileName"
        } catch {
            Write-Warning "Errore scaricando ${fileName} in ${folderName}: $_"

            # Aggiunge oggetto con nome e link
            $errori += [PSCustomObject]@{
                Percorso = "$folderName\$fileName"
                Link     = $url
            }
        }
        Start-Sleep -Milliseconds 300
    } else {
        Write-Host "Già presente: $fileName"
    }
}

# --- RESOCONTO FINALE ---
Write-Host "`n--- RESOCONTO ---"
Write-Host "Totale file scaricati: $($scaricati.Count)"
if ($scaricati.Count -gt 0) {
    Write-Host "`nElenco dei file scaricati:"
    $scaricati | ForEach-Object { Write-Host " ✅ $_" }
} else {
    Write-Host "Nessun file nuovo scaricato."
}

if ($errori.Count -gt 0) {
    Write-Host "`nFile con errore di download: $($errori.Count)"
    foreach ($errore in $errori) {
        Write-Host " ❌ $($errore.Percorso)"
        Write-Host "     Link diretto: $($errore.Link)"
    }
} else {
    Write-Host "`nNessun errore di download."
}
