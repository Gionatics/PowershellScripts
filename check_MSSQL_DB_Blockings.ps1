[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | out-null

clear

# --- Configuration ---
$InstanceListPath = "C:\SQLPowershellScripts\Powershell\SQL_Servers.txt"  # List of SQL Server instances
$From = "" # Set Sender
$To = "" # Set Recipients
$SmtpServer = "" # Set SMTP

# --- Read Instances ---
$Instances = Get-Content $InstanceListPath

foreach ($SqlServer in $Instances) {
    #Write-Output "Checking blocking on $SqlServer"

    $Query = @"
SELECT 
    r.blocking_session_id AS BlockingSessionID,
    r.session_id AS BlockedSessionID,
    r.wait_type,
    r.wait_time,
    r.wait_resource,
    DB_NAME(r.database_id) AS DatabaseName,
    r.status,
    s.login_name AS LoginName,
    s.host_name AS HostName,
    t.text AS SqlText
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0;
"@

    try {
        $BlockingResults = Invoke-Sqlcmd -ServerInstance $SqlServer -Query $Query -ErrorAction Stop

        if ($BlockingResults.Count -gt 0) {
            #Write-Output "Blocking detected on $SqlServer in DB(s): " + ($BlockingResults | Select-Object -ExpandProperty DatabaseName | Sort-Object -Unique -Join ", ")

            $Subject = "Blocking Detected on $SqlServer"

            $Body = "Blocking sessions detected on SQL Server instance ${SqlServer}:`n`n"

            foreach ($row in $BlockingResults) {
                $maxLength = 300
                $shortQuery = if ($row.SqlText.Length -gt $maxLength) {
                    $row.SqlText.Substring(0, $maxLength) + "..."
                } else {
                    $row.SqlText
                }

                $Body += @"
Blocked SPID: $($row.BlockedSessionID), Blocking SPID: $($row.BlockingSessionID)
Login: $($row.LoginName), Host: $($row.HostName)
DB: $($row.DatabaseName), WaitType: $($row.wait_type), WaitTime: $($row.wait_time)
Query: $shortQuery

"@
            }

            # Send Alert Email
            Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SmtpServer $SmtpServer
        }
        #else {
        #    Write-Output "No blocking detected on $SqlServer."
        #}
    }
    catch {
        #Write-Warning "Failed to query $SqlServer. Error: $_"
    }
}
