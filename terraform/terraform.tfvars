aws_region          = "il-central-1"
project_name        = "final-project"
cluster_name        = "final-project"
ecr_repository_name = "final-project"

vpc_id = "vpc-084065306e3ea1db1"

private_subnet_ids = [
  "subnet-0ee341dd743efd4b1",
  "subnet-0c8125312d6288fec",
  "subnet-0a5a5507442d6c84c"
]

node_instance_types = [
  "t3.medium"
]

node_desired_size = 1
node_min_size     = 1
node_max_size     = 2