# `?elk`

`?elk` can be used to surface general information about the log-processing
Elasticsearch cluster

## Available Information

### `health`

Determine the health of an elk Elasticsearch cluster with:

    frantz | ?elk health
    irccat | Elasticsearch cluster health is GREEN

Determine the health of a non-elk Elasticsearch cluster with:

    frantz | ?es health flop elastic1
    irccat | Elasticsearch cluster, flop-elastic1, health is GREEN

### `indices <index prefix> <number of indices>`

Use `indices` to enumerate the indices housed in the ELK cluster. The naming
convention for most indices is

`<index_name>-YYYY.MM.DD`

The `indices` subcommand strips the date component from the indices as it enumerates them, for
easy consumption.

    frantz | ?elk indices
    irccat |  INDEX PREFIX | COUNT
    irccat |  .kibana4     |     1
    irccat |  .marvel      |     1
    irccat |  catapult     |     1
    irccat |  cloudtrail   |     1
    irccat |  datafindr    |     1
    irccat |  grafana      |     1
    irccat |  kibana       |     1
    irccat |  logstash     |    70
    irccat |  nagios       |     1
    irccat |  securelog    |    12
    irccat |  statsd       |     1
    irccat |  superbit     |     1

Providing an `<index prefix>` argument tells `indices` to list information about
related indices. The default number of indices to list is **2**.

    frantz | ?elk indices securelog
    irccat |  INDEX                  | HEALTH |    SIZE | PRI SIZE | P SHARD | R SHARD
    irccat | securelog-2015.01.27    | green  |     2gb |      1gb |       2 |       2
    irccat | securelog-2015.01.26    | green  |   2.4gb |    1.2gb |       2 |       2

Optionally, instruct `indices` to list more indices via the `<number of indices>`
argument:

    frantz | ?elk indices logstash 4
    irccat |  INDEX                  | HEALTH |    SIZE | PRI SIZE | P SHARD | R SHARD
    irccat | logstash-2015.12.01     | green  |   135kb |   67.5kb |      42 |      42
    irccat | logstash-2015.10.30     | green  |  47.1kb |   23.5kb |      42 |      42
    irccat | logstash-2015.08.30     | green  |  47.2kb |   23.6kb |      42 |      42
    irccat | logstash-2015.08.20     | green  |  59.3kb |   29.6kb |      42 |      42

### `master`

The Elasticsearch cluster elects and maintains a master node. You can find it
as well as any eligible master nodes:

    frantz | ?elk master
    irccat | elasticsearchmaster.examplecorp.com        60     IN CNAME   elasticsearchmaster05.ny4.example.com
    irccat |  MASTER | ELIGIBLE | HOST
    irccat |    *    |          | elasticsearchmaster05.ny4.example.com
    irccat |         |    *     | elasticsearchmaster04.ny4.example.com
    irccat |         |    *     | elasticsearchmaster06.ny4.example.com

### `node` or `nodes`

`?elk` can provide a count of active data nodes as well as the total count of nodes
(including non-data nodes like the masters and Kibana hosts).

    frantz | ?elk nodes
    irccat |  TYPE   | COUNT
    irccat |  CLIENT |       2
    irccat |  DATA   |      96
    irccat |  MASTER |       3
    irccat |  TOTAL  |     101

Providing a node name as an optional argument will show details about the specified node.

    beerops | ? elk node elasticsearch32.ny5
    irccat  | Node elasticsearch32.ny5 (with role data node) has:
    irccat  | 60 started indices
    irccat  | 0 initializing indices
    irccat  | 0 relocating indices

### `rebalancing`

One of the nice things about Elasticsearch is that it can rebalance the shard
allocation across nodes. This is important to keep all nodes' storage beneath
a minimum storage watermark, a point above which the cluster's performance
could be negatively affected.

Occasionally cluster rebalancing needs to be disabled (i.e. to expedite
recovering the cluster or backfilling log events). This can be done to reduce
the overall load on the cluster.

`rebalancing` will indicate if cluster rebalancing is enabled or not. If it is,
the number of concurrent shards that can be relocated at any given time is
displayed. If any shards are currently being relocated, their count will be
displayed. Shards can be relocating even **while** rebalancing is disabled
if they those relocations were in flight at the time rebalancing was turned off.

    frantz | ?elk rebalancing
    irccat |  RE-BALANCING | CONCURRENT SHARDS | RELOCATING PRI | RELOCATING REP
    irccat |  ON           |                 1 |              0 |              1

If an optional node name is provided as an argument, the output will show the
status of any ongoing rebalancing operations to or from that node.

    beerops | ?elk rebalancing elasticsearch63.ny5
    irccat  |  RE-BALANCING | CONCURRENT SHARDS | RELOCATING PRI | RELOCATING REP
    irccat  |  ON           |                 8 |              0 |              0
    irccat  | INDEX: logstash-2015.10.28 TYPE: replica FROM: elasticsearch63.ny5.example.com TO: elasticsearch22.ny5.example.com FILES %: 63.1% BYTES %: 2.3%

### `setrebalancing`

`?elk setrebalancing <num>` takes a number between 0 and 8 and sets the rebalancing
setting to that number. 0 means rebalacing is disabled. 1-8 means rebalancing is
enabled, with 1 being the lowest and 8 being the highest amount of concurrent
rebalancing.

    beerops | ?elk setrebalancing 8
    irccat  | {"acknowledged":true,"persistent":{"cluster":{"routing":{"allocation":
    irccat  | {"cluster_concurrent_rebalance":"8"}}}},"transient":{}} (200 OK)

