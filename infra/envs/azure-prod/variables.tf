# variables.tf
# These Terraform variables get their values from your GitHub Actions
# environment via TF_VAR_* (see workflow env: ... above).
variable "location"           { type = string }           # <- from $TF_VAR_location (GitHub vars.LOCATION)
variable "resource_group_name"{ type = string }           # <- from $TF_VAR_resource_group_name (vars.RG_PREPROD/RG_PROD)
variable "app_name"           { type = string }           # <- from $TF_VAR_app_name ("vote-preprod"/"vote-prod")
variable "acr_login_server"   { type = string }           # <- from $TF_VAR_acr_login_server (vars.ACR_LOGIN_SERVER)
variable "image_tag"          { type = string }           # <- from $TF_VAR_image_tag (github.sha)
variable "sa_tfstate"         { type = string }           # <- from $TF_VAR_sa_tfstate (vars.SA_TFSTATE)  (used in backend)
variable "tfstate_container"  { type = string }           # <- from $TF_VAR_tfstate_container (vars.TFSTATE_CONTAINER)
variable "subscription_id" {
  type = string
}