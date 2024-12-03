<#
    .SYNOPSIS
        Automates the creation of service principals, assignment of roles, and configuration of service connections in Azure DevOps.

    .DESCRIPTION
        This script automates the process of creating service principals in Entra ID, assigning the "Owner" role to them for specified subscriptions, and configuring service connections in Azure DevOps. It also handles the addition of API permissions for Entra ID Groups, and the creation of federated credentials for the service principals.

        The script reads parameters from a JSON file, which includes details such as organization name, project name, and subscription name. It ensures that the necessary roles and permissions are assigned, and that the service connections are created and configured correctly.

        The script includes error handling to ensure that any issues encountered during the execution are reported appropriately. It also includes a flag to skip the creation of service connections if not required.

        Prerequisites:
        - The user must be logged into Azure using Login-AzAccount or Connect-AzAccount.
        - The user must have the relevant privileges in Entra ID to create a Service Principal (Application Administrator or above)
        - The necessary modules (Az, Az.Accounts, Az.Resources, Az.DevOps) must be installed.

        Parameters:
        - paramsFile: The path to the JSON file containing the parameters for the script. Default is "params.json".

        Example usage:
        .\New-WorkloadIdentity.ps1 -paramsFile "path\to\params.json"
#>


param
(
    [Parameter(Mandatory = $true)]
    [string]$paramsFile = "params.json"
)


# Import the functions and error if they don't load
try {
    . .\modules\Authentication.ps1
    Write-Host "Successfully imported Authentication.ps1"
} catch {
    Write-Error "Failed to import Authentication.ps1: $_"
    exit 1
}

try {
    . .\modules\Service-Connection.ps1
    Write-Host "Successfully imported Service-Connection.ps1"
} catch {
    Write-Error "Failed to import Service-Connection.ps1: $_"
    exit 1
}

# Read the parameters from the JSON file and error if it doesn't exist
try {
    if (-Not (Test-Path -Path $paramsFile)) {
        throw "The parameters file '$paramsFile' does not exist."
    }
    $params = Get-Content $paramsFile -Raw | ConvertFrom-Json
    Write-Host "Successfully read parameters from '$paramsFile'"
} catch {
    Write-Error "Failed to read parameters from '$paramsFile': $_"
    exit 1
}

# Check Azure Context
if (-not (Get-AzContext)) {
    Write-Error "No Azure context found. Please run 'az login' to authenticate."
    exit 1
}




