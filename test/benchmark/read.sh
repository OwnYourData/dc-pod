#!/usr/bin/env bash

HOST="http://localhost:3600"
APP_KEY=$(docker logs pod | grep "APP_KEY:" | head -n1 | cut -d' ' -f2)
APP_SEC=$(docker logs pod | grep "APP_SEC:" | head -n1 | cut -d' ' -f2)
TOKEN=`curl -s -d grant_type=client_credentials -d client_id=$APP_KEY -d client_secret=$APP_SEC -d scope=write -X POST ${HOST}/oauth/token | jq -r '.access_token'`

# number of read operations (default 500)
READS=${1:-500}

# maximum OID (default 2000)
OID_RANGE=${2:-2000}

min_ms=0
max_ms=0
sum_ms=0

echo "Starting random read benchmark:"
echo "Reads: $READS"
echo "OID range: 1–$OID_RANGE"

for r in $(seq 1 $READS); do
  # pick a random object ID 1–OID_RANGE
  OID=$(( (RANDOM % OID_RANGE) + 1 ))

  start_ns=$(date +%s%N)

  curl -s -H "Authorization: Bearer $TOKEN" \
       ${HOST}/object/${OID}/read > /dev/null

  end_ns=$(date +%s%N)
  duration_ms=$(( (end_ns - start_ns) / 1000000 ))

  # print only every 10th iteration
  if (( r % 10 == 0 )); then
    echo "Read $r: ${duration_ms} ms (object-id ${OID})"
  fi

  # update statistics
  if [ "$r" -eq 1 ] || [ "$duration_ms" -lt "$min_ms" ]; then
    min_ms=$duration_ms
  fi

  if [ "$duration_ms" -gt "$max_ms" ]; then
    max_ms=$duration_ms
  fi

  sum_ms=$(( sum_ms + duration_ms ))
done

avg_ms=$(( sum_ms / READS ))

echo "----------------------------------------"
echo "Total reads performed : $READS"
echo "OID range used        : 1–$OID_RANGE"
echo "Minimum duration      : ${min_ms} ms"
echo "Maximum duration      : ${max_ms} ms"
echo "Average duration      : ${avg_ms} ms"