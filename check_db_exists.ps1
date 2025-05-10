Clear-Host

$sourceServer = '' #Source Instance
$fullDir = "" #path to check
$databasesPath = ($fullDir + "DatabaseList.txt")
$databasestoCheck = Get-Content $databasesPath

$sourceConn = New-Object System.Data.SqlClient.SqlConnection("Server=$sourceServer;Integrated Security=True")
$sourceConn.Open()

$output = @()

foreach($sourceDBName in $databasestoCheck) {
    $sourceCmd = New-Object System.Data.SqlClient.SqlCommand("Select name from sys.databases",$sourceConn)
    $sourceReader = $sourceCmd.ExecuteReader()

    If ($sourceReader.HasRows)
    {
        $destinationServer = '' #destination instance
        $destinationConn = new-object System.Data.SqlClient.SqlConnection("Server = $destinationServer;Integrated Security=True")
        $destinationConn.Open()

        $destinationCmd = New-Object System.Data.SqlClient.SqlCommand("SELECT COUNT(*) FROM sys.databases WHERE name = '$sourceDBName'",$destinationConn)
        $count = $destinationCmd.ExecuteScalar()

        If ($count -gt 0) {
            Write-Output "Database $sourceDBName exists on destination server."
        }
        else {
            $output += $sourceDBName
        }

        $destinationConn.Close()
        $sourceReader.Close()
    }
    else {
        Write-Output "Database $sourceDBName does not exist on source server."
    }
}

Write-output "Writing output to directory/file: " $databasesPath
$output | out-file -filepath ($fulldir + "MissingDbs.txt")
