# ==== IDs you need ====
TENANT_ID="<YOUR_TENANT_ID_GUID>"
SUBSCRIPTION_ID="<YOUR_SUBSCRIPTION_ID_GUID>"
LOCATION="eastus"

# GitHub repo coordinates
GH_OWNER="<your-github-username-or-org>"
GH_REPO="<your-forked-repo-name>"    # e.g. azure-voting-app-redis

# Naming (must be globally unique where needed)
ACR_NAME="acrlz$RANDOM$RANDOM"       # or pick your own unique name, lowercase only
SA_TFSTATE="satf$RANDOM$RANDOM"      # storage account for TF state, lowercase only
RG_SHARED="rg-platform-shared"
RG_PREPROD="rg-vote-preprod"
RG_PROD="rg-vote-prod"

# Login & sub
az login
az account set --subscription "$SUBSCRIPTION_ID"

# ==== Resource Groups ====
az group create -n "$RG_SHARED" -l "$LOCATION"
az group create -n "$RG_PREPROD" -l "$LOCATION"
az group create -n "$RG_PROD" -l "$LOCATION"

# ==== ACR ====
az acr create -g "$RG_SHARED" -n "$ACR_NAME" --sku Basic --admin-enabled true
ACR_LOGIN_SERVER=$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)
echo "ACR: $ACR_NAME  LoginServer: $ACR_LOGIN_SERVER"

# ==== Terraform state backend (storage account + container) ====
az storage account create -g "$RG_SHARED" -n "$SA_TFSTATE" -l "$LOCATION" --sku Standard_LRS
ACCOUNT_KEY=$(az storage account keys list -g "$RG_SHARED" -n "$SA_TFSTATE" --query "[0].value" -o tsv)
az storage container create --name tfstate --account-name "$SA_TFSTATE" --account-key "$ACCOUNT_KEY"

# ==== App Registration for GitHub OIDC ====
APP_ID=$(az ad app create --display-name "gh-oidc-vote" --query appId -o tsv)
SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)

# Federated credential: allow main branch
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "gh-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GH_OWNER"'/'"$GH_REPO"':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# ==== RBAC for that SP ====
# ACR push/pull
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "AcrPush" --scope "$(az acr show -n $ACR_NAME --query id -o tsv)"

# Preprod Contributor (infra/app deploy)
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Contributor" --scope "$(az group show -n $RG_PREPROD --query id -o tsv)"

#ADD HERE WEBUAMI ROLE & ASSIGNMENT FOR ACR PULL



# Prod Contributor (you can tighten later with PIM)
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Contributor" --scope "$(az group show -n $RG_PROD --query id -o tsv)"

echo "APP_ID (clientId)  : $APP_ID"
echo "TENANT_ID          : $TENANT_ID"
echo "SUBSCRIPTION_ID    : $SUBSCRIPTION_ID"
echo "ACR_LOGIN_SERVER   : $ACR_LOGIN_SERVER"
echo "ACR_NAME           : $ACR_NAME"
echo "TF STATE ACCOUNT   : $SA_TFSTATE"

#test1
