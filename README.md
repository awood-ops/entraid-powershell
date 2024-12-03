# New-DAPWorkloadIdentity.ps1

## Overview

This script automates the creation of service principals, assignment of roles, and configuration of service connections in Azure DevOps. It reads parameters from a JSON file, which includes details such as organisation name, project name, and subscription name. The script ensures that the necessary roles and permissions are assigned, and that the service connections are created and configured correctly.

## Prerequisites

Before running the script, ensure that the following prerequisites are met:

- The user must be logged into Azure using `Login-AzAccount` or `Connect-AzAccount`.
- The user must have the relevant privileges in Entra ID to create a Service Principal (Application Administrator or above)
- The user must have access to the relevant subscriptions as Owner or User Access Administrator
- The necessary modules must be installed:
  - `Az`
- AZ CLI also needs to be installed

## Parameters

A configuration file is available and ready to be populated at `config/WorkloadIdentity.json`. For each environment required, populate an additional subscription.

- **paramsFile**: The path to the JSON file containing the parameters for the script. Default is `"params.json"`.

The parameters required are:

- **SubscriptionName**: The name of the subscription that the workload is being deployed to.
- **CreateServiceConnection**: Option to enable the automated creation of the Service Connection in Azure DevOps (set to `true` or `false`).

## Usage

### Example Command

```sh
New-WorkloadIdentity.ps1 -paramsFile "path\to\params.json"
```

Example JSON Parameters File with 2 Subscriptions

```sh
[
    {
        "SubscriptionName": "Subscription1",
        "CreateServiceConnection": "false"
    },
    {
        "SubscriptionName": "Subscription2",
        "CreateServiceConnection": "false"
    }
]
```

Currently applying the API Permissions appears to be unstable and sometimes admin consent is granted to the App Registration and sometimes it isn't.

This will need checking and if the permissions haven't been Granted admin consent to the Directory, this will need doing manually
