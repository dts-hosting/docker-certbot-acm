#!/bin/bash
# ./run.sh archivesspace-ex-complete ex-complete archivesspaceprogramteam

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

# replace command "/root/bootstrap.sh" with "bash" to access the container
aws ecs execute-command  \
  --cluster $CLUSTER \
  --task $TASK \
  --container certbot \
  --profile $PROFILE \
  --command "/root/bootstrap.sh" \
  --interactive
