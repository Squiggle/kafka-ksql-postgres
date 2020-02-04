Bootstrapping a Kafka/KSQL/Postgres pipeline to transform source records into a denormalised datastore.

# Up and running

```
docker-compose up -d
```

# Apply schema

This is the schema that our 
```
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" -d @'data/people_sink.schema_payload.json' http://localhost:8081/subjects/people_sink-value/versions
```

To confirm schemas, we can interrogate the Schema service's REST interface:

```
curl -X GET http://localhost:8081/subjects
```

# Topics

Confirm the broker is up and running by listing the topics. (use the appropriate container ID for the `kafka` broker instance)

```
docker exec -it bf758e195495 kafka-topics --zookeeper zookeeper:2181 --list
```

This should list a few of the core topics. Now we add one of our own.

```
docker exec -it bf758e195495 kafka-topics --zookeeper zookeeper:2181 --create --partitions 1 --replication-factor 1 --topic people
```

# KSQL

Open the KSQL CLI (the `ksqldb-cli` docker image)

```
docker exec -it 5492af6f2bb5 ksql http://ksqldb-server:8088
```

Recommended to run queries from the start of any log - `SET 'auto.offset.reset'='earliest';`

And in the KSQL CLI:
- Use a `STREAM` to retrieve specific data from a topic
- Use a `STREAM` apply a key to the data
- Use a `STREAM` to translate the JSON to AVRO format
- Use a `SINK CONNECTOR` to stream the data out to the postgres database

```
CREATE STREAM people_stream (
  identity_id STRING,
  name STRING
)
WITH (
  KAFKA_TOPIC='people',
  VALUE_FORMAT='JSON'
);

CREATE STREAM people_keyed
AS SELECT * from people_stream
PARTITION BY identity_id;

# alternative
CREATE STREAM people_keyed_avro WITH (
  'KAFKA_TOPIC'='people_stream',
  'VALUE_FORMAT'='AVRO'
)
AS SELECT * FROM people_stream
PARTITION BY identity_id;

CREATE STREAM people_sink
WITH (
  KAFKA_TOPIC='people_keyed',
  VALUE_FORMAT='AVRO'
) AS
SELECT
  identity_id,
  name as full_name
FROM people_keyed;

CREATE SINK CONNECTOR people_jdbc WITH (
  'connector.class'='io.confluent.connect.jdbc.JdbcSinkConnector',
  'connection.url'='jdbc:postgresql://postgres:5432/denormalised',
  'connection.user'='postgres',
  'connection.password'='postgres',
  'dialect.name'='PostgreSqlDatabaseDialect',
  'insert.mode'='upsert',
  'topics'='people_sink',
  'auto.create'='true',
  'pk.fields'='record_key',
  'tasks.max'='1',
  'batch.size'='1',
  'errors.tolerance'='all',
  'errors.log.enable'='true',
  'errors.log.include.messages'='true',
  'value.converter.schemas.enable'='true',
  'value.converter'='io.confluent.connect.avro.AvroConverter',
  'value.converter.schema.registry.url'='http://schema-registry:8081',
  'table.name.format'='people'
);
```

_Note: for testing, it might be handy to stream to a file instead

```
CREATE SINK CONNECTOR people_file WITH (
  'connector.class'='FileStreamSink',
  'tasks.max'='1',
  'file'='/tmp/test.txt',
  'topics'='people_sink'
);
```

# Data

Using the CLI tool `kafkacat` (you can install it using `brew install kafkacat` on osx):

```
cat data/people.data | kafkacat -b localhost:9092 -P -t people
```

And check the data exists in the topics:
```
kafkacat -b localhost:9092 -C -t people -o beginning
```


```
WIP - still can't get AVRO schema to work
perhaps the KSQL server can't locate the schema repository?
```

# Troubleshooting

__KSQL Server logs__ can be accessed via `docker logs <container_id>` (use `-f` flag to live tail the log if you need to).