#!/usr/bin/env python

""" Copy the mapping from an existing index, into a new index, for specific
mapping types.

This can only run on one host at a time. It isn't idempotent - if you run it
twice it'll probably give you all kinds of errors.
"""

import argparse
import datetime
import json
import requests
import socket
import sys


def fetch_mapping(remote, index):
    """ Fetch the mapping from Elasticsearch. """
    res = requests.get("%s/%s/_mapping" % (remote, index))
    mapping = json.loads(res.content)
    return mapping


def put_mapping(remote, index, mapping, mapping_type):
    """ Apply a mapping to an index """

    mapping_json = json.dumps(mapping)

    res = requests.put("%s/%s/_mapping/%s" % (remote, index, mapping_type),
                       data=mapping_json)
    print "Mapping PUT response: %s" % res.status_code
    if res.status_code != 200:
        print res.content


def create_index_if_missing(remote, index):
    """ Check if an index exists. If not, create it. """

    res = requests.get("%s/%s" % (remote, index))
    if res.status_code != 200:
        print "Index %s doesn't exist yet. Creating it." % index
        res = requests.put("%s/%s" % (remote, index))
        if res.status_code != 200:
            print "Unable to create index:"
            print res.content
            sys.exit(1)


def check_master(scheme, hostname, port):
    """ Check to see if the current host is the master. """

    my_ip = ([(s.connect((hostname, port)), s.getsockname()[0], s.close())
              for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1])
    res = requests.get("%s://%s:%s/_cat/master?h=ip" % (scheme, hostname, port))
    if res.status_code != 200:
        print("Failed to get IP address of cluster master:")
        print(res.content)
        sys.exit(1)
    master_ip = res.content.strip()
    if my_ip == master_ip:
        # Return true if this host is the cluster master.
        # Otherwise the method defaults to returning false
        return True


def parse_args():
    """ Parse command line options. """

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument("--host", "-H", dest="host", default="localhost",
                        help="Elasticsearch hostname")
    parser.add_argument("--port", "-p", dest="port", default=9200,
                        help="Elasticsearch port", type=int)
    parser.add_argument("--scheme", "-s", dest="scheme", default="http",
                        choices=("http", "https"),
                        help="Scheme to use for connection")
    parser.add_argument("--index-prefix", "-i", dest="index_prefix",
                        default="logstash", help="Index prefix")
    parser.add_argument("--mapping-type", "-t", dest="mapping_type",
                        default="log", help="Mapping type")
    parser.add_argument("--only-master", "-o", dest="only_master",
                        action="store_true", default=False,
                        help="Only run on the cluster master")

    args = parser.parse_args()
    args.remote = "%s://%s:%s" % (args.scheme, args.host, args.port)
    return args


def main():
    """ We do stuff here. """

    args = parse_args()

    if args.only_master:
        if not check_master(args.scheme, args.host, args.port):
            print("Not the cluster master. Exiting.")
            sys.exit(0)

    today = datetime.datetime.now()
    tomorrow = today + datetime.timedelta(days=1)
    todays_idx = "%s-%s" % (args.index_prefix, today.strftime('%Y.%m.%d'))
    tomorrows_idx = "%s-%s" % (args.index_prefix, tomorrow.strftime('%Y.%m.%d'))

    create_index_if_missing(args.remote, tomorrows_idx)

    mapping = fetch_mapping(args.remote, todays_idx)
    mapping_to_apply = mapping[todays_idx]["mappings"][args.mapping_type]

    put_mapping(args.remote, tomorrows_idx, mapping_to_apply,
                args.mapping_type)


    return


if __name__ == "__main__":
    main()
