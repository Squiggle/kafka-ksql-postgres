CREATE STREAM "event_user" (
  identity_id STRING,
  name STRING,
  family_name STRING,
  event_id STRING,
  event_type STRING
)
WITH (
  KAFKA_TOPIC='event_user',
  PARTITIONS=1,
  REPLICAS=1,
  VALUE_FORMAT='JSON'
);

CREATE STREAM "sink_denormalised_user" WITH (
  VALUE_FORMAT='AVRO'
) AS
  SELECT 
    identity_id as "id",
    name as "name",
    family_name as "family_name",
    name + ' ' + family_name AS "full_name",
    SUBSTRING(UCASE(name), 1, 1) + SUBSTRING(UCASE(family_name), 1, 1) as "initials",
    event_id as "event_id"
  FROM "event_user"
EMIT CHANGES
PARTITION BY "id";