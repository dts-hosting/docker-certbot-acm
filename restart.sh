#!/bin/bash
# ./restart.sh archivesspace-ex-complete ex-complete archivesspaceprogramteam

CLUSTER=$1
SERVICE=$2
PROFILE=${3-default}

aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment \
  --profile $PROFILE
