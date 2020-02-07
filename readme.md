Bootstrapping a Kafka/KSQL/Postgres pipeline to transform source records into a denormalised datastore.

# Up and running

```
docker-compose up -d
```

Note that:
- Our KSQL configuration ensures that schemas are applied automatically (we do not need to apply schemas manually)
- Our docker configuration ensures that the `people` kafka topic is created as soon as it is referenced

# KSQL

Implementing the streams and connectors manually:

Open the KSQL CLI (the `ksqldb-cli` docker image)

```
docker exec -it 5492af6f2bb5 ksql http://ksqldb-server:8088
```

_If you want to run SELECT queries in the KSQL CLI, it is recommended to run queries from the start of any log - `SET 'auto.offset.reset'='earliest';`_

Now in the KSQL CLI we will:
1. Use a `STREAM` to retrieve specific data from a topic
1. Use a `STREAM` to apply a key to the data, convert the data to AVRO format, and to do a basic projection
1. Use a `SINK CONNECTOR` to stream the data out to the postgres database

```
CREATE STREAM people_stream (
  identity_id STRING,
  name STRING,
  family_name STRING
)
WITH (
  KAFKA_TOPIC='people',
  PARTITIONS=1,
  REPLICAS=1,
  VALUE_FORMAT='JSON'
);

CREATE STREAM people_denormalised WITH (
  'VALUE_FORMAT'='AVRO'
) AS
  SELECT 
    identity_id,
    name,
    family_name,
    name + ' ' + family_name AS full_name
  FROM people_stream
EMIT CHANGES
PARTITION BY identity_id;

CREATE SINK CONNECTOR people WITH (
  'connector.class'='io.confluent.connect.jdbc.JdbcSinkConnector',
  'connection.url'='jdbc:postgresql://postgres:5432/denormalised',
  'connection.user'='postgres',
  'connection.password'='postgres',
  'tasks.max'='1',
  'insert.mode'='upsert',
  'topics'='people_denormalised',
  'auto.create'='true',
  'pk.mode'='record_value',
  'pk.fields'='IDENTITY_ID',
  'batch.size'='1',
  'table.name.format'='people'
);
```

TODO: projections not yet working
```
CREATE STREAM people_denormalised WITH (
  'VALUE_FORMAT'='AVRO'
) AS
  SELECT 
    identity_id,
    name,
    family_name,
    name + ' ' + family_name AS full_name
  FROM people_stream
EMIT CHANGES
PARTITION BY identity_id;

CREATE SINK CONNECTOR people WITH (
  'connector.class'='io.confluent.connect.jdbc.JdbcSinkConnector',
  'connection.url'='jdbc:postgresql://postgres:5432/denormalised',
  'connection.user'='postgres',
  'connection.password'='postgres',
  'tasks.max'='1',
  'insert.mode'='upsert',
  'topics'='PEOPLE_DENORMALISED',
  'auto.create'='true',
  'pk.mode'='record_value',
  'pk.fields'='IDENTITY_ID',
  'batch.size'='1',
  'table.name.format'='people'
);
```

# Data

Using the CLI tool `kafkacat` (you can install it using `brew install kafkacat` on osx):

```
cat data/people.data | kafkacat -b localhost:9092 -P -t people
```

And check the data exists in the database:
```
docker exec -it 065794b4cffb psql -U postgres -d denormalised
```

using:
- `\dt` command to prove the table was created
- `SELECT * FROM people;` to show the data

To ensure updates are working, there is a 2nd data file:

```
cat data/people.updated.data | kafkacat -b localhost:9092 -P -t people
```

# Troubleshooting

__KSQL Server logs__ can be accessed via `docker logs <container_id>` (use `-f` flag to live tail the log if you need to).