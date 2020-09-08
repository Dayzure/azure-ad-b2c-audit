# Playground for various queries on Azure AD B2C Audit Logs

This repository aims to provide useful queries around Azure AD B2C Audit Logs.

Please, remember that Azure AD B2C sign-in data is actually located in the **audit** log, not in **user sign-in** log.

More information on the categories and different field/values relevant to Azure AD B2C Audit Logs can be found [here](http://bit.ly/b2c-audit-fields).

If you are going to query the live data directly in Azure AD B2C Audit Logs, also do remember that Azure AD Audit logs are only preserved for 7 days. 
If you would like to query historical data for more than 7 days, you have to export Azure AD B2C Audit Log data to a Log Analytics Workspace (Azure Monitor).

Detailed instructions on how to enable Azure AD B2C Audit Logs available in Azure Monitor (Log Analytics workspace) please refer to [this article](http://bit.ly/b2c-monitor). 

# Azure AD PowerShell

Using [Azure AD PowerShell for MS Graph (v2.0)](http://bit.ly/aad-ps-msgraph) you can queriy Azure AD B2C Audit logs directly. Do not forget that you must be 
administrator of the directory to query audit logs data.

Here is a small PowerShell script that utilizies the [Azure AD PowerShell for MS Graph (v2.0)](http://bit.ly/aad-ps-msgraph) and [Azure AD PowerShell for MS Graph (v2.0-preview)](http://bit.ly/aad-ps-msgraph-preview) modules to query audit log directly:

 [b2c-audit-logs.ps1](./b2c-audit-logs.ps1)

The script queries the audit logs applying the following filter (split over several lines for readibility):

```
    loggedByService eq 'B2C' 
    and category eq 'Authentication' 
    and result eq 'success' 
    and (
            activityDisplayName eq 'Issue an id_token to the application' 
            or activityDisplayName eq 'Issue an access token to the application' 
            or activityDisplayName eq 'Exchange token')
```

Again, here important is, that this information is located in **audit** logs. Note that `Exchange token` activity appears for both
`refresh token` event and also for `redeem authorization code`. 

# Azure Log Analytics (Azure Monitor)

As already mentioned, if you need to query data for longer periods (then the last 7 days) you have to export your Azure AD B2C
audit logs into Log Analytics workspace (ref.: [Using Azure Monitor with Azure AD B2C](http://bit.ly/b2c-monitor)). Then you have the full freedom of KQL to query and analyse this data.

## Simple Queries
Follwing are three simple queries that will give you some relevant informaiton about your Azure AD B2C audit data

### Relevant authentications
This query gives you information about the authentication events in the last 30 days, broken down by type:

```
    AuditLogs 
    | where TimeGenerated > ago(30d)
    | where AADTenantId == "<put-your-tenant-id-here>" 
        and LoggedByService == "B2C" 
        and Result == "success" 
        and Category == "Authentication" 
        and OperationName in ("Issue an id_token to the application","Exchange token","Issue an authorization code to the application","Issue an access token to the application")
    | order by TimeGenerated desc 
    | summarize total_authn = count() by OperationName
```

This give result similar to the following table:

| OperationName | total_authn |
| ------------- |:-------------:| 
| Issue an access token to the application      | 12,394 |
| Issue an id_token to the application      | 39 |
| Issue an authorization code to the application | 2 |
| Exchange token | 61 |

### Monthly Active Users (MAUs)	

This query will enlist all your monthly active users (their `object id`) along with how often each user authenticated during the last 30 days.

```
    AuditLogs 
    | where TimeGenerated > ago(30d)
    | where AADTenantId == "<put-your-tenant-id-here>" 
        and LoggedByService == "B2C" 
        and Result == "success" 
        and Category == "Authentication" 
        and OperationName in ("Issue an id_token to the application","Exchange token","Issue an authorization code to the application","Issue an access token to the application")
    | order by TimeGenerated desc 
    | summarize total_authn = count() by tostring(TargetResources[0].id)
```

The resulting table looke like this:

| TargetResources_0_id | total_authn |
| ------------- |:-------------:|
| fc173cd0-bd59-4116-b368-8620b02a3d83      | 4,310 |
| ced37a33-c551-47ef-b8d2-075124259cd7      | 980 |
| 66815bc7-b7d7-4f3e-acb7-b889cc0fa59d | 12 |
| 284e680c-ec63-42f1-aaf2-cb298e6e1afc | 64 |

### Authentications vs. MAUs

The informations that is most relevant, if you are still on a `per-authentication` billing can be queried with the following KQL query:

```
    AuditLogs 
        | where TimeGenerated > ago(30d)
        | where AADTenantId == "<put-your-tenant-id-here>" 
            and LoggedByService == "B2C" 
            and Result == "success" 
            and Category == "Authentication" 
            and OperationName in ("Issue an id_token to the application","Exchange token","Issue an authorization code to the application","Issue an access token to the application")
        | order by TimeGenerated desc 
        | summarize auths = count(), maus = dcount(tostring(TargetResources[0].id))
```

The result will be a single line with two columns:

| auths | maus |
| ------------- |:-------------:| 
| 148,258      | 17,310 |
	
This is a very clear comparison between total authentications vs total MAUs for your Azure AD B2C Tenant

### Authentications vs. MAUs for charting

The last query gives us expected result, however it is not suitable for any visualisation. If we want to graphically represent this result,
we would need to craft a different query, so that we have two records with two columns each. 
The following query gives us a result suitable for visualisations:

```
    AuditLogs 
        | where TimeGenerated > ago(30d)
        | where AADTenantId == "<replace-with-your-tenant-id>" 
            and LoggedByService == "B2C" 
            and Result == "success" 
            and Category == "Authentication" 
            and OperationName in ("Issue an id_token to the application","Exchange token","Issue an authorization code to the application","Issue an access token to the application")
        | order by TimeGenerated desc 
        | summarize Authentications = count(), MAUs = dcount(tostring(TargetResources[0].id))
        | evaluate narrow()
        | project Column, Value
```

Thanks [Hans Peter](https://bit.ly/3haGlJ8), for helping out on this part!

And the result would be formatted that way:

| Column | Value |
| ------------- |:-------------:| 
| Authentications      | 148,258 |
| MAUs      | 17,310 |

## Azure Log Analytics Workbook

Last, but not least, we can pack the various queries in Azure Log Analytics Workbook and have it visually hint us about the authentications and MAUs.
A sample Workbook is provided in this repository: [b2c-audits.json](./b2c-audits.json). This is a *gallery template* not an *arm template*.


