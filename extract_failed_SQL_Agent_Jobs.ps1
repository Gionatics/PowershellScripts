## Extract all SQL agent failed jobs and generate a report thru email ##
## This can be automated by embedding it in SQL Agent Job in MSSQL Instance. Create a job and step calling the powershell script: powershell.exe -File "C:\SQLPowershellScripts\Powershell\failed_SQL_Agent_jobs.ps1"

[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | out-null

#Define the path to the file containing SQL Server Instances
$instancesFilePath = "C:\SQLPowershellScripts\Powershell\SQL_Servers.txt"
$serverInstances = Get-Content -Path $instancesFilePath

#Email Settings -- provide the values here
$smtpServer = ""
$senderEmail = ""
$recipientEmail = ""

#Report dump path
$folderPath = "C:\SQLPowershellScripts\Powershell\Failed SQL Agent Jobs\"
$reportPath = $folderPath + "SQL_Agent_Job_Details.csv"

#If (Test-Path ($reportPath)) {
    #Remove-Item -Path $reportPath -Force
    Get-childitem -path $folderPath -file -recurse | remove-item
#}

# Create an empty array to store the report data
$reportData = @()

# Loop through SQL Server instances
foreach ($instance in $serverInstances) {
    $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($instance)

 # Query failed SQL agent jobs from yesterday to today
    $query = @"
USE msdb;

WITH LastExecutionCTE AS (
    SELECT
        j.name AS JobName,
        
		/*CASE s.last_run_outcome
		WHEN 0 THEN 'Failed'
		ELSE 'Completed'
		END AS 'PreviousOutcome',*/
		
        CASE h.run_status 
		WHEN 0 THEN 'Failed'
		ELSE 'Completed'
		END AS 'CurrentStatus', 
		
        s.step_id AS StepID,
        s.step_name AS StepName,             
        h.run_date AS RunDate,     
        --CONVERT(TIME, STUFF(STUFF(RIGHT('00000' + CAST(h.run_duration AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':')) AS RunDuration
        h.run_duration AS RunDuration
           
    FROM msdb.dbo.sysjobs AS j
    INNER JOIN msdb.dbo.sysjobschedules AS js ON j.job_id = js.job_id
    INNER JOIN msdb.dbo.sysjobservers AS srv ON j.job_id = srv.job_id
    LEFT JOIN msdb.dbo.sysjobhistory AS h ON j.job_id = h.job_id
    INNER JOIN msdb.dbo.sysjobsteps AS s ON h.job_id = s.job_id AND h.step_id = s.step_id
    
    WHERE 
      h.run_status = 0 -- 0 indicates a failed job
      and j.enabled = 1 -- Only enabled jobs
      AND h.run_date BETWEEN CONVERT(INT, CONVERT(VARCHAR, GETDATE()-1, 112)) AND CONVERT(INT, CONVERT(VARCHAR, GETDATE(), 112))
)
SELECT
    JobName,
    --PreviousOutcome,
    CurrentStatus,
    StepID,
    StepName,
    RunDate,
    RunDuration
    
FROM LastExecutionCTE
ORDER BY JobName, StepID DESC;
"@

        $results = $sqlServer.ConnectionContext.ExecuteWithResults($query)

        # Append the results to the report data
        foreach ($row in $results.Tables[0].Rows) {
            $runDate = [datetime]::ParseExact($row["RunDate"].ToString(), "yyyyMMdd", $null)
            $formattedRunDate = $runDate.ToString("dd/MM/yyyy")

            $runDuration = [TimeSpan]::FromSeconds($row["RunDuration"])
            $formattedRunDuration = $runDuration.ToString("hh\:mm\:ss")

            $reportData += [PSCustomObject]@{
                "Instance" = $instance
                "JobName" = $row["JobName"]
                #"PreviousOutcome" = $row["PreviousOutcome"]
                "RunStatus" = $row["CurrentStatus"]
                "StepNo" = $row["StepID"]
                "StepName" = $row["StepName"]
                "RunDate" = $formattedRunDate  
                "RunDuration" = $formattedRunDuration    
            }         
        }
    }

# Export the report data to a CSV file

$reportData | Export-Csv -Path $reportPath -NoTypeInformation

#Check if data extracted is greater than 0 then send email subject and body based on results
$emailSubject = "SQL Agent Failed Jobs"

If ($reportData.Count -gt 0) {
$emailBody = "Please find the attached daily extract for PRODUCTION SQL Server instances with failed agent jobs. Please look into it and fix the issues if necessary."

# Send an email with the report attached
Send-MailMessage -From $senderEmail -To $recipientEmail -Subject $emailSubject -Body $emailBody -SmtpServer $smtpServer -Attachments $reportPath
}
else {
$emailBody = "No SQL Agent failed jobs across all PRODUCTION Instances/Databases"

# Send an email only
Send-MailMessage -From $senderEmail -To $recipientEmail -Subject $emailSubject -Body $emailBody -SmtpServer $smtpServer
}
