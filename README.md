# ELK-utils
Utilities for working with the ELK (Elasticsearch, Logstash, Kibana) stack

## elkvacuate.rb
This script is for easily adding and removing nodes from a running Elasticsearch
cluster by including or excluding the node from every index that exists on the
cluster.

It uses `exclude._host` and `include._host` to manage which Elasticsearch nodes
are available to shards.

### Usage:
Before running this script, add or remove the nodes from your ES cluster
settings and mapping templates as needed.

To remove a node from the cluster:
`./elkvacuate.rb -a evacuate -h nodetoremove.example.com -u elkmaster.example.com -p 1234`

To add a node to the cluster:
`./elkvacuate.rb -a invacuate -h nodetoremove.example.com -u elkmaster.example.com -p 1234`
