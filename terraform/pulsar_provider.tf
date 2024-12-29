
# https://registry.terraform.io/providers/streamnative/pulsar/latest/docs
# https://github.com/streamnative/terraform-provider-pulsar

#provider "pulsar" {
#  web_service_url = "http://cluster-broker.test.svc.cluster.local:8080"
#}

# resource "pulsar_tenant" "pulsar_tenant" {
#   tenant           = "pulsar"
#   allowed_clusters = [pulsar_cluster.pulsar_cluster.cluster]
# }

# resource "pulsar_namespace" "test" {
#   tenant    = pulsar_tenant.pulsar_tenant.tenant
#   namespace = "main"

#   // If defined partially, plan would show difference
#   // however, none of the mising optionals would be changed
#   namespace_config {
#     anti_affinity                  = "anti-aff"
#     max_consumers_per_subscription = "50"
#     max_consumers_per_topic        = "50"
#     max_producers_per_topic        = "50"
#     message_ttl_seconds            = "86400"
#     replication_clusters           = ["standalone"]
#   }

#   dispatch_rate {
#     dispatch_msg_throttling_rate  = 50
#     rate_period_seconds           = 50
#     dispatch_byte_throttling_rate = 2048
#   }

#   subscription_dispatch_rate {
#     dispatch_msg_throttling_rate  = 50
#     rate_period_seconds           = 50
#     dispatch_byte_throttling_rate = 2048
#   }

#   retention_policies {
#     retention_minutes    = "1600"
#     retention_size_in_mb = "10000"
#   }

#   backlog_quota {
#     limit_bytes  = "10000000000"
#     limit_seconds = "-1"
#     policy = "consumer_backlog_eviction"
#     type = "destination_storage"
#   }

#   persistence_policies {
#     bookkeeper_ensemble                   = 1   // Number of bookies to use for a topic, default: 0
#     bookkeeper_write_quorum               = 1   // How many writes to make of each entry, default: 0
#     bookkeeper_ack_quorum                 = 1   // Number of acks (guaranteed copies) to wait for each entry, default: 0
#     managed_ledger_max_mark_delete_rate   = 0.0 // Throttling rate of mark-delete operation (0 means no throttle), default: 0.0
#   }

#   permission_grant {
#     role    = "some-role"
#     actions = ["produce", "consume", "functions"]
#   }
# }

