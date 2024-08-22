variable "subscription_id" {
  type = string
  sensitive = true
}

variable "resource_group_name" {
  type = string
}

variable "storage_account_name" {
  type = string
  sensitive = true
}

variable "key" {
  type = string
}

variable "container_name" {
  type = string
}

variable "location" {
  type    = string
  default = "East US"
}

variable "gh_repo" {
  type = string
}
variable "bot_id" {
  type = string
}

variable "bot_tenant_id" {
  type = string
}