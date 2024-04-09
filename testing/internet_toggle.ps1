

param (
    [Parameter(Mandatory)]
    [Alias("RG")]
    [string]$ResourceGroup,
    [string]$NSG = "NSG1",
    [switch]$enable = $false
)

function enable {
  $list=az network nsg rule list -g $ResourceGroup --nsg-name $NSG | jq -r 'map(.name) | .[]'

  if ($list.contains("DENYINTERNET")){
    az network nsg rule delete --name DENYINTERNET -g $ResourceGroup --nsg-name $NSG
  }
  if ($list.contains("DENYLOAD")){
    az network nsg rule delete --name DENYLOAD  -g $ResourceGroup --nsg-name $NSG
  }
}

function disable {
  az network nsg rule create --name DENYINTERNET `
      --resource-group $ResourceGroup `
      --nsg-name $NSG `
      --priority 4096 `
      --direction OutBound `
      --access Deny `
      --destination-address-prefixes Internet `
      --destination-port-ranges '*'
 
  az network nsg rule create --name DENYLOAD `
      --resource-group $ResourceGroup `
      --nsg-name $NSG `
      --priority 4095 `
      --direction OutBound `
      --access Deny `
      --destination-address-prefixes AzureLoadBalancer `
      --destination-port-ranges '*'
}

if ($enable) {
  enable
}
else {
  disable
}
