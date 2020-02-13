Bootstrapping a Kafka/KSQL/Postgres pipeline to transform source records into a denormalised datastore.

# Up and running

```
docker-compose up -d
```

Note that:
- Our KSQL configuration ensures that schemas are applied automatically (we do not need to apply schemas manually)
- Our docker configuration ensures that the `user` kafka topic is created as soon as it is referenced


The `docker-compose` file will bring up the following services:

| Service name  | Purpose                                                                                                                    |
|---------------|----------------------------------------------------------------------------------------------------------------------------|
| zookeeper     | A dependency of Kafka. Coordinates the connection(s) to Kafka brokers.                                                     |
| kafka         | Log database, composed of multiple topics                                                                                  |
| schema-server | Central repository of schema for various services to agree on the data structures within topics                            |
| ksqldb-server | Stream processor which consumes, translates and produces data between kafka topics using SQL-like syntax                   |
| kafka-connect | Service for linking kafka topics to external systems. Used in this case to translate data to postgres and other databases. |
| postgres      | database system                                                                                                            |

As well as executing two dockerised scripts:
- kafka-connect-init
- data-producer

Kafka-connect-init is responsible for automatically creating the JDBC sink connector (amongst others) which connects the sink topic in kafka to the Postgres database.

The data-producer is responsible for creating events in the system; both create events and update events.

# Querying the database

Connect to the database directly via the container:

```
docker-compose exec postgres psql -U postgres -d denormalised
```

using:
- `\dt` command to prove the table was created
- `SELECT * FROM user;` to show the data

# Development & Testing

Using the CLI tool `kafkacat` (you can install it using `brew install kafkacat` on osx):

## Show all topics

```
kafkacat -b localhost:9092 -L
```

## Query the topics

```
kafkacat -b localhost:9092 -t event_user -C
```

## Creating more events

Using producer mode `-P` to feed the contents of a data file to the `event_user` topic:

```
cat data/user.data | kafkacat -b localhost:9092 -P -t event_user
```

# Troubleshooting

__KSQL Server logs__ can be accessed via `docker-compose logs <container name>` (use `-f` flag to live tail the log if you need to).