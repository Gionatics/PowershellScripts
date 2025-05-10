# Define the drive to search and the minimum file size (in bytes) for "large" files
Clear

$drive = "D:\"  # Change this to the drive you want to search
$minFileSize = 100MB  # Change this to the desired minimum file size (in bytes)

# Get the server name
$serverName = $env:COMPUTERNAME

# Function to convert size in bytes to a more readable format
function Convert-Size {
    param ($bytes)
    switch ($bytes) {
        {$_ -ge 1PB} {"{0:N2} PB" -f ($bytes / 1PB); break}
        {$_ -ge 1TB} {"{0:N2} TB" -f ($bytes / 1TB); break}
        {$_ -ge 1GB} {"{0:N2} GB" -f ($bytes / 1GB); break}
        {$_ -ge 1MB} {"{0:N2} MB" -f ($bytes / 1MB); break}
        {$_ -ge 1KB} {"{0:N2} KB" -f ($bytes / 1KB); break}
        default {"$bytes Bytes"}
    }
}

# Get large files with their full path, last access time, and size
$largeFiles = Get-ChildItem -Path $drive -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -ge $minFileSize -and $_.Extension -notin @('.ldf', '.mdf', '.ndf', '.iso', '.exe', '.csv', '.vol2', '.zip') } |
    Select-Object @{Name="ServerName";Expression={$serverName}},
                   FullName, 
                   @{Name="LastAccessTime";Expression={$_.LastAccessTime}}, 
                   @{Name="Size";Expression={Convert-Size -bytes $_.Length}} |
    Sort-Object "LastAccessTime"

# Output the result
$largeFiles | Format-Table -AutoSize
