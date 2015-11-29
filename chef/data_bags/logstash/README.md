# `logstash::config` Data Bag

Some general notes about the `logstash::config data bag.

## Cluster Definitions

All Logstash clusters should be keyed by *name* under the `clusters` key:

```
{
  "id": "config",
  "clusters": {
    "elk": {
      "routers": [
        "server1.example.com",
        "server2.example.com",
        "server3.example.com"
      ]
    },
    "additional_plugins": {
      "logstash-output-elasticsearch-shield": "0.2.3"
    }
    ...
  }
}
```

## `additional_plugins`

Specify the Logstash plugins nodes in this cluster need to have installed:

```
  ...
    "elk": {
      ...,
      "additional_plugins": {
        "logstash-output-elasticsearch-shield": "0.2.3"
      }
    }
  ...
```

**NOTE**: This is only supported for Logstash 1.5 and up.

## `cluster_name` in Role Files

Any Chef roles that are used for Logstash clusters must define the cluster name
in the `'elasticsearch' => 'cluster_name'` value under the default attributes:

```
  ...
  "default_attributes": {
    "logstash": {
        "cluster_name": "elk",
    },
    ...
```

## `routers`

Every Logstash server (router) should be listed in the `routers` array:

```
  ...
    "elk": {
      "routers": [
        "server1.example.com",
        "server2.example.com",
        "server3.example.com"
      ],
    }
  ...
```
