module certs {
  source = "github.com/gruntwork-io/private-tls-cert//modules/generate-cert"

  dns_names = ["rptx-epinzu1703-7.local"]
  validity_period_hours = 36500
  private_key_file_path = "./server.key"
  owner = "epinzur"
  ca_common_name = "Eric Pinzur"
  common_name = "Eric Pinzur"
  ip_addresses = []
  ca_public_key_file_path = "./ca.crt"
  public_key_file_path = "./server.crt"
  organization_name = "Eric Pinzur"
}