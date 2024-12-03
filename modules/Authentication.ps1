<#
    .SYNOPSIS
        Returns an access token that can be used to call the Azure DevOps REST APIs.

    .DESCRIPTION
        This function uses the currently logged in user from the Az Context, and generates an access token for calling Azure DevOps REST APIs.
        You should have already logged into Azure using Login-AzAccount or Connect-AzAccount prior to calling this function.

        The ResourceUrl "499b84ac-1321-427f-aa17-267ca6975798" is the defined URL for interacting with Azure DevOps. DO NOT CHANGE THIS VALUE.
#>

function Get-AzDevOpsAccessToken {
    return (Get-AzAccessToken -ResourceUrl "499b84ac-1321-427f-aa17-267ca6975798").Token;
}



<#
    .SYNOPSIS
        Authenticates against Azure. If there is an existing context which does not match the parameters provided to the function, then the user will be asked to choose which context they want to use.

    .DESCRIPTION
        Authenticates against Azure and verifies the current Azure context matches the parameters supplied. If not, then the user is prompted to choose a context.

        If this function needs to re-authenticate the user, then it will use device authentication (aka device code), in order to avoid potential issues with MFA.
#>
function Set-AzureAuthentication {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $AzureUserName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionId,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $TenantId
    )

    $context = Get-AzContext;

    if ($null -ne $context) {
        # Display what the current Azure context is
        # If this is different from the context defined in the parameters, we will allow the user to choose to continue or re-authenticate
        Write-Host "Current Azure context is:" -ForegroundColor Cyan;
        Write-Host "Account:            " $context.Account -ForegroundColor Cyan;
        Write-Host "Subscription Name:  " $context.Subscription.Name -ForegroundColor Cyan;
        Write-Host "Subscription Id:    " $context.Subscription.Id -ForegroundColor Cyan;
        Write-Host "Tenant Id:          " $context.Tenant.Id -ForegroundColor Cyan;
        Write-Host;

        # Check if the current context matches the parameters
        $accountMatch = $context.Account.Id -eq $AzureUserName;
        $subMatch = $context.Subscription.Id -eq $SubscriptionId;
        $tenantMatch = $context.Tenant.Id -eq $TenantId;

        if (($false -eq $accountMatch) -or ($false -eq $subMatch) -or ($false -eq $tenantMatch))
        {
            # The contexts don't match, so ask the user which one they want to use
            Write-Host "`nWARNING: Current Azure context does not match the context defined in the configuration file.`n" -ForegroundColor Yellow;

            $reply = Read-Host -Prompt "Do you want to continue with the current context? 
            - Enter y to use the current context.
            - Enter n to use the context defined in the configuration file (you will be asked to authenticate again).
            ";
        
            if($reply -match "[yY]" ) {
                Write-Host "`nCONTINUING WITH THE CURRENT AZURE CONTEXT`n" -ForegroundColor "Yellow";
                # We're already signed into the Azure context, so we don't need to do anything else here
            }
            else {
                Write-Host "`nUSING AZURE CONTEXT FROM CONFIG`n" -ForegroundColor "Magenta";

                # We want to use the Azure context from the config, so authenticate again
                # Use device authentication so we can get around any issues with MFA
                Login-AzAccount -Tenant $TenantId -Subscription $SubscriptionId -UseDeviceAuthentication;
            }
        } 
        else {
            Write-Host "Current Azure context matches the context defined in the configuration file. Continuing with the current context.`n" -ForegroundColor Green;
        }
    } 
    else {
        # We don't have an Azure context, so authenticate
        # Use device authentication so we can get around any issues with MFA
        Login-AzAccount -Tenant $TenantId -Subscription $SubscriptionId -UseDeviceAuthentication;
    }

    return Get-AzContext;
}