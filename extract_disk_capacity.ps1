Clear-Host

if ($null -eq $cred)
{
    $cred = Get-Credential
}

$servers = '',''

$ResultPath = '' #destination path and name of exported txt file

$Results = foreach($server in $servers) {
    Invoke-Command -ComputerName $server {
        $path = '' #change drive letter

        $folders = Get-ChildItem $path |
            Where-Object {$_ -is [io.directoryinfo]} |
            Sort-Object

            ForEach ($folder in $folders) {
                $folderSize = Get-ChildItem $folder.fullname -Recurse - force |
                    Measure-Object -Property Length -sum |
                    Select-Object -ExpandProperty sum

                $properties = @{
                    Directory = $folder.fullname
                    Name = $folder.Name
                    LastWrite = $folder.LastwriteTime
                    FreespaceMB = '{0:N2} MB' -f ($folderSize / 1MB)
                    FreespaceGB = '{0:N2} GB' -f ($folderSize / 1GB)
                }
            New-Object -typename PSCustomObject -Property $properties
            }
    }
    '---------------------------------------------------------------------------'
}

$Results | Select-Object -Property PSComputerName,Directory,Name,LastWrite,FreeSpaceMB,FreeSpaceGB | Format-Table
$Results | Select-Object -Property PSComputerName,Directory,Name,LastWrite,FreeSpaceMB,FreeSpaceGB | Export-csv $ResultPath -NoTypeInformation
