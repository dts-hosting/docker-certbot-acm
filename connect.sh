#!/bin/bash
# ./connect.sh archivesspace-ex-complete ex-complete archivesspaceprogramteam

CLUSTER=$1
SERVICE=$2
PROFILE=$3

TASK=$(
  aws ecs list-tasks \
    --cluster $CLUSTER \
    --service-name $SERVICE \
    --profile $PROFILE \
    | jq -r '.["taskArns"][0] | split("/")[-1]'
)

aws ecs execute-command  \
  --cluster $CLUSTER \
  --task $TASK \
  --container certbot \
  --profile $PROFILE \
  --command "/bin/bash" \
  --interactive