# Loop through the parameters and create a service principal for each set of parameters
foreach ($param in $params) {
    # Extract the parameters from the object
    $SubscriptionName = $param.SubscriptionName
    $CreateServiceConnection = $param.CreateServiceConnection
    $OrgName = $param.OrgName
    $ProjectName = $param.ProjectName
    

# Construct the service principal name
$spName = "app-$subscriptionName-devops"

# Get Subscription ID, if subscription doesn't exist, exit with error
$subscriptionId = (Get-AzSubscription -SubscriptionName $SubscriptionName -ErrorAction SilentlyContinue).Id
if (-not $subscriptionId) {
    Write-Error "Subscription '$SubscriptionName' not found."
    return
}

# Set the Subscription Context
Write-Output "Setting subscription context to '$SubscriptionName'..."
Set-AzContext -SubscriptionName $SubscriptionName

# Check if the service principal already exists and create it if it doesn't
try {
    $existingSp = Get-AzADServicePrincipal -DisplayName $spName -ErrorAction SilentlyContinue
    if ($existingSp) {
        Write-Warning "Service principal '$spName' already exists. Skipping creation..."
        $sp = $existingSp
    } else {
        Write-Output "Service principal '$spName' does not exist. Creating..."
        $sp = New-AzADServicePrincipal -DisplayName $spName
        Write-Host "Service principal '$spName' created successfully."
    }
} catch {
    Write-Error "Failed to create or check service principal '$spName': $_"
    return
}

# Remove the secret from the service principal
try {
    Get-AzADApplication -DisplayName $spName | Remove-AzADAppCredential
    Write-Host "Removed the secret from the service principal '$spName'."
} catch {
    Write-Error "Failed to remove the secret from the service principal '$spName': $_"
    return
}

# Assign the "Owner" role to the service principal for the subscription, unless it already has it
try {
    Write-Output "Checking if service principal '$spName' already has 'Owner' role for subscription '$subscriptionId'..."
    $existingRoleAssignment = Get-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "Owner" -Scope "/subscriptions/$subscriptionId" -ErrorAction SilentlyContinue
    if ($existingRoleAssignment) {
        Write-Warning "Service principal '$spName' already has 'Owner' role for subscription '$subscriptionId' at scope '/subscriptions/$subscriptionId'. Skipping..."
    } else {
        Write-Output "Assigning 'Owner' role to service principal '$spName' for subscription '$subscriptionId'..."
        New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "Owner" -Scope "/subscriptions/$subscriptionId"
        Write-Host "Assigned 'Owner' role to service principal '$spName' at scope '/subscriptions/$subscriptionId'."
    }
} catch {
    Write-Error "Failed to assign 'Owner' role to service principal '$spName': $_"
    return
}


# Add API Permissions for creating Entra ID Groups, unless they already exist
try {
    Write-Output "Adding API Permissions for creating Entra ID Groups..."
    $spn = Get-AzADApplication -DisplayName $spName

    # Define the API permissions to add
    $apiPermissions = @(
        @{ ApiId = "00000003-0000-0000-c000-000000000000"; Id = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"; Name = "Directory Read All"; Type = "Role" }
    )

    # Get existing permissions
    $existingPermissions = Get-AzADAppPermission -ApplicationId $spn.AppId

    foreach ($permission in $apiPermissions) {
        $existingPermission = $existingPermissions | Where-Object { $_.ApiId -eq $permission.ApiId -and $_.Id -eq $permission.Id -and $_.Type -eq $permission.Type }
        if ($existingPermission) {
            Write-Warning "Permission '$($permission.Name)' already exists. Skipping..."
        } else {
            Write-Output "Adding permission '$($permission.Name)'..."
            try {
                Add-AzADAppPermission -ApplicationId $spn.AppId -ApiId $permission.ApiId -PermissionId $permission.Id -Type $permission.Type
                Write-Host "Permission '$($permission.Name)' added successfully."
            } catch {
                Write-Error "Failed to add permission '$($permission.Name)': $_"
            }
        }
    }
} catch {
    Write-Error "Failed to add API Permissions for creating Entra ID Groups: $_"
    return
}

# Start Sleep
Start-Sleep -Seconds 10

# Run the command to grant admin consent to the Application
$command = "az ad app permission admin-consent --id $($spn.AppId)"
Write-Output "Running command '$command'..."
Invoke-Expression $command

# Output the App ID and Secret
Write-Output "App ID: $($sp.AppId)"
Write-Output "Tenant ID: $($sp.AppOwnerOrganizationId)"
Write-Output "Subscription ID: $subscriptionId"
Write-Output "Subscription Name: $SubscriptionName"
Write-Output "Service principal '$spName' created successfully."


# If createServiceConnection is set to true, create the service connection in Azure DevOps, else skip, check if the service connection already exists and create it if it doesn't
if ($CreateServiceConnection -eq "true") {
    Write-Output "Creating service connection in Azure DevOps..."

# Get the Azure DevOps access token
try {
    $token = Get-AzDevOpsAccessToken
    Write-Host "Successfully retrieved Azure DevOps access token."
} catch {
    Write-Error "Failed to retrieve Azure DevOps access token: $_"
    return
}

# Create the service connection in Azure DevOps
try {
    $serviceConnectionId = (New-AzDevOpsAzureSubscriptionServiceConnection -OrgName $OrgName -ProjectName $ProjectName -Name "conn-$spName" -SubscriptionId $subscriptionId -SubscriptionName $subscriptionName -ServicePrincipalClientId $sp.AppId -ServicePrincipalTenantId $sp.AppOwnerOrganizationId -AccessToken $token).id
    Write-Host "Successfully created service connection with ID: $serviceConnectionId."
} catch {
    Write-Error "Failed to create service connection in Azure DevOps: $_"
    return
}

# Get the service connection ID
try {
    $Issuer = (Get-AzDevOpsAzureServiceConnection -OrgName $OrgName -ProjectName $ProjectName -Name "conn-$spName" -ServiceConnectionId $serviceConnectionId -AccessToken $token).authorization.parameters.workloadIdentityFederationIssuer
    Write-Host "Successfully retrieved service connection issuer: $Issuer."
} catch {
    Write-Error "Failed to retrieve service connection issuer: $_"
    return
}

# Define the subject identifier
$subjectIdentifier = "sc://$OrgName/$ProjectName/conn-$spName"

# Get Application Object ID
try {
    $appObjectId = Get-AzADApplication -DisplayName $spName | Select-Object -Property @{Name="ApplicationObjectId";Expression={$_.Id}}
    Write-Host "Successfully retrieved application object ID: $($appObjectId.ApplicationObjectId)."
} catch {
    Write-Error "Failed to retrieve application object ID: $_"
    return
}

# Add Federated Credential to the App Registration
try {
    New-AzADAppFederatedCredential -ApplicationObjectId $appObjectId.ApplicationObjectId -Issuer $Issuer -Subject $subjectIdentifier -Audience "api://AzureADTokenExchange" -Name "AzureDevOps"
    Write-Host "Successfully added federated credential to the app registration."
} catch {
    Write-Error "Failed to add federated credential to the app registration: $_"
    return
}
}
else {
    Write-Output "Skipping service connection creation in Azure DevOps..."
}
}