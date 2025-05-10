## Script to generate list of orphaned users in MSSQL database, can be embedded in SQL Agent job: powershell.exe -File "C:\SQLPowershellScripts\Powershell\check_SQL_Orphaned_Users_v1.ps1"

[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | out-null

#Define the path to the file containing SQL Server Instances
$instancesFilePath = "C:\SQLPowershellScripts\Powershell\SQL_Servers.txt"
$serverInstances = Get-Content -Path $instancesFilePath

# Email Settings -- provide values here
$smtpServer = ""
$senderEmail = ""
$recipientEmail = ""

#Report dump path
$folderPath = "C:\SQLPowershellScripts\Powershell\MSSQL Audit\"
$reportPath = $folderPath + "Orphaned_Users.csv"

If (Test-Path ($reportPath)) {
    Remove-Item $reportPath -Force
}

# Create an empty array to store the report data
$reportData = @()

# Loop through SQL Server instances
foreach ($instance in $serverInstances) {
    $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($instance)
    
        # Define the databases you want to check on each instance excluding system databases (master,msdb,etc...)
    $databases = $sqlServer.Databases | Where-Object { $_.IsSystemObject -eq $false }
    
    # Loop through databases
    foreach ($database in $databases) {
        $databaseName = $database.Name

 # Query server-level roles with high privileges
    $query = @"
USE $databaseName

SELECT name, 'USE [$databaseName] DROP USER ' + name + ';' AS 'DropStatement'
FROM sysusers
WHERE issqluser = 1 AND (sid IS NOT NULL AND sid <> 0x0)
AND name NOT IN ('dbo') 
AND NOT EXISTS (SELECT 1 FROM master.sys.server_principals WHERE sid = sysusers.sid);
"@

        $results = $database.ExecuteWithResults($query)

        # Append the results to the report data
        foreach ($row in $results.Tables[0].Rows) {
            $reportData += [PSCustomObject]@{
                "Instance" = $instance
                "DBName" = $databaseName
                "OrphanedUser" = $row["name"]
                "DropStatement" = $row["DropStatement"]             
            }
        }
    }
}
# Export the report data to a CSV file
$reportData | Export-Csv -Path $reportPath -NoTypeInformation

#Check if data extracted is greater than 0 then send email subject and body based on results
$emailSubject = "[ORPHANED USERS MSSQL PROD SECURITY AUDIT] DB Users with no associated DB"

If ($reportData.Count -gt 0) {
$emailBody = "Please find the attached report for PRODUCTION SQL Server database users Server roles with high privileges. Please look into it and apply restrictions if necessary."

# Send an email with the report attached
Send-MailMessage -From $senderEmail -To $recipientEmail -Subject $emailSubject -Body $emailBody -SmtpServer $smtpServer -Attachments $reportPath
}
else {
$emailBody = "No users found with high privilege Server roles across all PRODUCTION Instances/Databases"

# Send an email only
Send-MailMessage -From $senderEmail -To $recipientEmail -Subject $emailSubject -Body $emailBody -SmtpServer $smtpServer
}
