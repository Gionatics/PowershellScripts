## Script that checks list of users with server roles, can be embedded in SQL Agent Job: powershell.exe -File "C:\SQLPowershellScripts\Powershell\check_SQL_Server_Roles.ps1"##

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
$reportPath = $folderPath + "Server_Roles.csv"

# Define a list of server roles considered as high privilege
$highPrivilegeRoles = @("sysadmin", "securityadmin", "serveradmin", "setupadmin")

If (Test-Path ($reportPath)) {
    Remove-Item $reportPath -Force
}

# Create an empty array to store the report data
$reportData = @()

# Loop through SQL Server instances
foreach ($instance in $serverInstances) {
    $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($instance)

 # Query server-level roles with high privileges
    $query = @"

SELECT DP1.name AS ServerRoleName, 
    DP2.name AS MemberName
FROM sys.server_role_members AS SRM
    INNER JOIN sys.server_principals AS DP1
        ON SRM.role_principal_id = DP1.principal_id
    INNER JOIN sys.server_principals AS DP2
        ON SRM.member_principal_id = DP2.principal_id
WHERE DP1.type = 'R' 
AND DP2.name NOT LIKE '%##%' 
AND DP2.name NOT LIKE '%NT Service%' 
ORDER BY DP1.name;
"@

        $results = $sqlServer.ConnectionContext.ExecuteWithResults($query)

        # Append the results to the report data
        foreach ($row in $results.Tables[0].Rows) {
            $serverRole = $row["ServerRoleName"]
            if ($highPrivilegeRoles -contains $serverRole.ToLower()) {

                $reportData += [PSCustomObject]@{
                    "Instance" = $instance
                    "MemberName" = $row["MemberName"]
                    "ServerRoleName" = $row["ServerRoleName"]    
                }         
            }
        }
    }

# Export the report data to a CSV file
$reportData | Export-Csv -Path $reportPath -NoTypeInformation

#Check if data extracted is greater than 0 then send email subject and body based on results
$emailSubject = "[SERVER ROLES MSSQL PROD SECURITY AUDIT] DB Users with High Privilege Server roles"

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
