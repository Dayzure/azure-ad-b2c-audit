## Use this script to quickly analyse your current Azure AD B2C Tenant
## Please use cloud only user (Global Admin) local to your B2C tenant
## This script uses Azure AD PowerShell for MS Graph + Azure AD PowerShell for Graph preview modeules
## http://bit.ly/aad-ps-msgraph
## http://bit.ly/aad-ps-msgraph-preview
## You must have both the modules to run this script
## The information is based on the Audit Logs of Azure AD B2C, which is only there for 7 days
## If you need to query data for more than 7 days, then you must export your Azure AD B2C Audit Logs 
## Read More about how to export Azure AD B2C Audit Logs to Log Analytics Workspace:
## http://bit.ly/b2c-monitor

Disconnect-AzureAD
Connect-AzureAD

$users = Get-AzureADUser -Filter "creationType eq 'localAccount'" -All $true
$totalUsers = $users.Count
Write-Host "You have a total of $totalUsers B2C users"

$authEvents = Get-AzureADAuditDirectoryLogs -Filter "loggedByService eq 'B2C' and category eq 'Authentication' and result eq 'success' and (activityDisplayName eq 'Issue an id_token to the application' or activityDisplayName eq 'Issue an access token to the application' or activityDisplayName eq 'Exchange token')" -All $true
$totalAuthEvents = $authEvents.Count
Write-Host "You have $totalAuthEvents auth events for the last 7 days"
$resultSizeList = @{}

foreach ($event in $authEvents)
{
   $resultSizeList[$event.targetResources[0].id] =   $resultSizeList[$event.targetResources[0].id] +1;
}

$totalActiveUsers = $resultSizeList.Count

Write-Host "And you have $totalActiveUsers active users for the last 7 days"