## Script to generate list of db user permissions with high privileges. Can be integrated in SQL Agent Job: powershell.exe -File "C:\SQLPowershellScripts\Powershell\check_SQL_DB_Permissions.ps1"

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
$reportPath = $folderPath + "DB_Permissions.csv"

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

        # Query database users with high privileges

$query = @"
USE [$databaseName];
SELECT DP1.name AS DatabaseRoleName, 
    DP2.name AS MemberName
FROM sys.database_role_members AS DRM
    INNER JOIN sys.database_principals AS DP1
        ON DRM.role_principal_id = DP1.principal_id
    INNER JOIN sys.database_principals AS DP2
        ON DRM.member_principal_id = DP2.principal_id
WHERE (DP1.name = 'db_owner' OR DP1.name LIKE '%admin%') AND (DP2.name NOT IN ('dbo') 
AND DP2.name NOT LIKE '%$' AND DP2.name NOT LIKE '%##%')
ORDER BY DP1.name,DP2.name
"@

        $results = $database.ExecuteWithResults($query)

        # Append the results to the report data
        foreach ($row in $results.Tables[0].Rows) {
            $reportData += [PSCustomObject]@{
                "Instance" = $instance
                "Database" = $database
                "MemberName" = $row["MemberName"]
                "DatabaseRoleName" = $row["DatabaseRoleName"]             
            }
        }
    }
}

# Export the report data to a CSV file
$reportData | Export-Csv -Path $reportPath -NoTypeInformation

#Check if data extracted is greater than 0 then send email subject and body based on results
$emailSubject = "[DB PERMISSIONS MSSQL PROD SECURITY AUDIT] DB Users with High Privilege DB permissions"

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
