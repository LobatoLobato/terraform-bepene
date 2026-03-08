output "accelerator_ips" {
  value = merge(
    { for k, v in module.bpn_sa_east_1 : k => v.accelerator_ips },
    { for k, v in module.bpn_us_east_1 : k => v.accelerator_ips }
  )
}

output "instance_public_ip" {
  value = merge(
    { for k, v in module.bpn_sa_east_1 : k => v.instance_public_ip },
    { for k, v in module.bpn_us_east_1 : k => v.instance_public_ip }
  )
}