Clear-Host

$servers = '',''

$results = foreach ($server in $servers) {
    Invoke-Command -ComputerName $server {
        Get-DtcNetworkSetting
    }
}

$results | Select-Object * | Format-Table
