# `elasticsearch:config` Data Bag

Some general notes about the structure of the `elasticsearch:config` data bag:

## Cluster Definitions

All Elasticsearch clusters should be keyed *by name* under the `clusters` key:

```
{
  "id": "config",
    "clusters": {
      "elk": {
      ...
      },
      "develk": {
      },
    ...
}
```

## Node Definitions

Each cluster declaration should have a defined list of `master_nodes`, `data_nodes`, and `member_nodes`.

```
  "elk": {
    ...
    "master_nodes": [
      "elkmaster01.example.com",
      "elkmaster02.example.com"
    ],
    "data_nodes": [
      "elkdb01.example.com",
      "elkdb02.example.com"
    ],
    "member_nodes": [
      "kibana01.example.com",
      "kibana02.example.com"
    ],
    ...
```

## `additional_plugins`

To install additional Elasticsearch plugins, define them in the cluster's `additional_plugins` array.
`elasticsearch::plugins` will check for the presence of this array and install the listed plugins.

```
  "elk": {
    ...
    "additional_plugins": [
      "license",
      "shield"
    ]
  },
```

## `es_cluster_name` in Role Files

Any Chef roles that are used for Elasticsearch clusters must define the
cluster name in the `'elasticsearch' => 'es_cluster_name'` value under the
default attributes.

```
  ...
  "default_attributes": {
    "elasticsearch": {
      "es_cluster_name": "elk"
    },
  ...
```

## `licenses`

If any licenses are required for Elasticsearch plugins, define them in the cluster's `licenses` array.
`elasticsearch::licenses` will check for the presence of this array and install the listed licenses.

```
  "elk": {
    ...
    "licenses": [
      "shield"
    ]
  },
```

**NOTE**: `elasticsearch::licenses` will attempt to locate the license under
`files/default/licenses/<plugin_name>/<cluster_name>.json`. In the above example, the license file is
expected to be located at `files/default/licenses/shield/elk.json`