### `maxbytes`

`?elk maxbytes <num>` takes a number between 1 and 500 (MB) and sets this number to
be the number of max recovery bytes that the cluster will allow to be in flight at
a time during recovery. 1 is very slow recovery, 500 is the fastest we will allow
without the cluster falling over.

    beerops | ?elk maxbytes 250
    irccat  | {"acknowledged":true,"persistent":{"indices":{"recovery":
    irccat  | {"max_bytes_per_sec":"250mb"}}},"transient":{}} (200 OK)

### `repo` or `repos`

Enumerate the Elasticsearch snapshot repositories. These are shared file systems
that all nodes and the masters have mounted for the purpose of backing up indices.

    frantz | ?elk repos
    irccat |  REPO       | COMPRESS | BACKUP RATE | RESTORE RATE | LOCATION
    irccat | snapshots1  |     true |         5mb |            - |     /elasticsearch/snapshots1
    irccat | snapshots2  |     true |        10mb |            - |     /elasticsearch/snapshots2

### `settings`

Enumerate the Elasticsearch cluster's settings and `gist` them for the user. There are `persistent` and
`transient` settings; more often than not, only `persistent` values will be set. See below for example
output.

    >> Elasticsearch Cluster Settings << 
     
     persistent.action.destructive_requires_name = true
     persistent.cluster.routing.allocation.balance.primary = 0.1
     persistent.cluster.routing.allocation.cluster_concurrent_rebalance = 0
     persistent.cluster.routing.allocation.disk.threshold_enabled = true
     persistent.cluster.routing.allocation.enable = all
     persistent.cluster.routing.allocation.node_concurrent_recoveries = 1
     persistent.indices.recovery.compress = true
     persistent.indices.recovery.concurrent_streams = 3
     persistent.indices.recovery.max_bytes_per_sec = 200mb
     persistent.indices.recovery.translog_size = 512kb
     persistent.indices.store.throttle.max_bytes_per_sec = 5mb
     persistent.indices.store.throttle.type = none
     persistent.marvel.agent.exporter.es.hosts = nagios03.ny4.example.com:9200, nagios04.ny4.example.com:9200, monitor01.ny5.example.com:9200, monitor02.ny5.example.com:9200
     persistent.marvel.agent.interval = 10s

**NOTE**: The above namespaces cannot be used for copypasting settings when modifying the cluster.
They've been concatenated and delimited by dots for convenience reading them.

### `shard` or `shards`

All Elasticsearch indices are comprised of shards. It's useful to know the state of those shards.

    frantz | ?elk shards
    irccat | TYPE    |STATUS        |COUNT
    irccat | PRIMARY | STARTED      |    2083
    irccat |    -    | INITIALIZING |       0
    irccat |    -    | RELOCATING   |       0
    irccat |    -    | UNASSIGNED   |       0
    irccat |         | TOTAL        |    2083
    irccat | REPLICA | STARTED      |    2083
    irccat |    -    | INITIALIZING |       0
    irccat |    -    | RELOCATING   |       0
    irccat |    -    | UNASSIGNED   |       0
    irccat |         | TOTAL        |    2083

### `snapshot` or `snapshots`

Enumerate the most recent 3 Elasticsearch snapshots, per snapshot repo.

    frantz | ?elk snapshots
    irccat |  REPO       | SNAPSHOT NAME          | STATE       | START               | END                 | DURATION
    irccat | snapshots1  | statsd-2015.01.26      | SUCCESS     | 2015-01-26 19:36:36 | 2015-01-26 19:37:22 | 0d 0h 0m 46s
    irccat | snapshots2  | logstash-2015.01.27    | IN_PROGRESS | 2015-01-28 14:21:55 | -                   | -
    irccat | snapshots2  | logstash-2015.01.26    | SUCCESS     | 2015-01-27 15:15:47 | 2015-01-27 19:32:58 | 0d 4h 17m 11s

### `recovery`

Shows any current recovery operations that are in progress.

    beerops | ?elk recovery
    irccat  | 8 recoveries in progress:
    irccat  | index type stage source_host target_host files_percent bytes_percent
    irccat  | logstash-2015.08.18 relocation index elasticsearch24.ny5.example.com elasticsearch09.ny5.example.com 97.5% 98.1%
    irccat  | logstash-2015.08.17 replica index elasticsearch09.ny5.example.com elasticsearch14.ny5.example.com 98.0% 97.2%
    irccat  | logstash-2015.08.18 replica index elasticsearch49.ny5.example.com elasticsearch25.ny5.example.com 97.5% 95.1%
    irccat  | logstash-2015.09.03 replica index elasticsearch18.ny5.example.com elasticsearch53.ny5.example.com 83.7% 61.7%
    irccat  | logstash-2015.08.17 relocation index elasticsearch24.ny5.example.com elasticsearch44.ny5.example.com 84.4% 47.7%
    irccat  | logstash-2015.09.05 relocation index elasticsearch72.ny5.example.com elasticsearch21.ny5.example.com 85.0% 20.0%
    irccat  | logstash-2015.09.03 relocation index elasticsearch25.ny5.example.com elasticsearch48.ny5.example.com 87.0% 20.0%
    irccat  | logstash-2015.09.06 replica index elasticsearch46.ny5.example.com elasticsearch21.ny5.example.com 71.7% 13.2%
