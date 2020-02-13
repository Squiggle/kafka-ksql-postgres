#!/bin/bash

cat /etc/data/user.data | kafkacat -b kafka:29092 -P -t event_user;

cat /etc/data/user.update.data | kafkacat -b kafka:29092 -P -t event_user;