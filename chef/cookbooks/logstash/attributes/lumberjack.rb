
node.default[:lumberjack][:production_servers] = {
    "name" => "elk",
    "servers" => [
        'logstash01.example.com:9991',
        'logstash02.example.com:9991',
        'logstash03.example.com:9991',
        'logstash04.example.com:9991',
        'logstash05.example.com:9991',
        'logstash06.example.com:9991',
        'logstash07.example.com:9991',
        'logstash08.example.com:9991',
        'logstash09.example.com:9991',
        'logstash10.example.com:9991',
        'logstash11.example.com:9991',
        'logstash12.example.com:9991'
    ],
    "timeout" => 180
}
