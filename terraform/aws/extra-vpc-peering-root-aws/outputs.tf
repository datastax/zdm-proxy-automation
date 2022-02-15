output "peering_connection_id" {
  description = "ID of the new peering connection"
  value = module.vpc_peering.vpc_peering_connection_id
}