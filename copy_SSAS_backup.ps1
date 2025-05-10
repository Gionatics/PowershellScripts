Clear-Host

$sourceRootPath = ""
$destinationPath = ""

$databases = @(
    "",
    ""
)

$scriptContent = ""
$robocopyLogs = $destinationPath + "\robocopy" + $(get-date -f MMddyyyyhhmmss) + ".log"

$subfolders = Get-ChildItem -Path $sourceRootPath -Directory

ForEach ($subfolder in $subfolders) {
    $sourcePath = join-path -path $sourceRootPath -ChildPath $subfolder.name   

    Foreach ($database in $databases) {
        $latestBackup = Get-ChildItem -path $sourcePath -Filter "*.abf" -Recurse | Where-Object {$_.Name -like "$database*.abf"} |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

        If ($latestBackup) {
            $sourceFile = join-path -path $sourcePath -ChildPath $latestBackup.name
            $destinationFile = join-path -Path $destinationPath -ChildPath $latestBackup.Name

            $scriptContent += "robocopy `"$sourceFile`" `"$destinationFile`" `"$($latestBackup.Name)`" /COPY:DAT /R:1 /W:1 /log+:$robocopyLogs /tee `n"
            Write-host "Added ROBOCOPY command for backup file '$($latestBackup.Name)' of database '$database' in subfolder '$($subfolder.Name)'"
        }
        else {
            Write-host "No backup file found for database '$database' in subfolder '$($subfolder.Name)'"
        }
    }
}

$scriptPath = $destinationPath + "\robocopy_scripts.txt"
$scriptContent | out-file -FilePath $scriptPath

Invoke-expresssion -command (Get-Content -path $scriptPath -raw)
Write-host "ROBOCOPY Script executed"
