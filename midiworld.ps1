# Cartella base di destinazione cambiare "nome cartella utente" con il nome del proprio utente
$baseFolder = "C:\Users\nome cartella utente\Desktop\midiworld"
New-Item -ItemType Directory -Path $baseFolder -Force | Out-Null

# Lista per tracciare download ed errori
$scaricati = @()
$errori = @()

# Numero massimo file
$maxID = 5000

for ($id = 1; $id -le $maxID; $id++) {
    $url = "https://www.midiworld.com/download/$id"

    try {
        # Scarica il file temporaneamente in una cartella temp per leggere il nome
        $tempFolder = Join-Path $baseFolder "temp"
        New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

        # Scarica con nome temporaneo
        $tempFile = Join-Path $tempFolder "tempfile.mid"

        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing -ErrorAction Stop

        # Ottieni il nome vero del file dal Content-Disposition header se presente
        $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -ErrorAction Stop
        $cd = $response.Headers["Content-Disposition"]

        if ($cd -match 'filename="?([^"]+)"?') {
            $fileName = $Matches[1]
        } else {
            $fileName = "$id.mid"
        }

        # Sostituisci underscore con spazi nel nome file
        $fileName = $fileName -replace '_', ' '

        # Estrai il nome artista: tutto ciò che precede il trattino "-"
        if ($fileName -match '^(.*?) -') {
            $artista = $Matches[1].Trim()
        } else {
            # Se non c'è trattino, usa "Sconosciuto"
            $artista = "Sconosciuto"
        }

        # Crea cartella artista
        $artistFolder = Join-Path $baseFolder $artista
        New-Item -ItemType Directory -Path $artistFolder -Force | Out-Null

        # Percorso finale file
        $targetFile = Join-Path $artistFolder $fileName

        if (-not (Test-Path $targetFile)) {
            Move-Item -Path $tempFile -Destination $targetFile
            Write-Host "Scaricato $fileName in $artista"
            $scaricati += [PSCustomObject]@{
                ID = $id
                Artista = $artista
                File = $fileName
            }
        } else {
            # File già esistente
            Remove-Item $tempFile
            Write-Host "File già presente: $fileName"
        }

    } catch {
        # Rimuovi il file temporaneo se presente in caso di errore
        if (Test-Path $tempFile) { Remove-Item $tempFile }
        $errorMsg = $_.Exception.Message
        Write-Warning ("Errore con ID " + $id + ": " + $errorMsg)
        $errori += [PSCustomObject]@{
            ID = $id
            URL = $url
            Errore = $errorMsg
        }
    }
}

# Elenco scaricati
Write-Host "`n--- RESOCONTO ---"
Write-Host "Totale scaricati: $($scaricati.Count)"
Write-Host "Totale errori: $($errori.Count)"

if ($scaricati.Count -gt 0) {
    Write-Host "`nFile scaricati:"
    $scaricati | ForEach-Object { Write-Host "$($_.File) - $($_.Artista)" }
}

if ($errori.Count -gt 0) {
    Write-Host "`nErrori durante il download:"
    $errori | ForEach-Object { Write-Host "ID $($_.ID): $($_.Errore)" }
}
