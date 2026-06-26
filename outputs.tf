output "resource_group_name" {
  value = azurerm_resource_group.main.name
}
 
output "gallery_name" {
  value = azurerm_shared_image_gallery.main.name
}
 
output "image_definition_name" {
  value = azurerm_shared_image.rhel9_cis.name
}
 
output "packer_client_id" {
  value     = azuread_application.packer.client_id
  sensitive = true
}
 
output "packer_client_secret" {
  value     = azuread_service_principal_password.packer.value
  sensitive = true
}
 
output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}
 
output "subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}
