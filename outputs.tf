# Output the values required to connect the SFTP user to the server
output "agency_sftp_server_id" {
  value = [for i in range(length(var.agencies)):
             aws_transfer_server.sftp[i].id
          ]
}

# Print the endpoint URL of the SFTP server for each agency
output "agency_sftp_server_url" {
  value = [for i in range(length(var.agencies)) :
             aws_transfer_server.sftp[i].endpoint
  ]
}
