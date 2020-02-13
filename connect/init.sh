#!/bin/bash

curl -X POST -H "Content-Type: application/json" -d @"/etc/kafka-connect/scripts/denormalised-sink.json" http://kafka-connect-01:8083/connectors