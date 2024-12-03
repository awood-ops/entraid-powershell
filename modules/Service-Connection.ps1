<#
    .SYNOPSIS
        Creates a new azure resource manager service connection in an Azure DevOps project.
#>
function New-AzDevOpsAzureSubscriptionServiceConnection {
  param (
      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $OrgName,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $ProjectName,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $Name,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $SubscriptionId,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $SubscriptionName,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $ServicePrincipalTenantId,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $AccessToken,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $ServicePrincipalClientId

    
  )

  Write-Host "Creating service connection $Name in project $ProjectName" -ForegroundColor Cyan;

  # First, we need to get the project Id to go in our project reference
  $projectUrl = "https://dev.azure.com/$OrgName/_apis/projects/$ProjectName" + "?api-version=7.2-preview.4";

  $url = "https://dev.azure.com/$OrgName/_apis/serviceendpoint/endpoints?api-version=7.2-preview.4";

  $headers = @{
      'Authorization' = 'Bearer ' + $AccessToken
      'Content-Type' = 'application/json'
  }

  try {
    $project = Invoke-RestMethod -Method Get -Uri $projectUrl -Headers $headers
    Write-Host "Successfully retrieved project information."
    } catch {
    Write-Error "Failed to retrieve project information: $_"
    return
    }

  $projectId = $project.id;

  $body = @"
  {
      "data": {
        "subscriptionId": "$SubscriptionId",
        "subscriptionName": "$SubscriptionName",
        "environment": "AzureCloud",
        "scopeLevel": "Subscription",
        "creationMode": "Manual"
      },
      "name": "$Name",
      "type": "AzureRM",
      "url": "https://management.azure.com/",
      "authorization": {
        "parameters": {
          "tenantid": "$ServicePrincipalTenantId",
          "serviceprincipalid": "$ServicePrincipalClientId"
        },
        "scheme": "WorkloadIdentityFederation"
      },
      "isShared": false,
      "isReady": true,
      "serviceEndpointProjectReferences": [
        {
          "projectReference": {
            "name": "$ProjectName",
            "id": "$projectId"
          },
          "name": "$Name"
        }
      ]
    }
"@;

  $serviceConnection = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $body;

  Write-Host "Successfully created service connection $Name in project $ProjectName" -ForegroundColor Green;

  return $serviceConnection;

  ##Output the Issuer and Subject Identifier
  $serviceConnection | Select-Object -Property @{Name="ServiceConnectionName";Expression={$_.name}}, @{Name="ServiceConnectionId";Expression={$_.id}}
}

function New-AzDevOpsAzureManagementGroupServiceConnection {
  param (
      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $OrgName,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $ProjectName,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $Name,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $ManagementGroupId,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $ManagementGroupName,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $ServicePrincipalTenantId,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $AccessToken,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $ServicePrincipalClientId

    
  )

  Write-Host "Creating service connection $Name in project $ProjectName" -ForegroundColor Cyan;

  # First, we need to get the project Id to go in our project reference
  $projectUrl = "https://dev.azure.com/$OrgName/_apis/projects/$ProjectName" + "?api-version=7.2-preview.4";

  $url = "https://dev.azure.com/$OrgName/_apis/serviceendpoint/endpoints?api-version=7.2-preview.4";

  $headers = @{
      'Authorization' = 'Bearer ' + $AccessToken
      'Content-Type' = 'application/json'
  }

  $project = Invoke-RestMethod -Method Get -Uri $projectUrl -Headers $headers;

  $projectId = $project.id;

  $body = @"
  {
      "data": {
        "managementGroupId": "$ManagementGroupId",
        "managementGroupName": "$ManagementGroupName",
        "environment": "AzureCloud",
        "scopeLevel": "ManagementGroup",
        "creationMode": "Manual"
      },
      "name": "$Name",
      "type": "AzureRM",
      "url": "https://management.azure.com/",
      "authorization": {
        "parameters": {
          "tenantid": "$ServicePrincipalTenantId",
          "serviceprincipalid": "$ServicePrincipalClientId"
        },
        "scheme": "WorkloadIdentityFederation"
      },
      "isShared": false,
      "isReady": true,
      "serviceEndpointProjectReferences": [
        {
          "projectReference": {
            "name": "$ProjectName",
            "id": "$projectId"
          },
          "name": "$Name"
        }
      ]
    }
"@;

  $serviceConnection = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $body;

  Write-Host "Successfully created service connection $Name in project $ProjectName" -ForegroundColor Green;

  return $serviceConnection;

  ##Output the Issuer and Subject Identifier
  $serviceConnection | Select-Object -Property @{Name="ServiceConnectionName";Expression={$_.name}}, @{Name="ServiceConnectionId";Expression={$_.id}}
}

<#
    .SYNOPSIS
        Gets a azure resource manager service connection in an Azure DevOps project.
#>
function Get-AzDevOpsAzureServiceConnection {
  param (
      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $OrgName,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $ProjectName,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $ServiceConnectionId,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $AccessToken,

      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string] $Name
  )

  Write-Host "Getting service connection $Name in project $ProjectName" -ForegroundColor Cyan;

  $url = "https://dev.azure.com/$OrgName/$ProjectName/_apis/serviceendpoint/endpoints/$ServiceConnectionId"+ "?api-version=7.2-preview.4";

  $headers = @{
      'Authorization' = 'Bearer ' + $AccessToken
      'Content-Type' = 'application/json'
  }

  try {
    $serviceConnection = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
    Write-Host "Successfully retrieved service connection information."
    } catch {
    Write-Error "Failed to retrieve service connection information: $_"
    return
    }


  return $serviceConnection
}