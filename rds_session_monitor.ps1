Import-Module -Name Microsoft.RDInfra.RDPowerShell
Import-Module Orchestrator.AssetManagement.Cmdlets -ErrorAction SilentlyContinue


$connectionname = "AzureRunAsConnection"
try
{
    $servicePrincipalConnection=Get-Automationconnection -Name $connectionname
    Login-AzAccount -servicePrincipal -TenantId $servicePrincipalConnection.TenantId -applicationId $servicePrincipalConnection.applicationId -certificateThumbprint $servicePrincipalConnection.certificatethumbprint   
}
catch{
    if (!$serviceprincipalconnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}





# Define Credentials - pull from azure keyvault
$creds = Get-AutomationPSCredential -Name it@antondev.com
$userName = $creds.UserName
$securePassword = $creds.Password
[pscredential]$pscred = New-Object System.Management.Automation.PSCredential ($userName,$securepassword)

#Authenticate to WVD Service
Add-RdsAccount -DeploymentUrl "https://rdbroker.wvd.microsoft.com" -Credential $pscred


#WVD REPORTING


#clean previous connection (not sure if this is needed anymore)
$ServicePoint = [System.Net.ServicePointManager]::FindServicePoint("$influx_url" + "/write?db=azure")
#you could do something like this or manually clear out as required.
$ServicePoint.ConnectionLimit = 10
#start clean
$ServicePoint.CloseConnectionGroup("") | out-null

#Grab the session list and count it 
$final = (Get-RdsUserSession  -TenantName "WVDTenant-5688-1576873280" -HostPoolName "Pool-A" | Measure-Object).count | Select-Object -first 1

#Push the data to influxdb
$influx_url = 'http://wvdgrafana.westus.cloudapp.azure.com:8086'
$uri = ("$influx_url" + "/write?db=azure")
$postParams = "wvd_connections,host=pool-a value=$final"
Invoke-RestMethod -Uri $uri -Method POST -Body $postParams


Write-output "Connection count is $final"

$ServicePoint.CloseConnectionGroup("") |out-null
