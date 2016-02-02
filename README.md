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
`./elkvacuate.rb -a evacuate -h nodetoremove.example.com -u http://elkmaster.example.com -p 1234`

To add a node to the cluster:
`./elkvacuate.rb -a invacuate -h nodetoremove.example.com -u http://elkmaster.example.com -p 1234`

## Chef

This directory contains example roles, cookbooks, and data bags that can be used to
provision and maintain an ELK cluster relatively easily. These Chef code samples are
for example purposes only; they are provided as-is and no plans are made to maintain
or update them.

## irccat

This directory contains an example script containing commands that can be used with
an irc bot such as irccat for monitoring and managing an Elasticsearch cluster. These
commands are mostly wrappers around Elasticsearch's API. These code samples are also
provided as is for example purposes only, and will not be maintained or updated.
