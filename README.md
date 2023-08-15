# Korthcore.UAT-ENV

## Description

A repo to store scripts and **Bicep** templates that may be used for a base level implementation for a Lab environment within Azure. Primarily *Bicep* and *PowerShell DSC* Scripts, but the facility for other languages where appropriate.

## Table of Contents

- [Korthcore.UAT-ENV](#korthcoreuat-env)
  - [Description](#description)
  - [Table of Contents](#table-of-contents)
  - [Project Goals](#project-goals)
  - [Usage](#usage)
    - [Parameters](#parameters)
      - [main.bicep](#mainbicep)
      - [dev.parameters.json](#devparametersjson)
  - [Maintainers](#maintainers)
  - [Tests](#tests)

## Project Goals

- To quickly deploy a base configuration of a *Lab* environment for testing purposes.
- Enforce a baseline tagging strategy for Azure resources.

## Usage

Using your favourite command line tool, ensure the *[Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)* is installed.

Verify you have logged in to the appropriate tenant with a basic `az login --scope https://management.core.windows.net//.default` command. Alternatively additional details on how to authenticate can be found [here](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli).

Ensure your *Azure Development Tenant* has a dedicated Resource Group created explicitly for this project. Once you do, you can You can deploy via *Bicep* by navigating to this location (../Korthcore.UAT-ENV) in your command line tool of choice and running `az deployment group create --resource-group 'resource-group-name' --template-file main.bicep --parameters dev.parameters.json` to begin deployment.

Parameters may be specified in the parameters.json file as outlined. You may copy the original file and specify for certain environments where appropriate or edit these for your own use cases.

Eventually this will look to be configured via *Azure DevOps Pipelines* and/or *GitHub Actions*, but for now this is how it may be deployed. A work in progress if you will.

Currently the SAS tokens are stored in the in an *Azure KeyVault* which have been generated from an *Azure Storage Account* for the DSC configuration. Additional changes to this will also ensure the creation of a KeyVault and Storage Account to help facilitate this. Currently this was done manually.

A *Public IP* is in use intentionally as a cost reduction effort rather than utilising *Azure Bastion*, this of course can be removed and Bastion configured instead for simple access to the resources.

### Parameters

As this has been sanitised, a lot of default Parameters have been removed for privacy and security purposes. Look for the following empty parameters to update with your own choices here. Over time the idea is to pull these all out to be provided by the Parameters File instead.

#### main.bicep

- param virtualNetworkName
- param subnetName
- param allowedSourceIPAddress
- param domainControllerName
- param workstationName
- param domainFQDN
- param adminUsername

#### dev.parameters.json

- keyVault id is required for all SAS tokens listed here.
  - Currently has `add your keyvault id here` to reference.
  - Example: `/subscriptions/SUBSCRIPTIONID/resourceGroups/RESOURCEGROPUNAME/providers/Microsoft.KeyVault/vaults/KEYVAULTNAME`

## Maintainers

- Chris Edwards

## Tests

... Watch this space
