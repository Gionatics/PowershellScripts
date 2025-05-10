Clear-Host

$servers = '',''

$results = @()

foreach ($server in $servers) {
    $timezone = Get-WmiObject -Class win32_timezone -ComputerName $server
    $plan = Get-WmiObject -class win32_powerplan -ComputerName $server -Namespace "root\cimv2\power" | Where-Object {$_.isActive -eq $true}

    $obj = New-Object -type PSCustomObject -Property @{
        Server = $server
        TimezoneCaption = $timezone.Caption
        TimezoneName = $timezone.StandardName
        PowerPlane = $plan.ElementName
    }

    $Results += $obj
}

Write-output $results | Format-Table
