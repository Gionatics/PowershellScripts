#Create Availability groupt (Top to bottom) - Run each step (Highlight the step and press F8)
clear

#Step 1 - Import DBAtools
import-module DBAtools

#Authentication
if ($cred -eq $null)
{
    $cred = Get-Credential -Message 'Please enter pwd'
}

#Parameters
$defaultDB = '' #master
$primary = '' #primary replica
$secondary = '' #secondary replica
$agname = ''
$listenername = ''
$listener_port = ''
$ips = '',''
$db = ''
$availabilityMode = '' #Sync or Async commit
$failoverMode = '' #Automatic or Manual

#remove database on secondary replica
$qry = "DROP DATABASE [$db]"

Invoke-DbaQuery -SQLInstance $secondary -Query $qry -database $defaultDB -SqlCredential $cred

#Step 1 - add availability group
New-DbaAvailabilityGroup -Primary $primary -Secondary $secondary -Name $agname 
-PrimarySqlCredential $cred -SecondarySqlCredential $cred -AvailabilityMode $availabilityMode
-FailoverMode $failoverMode -ClusterType Wsfc -Confirm:$false

#Step 2 - add listener
Add-DbaAGListener -SQLInstance $primary -AvailabilityGroup $agname -IPAddress $ips -SubnetMask 255.255.255.0
-SqlCredential $cred -Name $listenername -Port $listener_port

#Step 3 - add database
Add-DbaAGDatabase -SQLInstance $primary -Secondary $secondary -AvailabilityGroup $agname -Database $db -UseLastBackup -SqlCredential $cred
-SecondarySqlCredential $cred
