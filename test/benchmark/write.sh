#!/usr/bin/env bash

HOST="http://localhost:3600"
APP_KEY=$(docker logs pod | grep "APP_KEY:" | head -n1 | cut -d' ' -f2)
APP_SEC=$(docker logs pod | grep "APP_SEC:" | head -n1 | cut -d' ' -f2)
TOKEN=`curl -s -d grant_type=client_credentials -d client_id=$APP_KEY -d client_secret=$APP_SEC -d scope=write -X POST ${HOST}/oauth/token | jq -r '.access_token'`

echo '{"name": "Collection"}' | curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d @- \
-X POST ${HOST}/collection/ > /dev/null

# number of measurements and datasets per measurement
MEASUREMENTS=100
PER_MEASUREMENT=10

min_ms=0
max_ms=0
sum_ms=0

for j in $(seq 1 $MEASUREMENTS); do
  start_ns=$(date +%s%N)

  # write 10 datasets per measurement
  for k in $(seq 1 $PER_MEASUREMENT); do
    OID=$(echo "{\"name\":\"dataset ${j}-${k}\", \"collection-id\":1}" | \
    curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d @- \
    -X POST ${HOST}/object/ | jq -r '.["object-id"]')

    N=10
    { printf '{'; for i in $(seq 1 $N); do printf '"key%i":"value%i"' "$i" "$i"; [ "$i" -lt "$N" ] && printf ','; done; printf '}\n'; } | \
    curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d @- \
    -X PUT ${HOST}/object/$OID/write > /dev/null
  done

  end_ns=$(date +%s%N)
  duration_ms=$(( (end_ns - start_ns) / 1000000 ))
  echo "Measurement $j: ${duration_ms} ms (10 datasets)"

  # update min/max/sum
  if [ "$j" -eq 1 ] || [ "$duration_ms" -lt "$min_ms" ]; then
    min_ms=$duration_ms
  fi

  if [ "$duration_ms" -gt "$max_ms" ]; then
    max_ms=$duration_ms
  fi

  sum_ms=$(( sum_ms + duration_ms ))
done

avg_ms=$(expr $sum_ms / $MEASUREMENTS)
total_datasets=$(expr $MEASUREMENTS \* $PER_MEASUREMENT)

echo "----------------------------------------"
echo "Number of measurements : $MEASUREMENTS"
echo "Total datasets written : $total_datasets"
echo "Minimum duration       : ${min_ms} ms"
echo "Maximum duration       : ${max_ms} ms"
echo "Average duration       : ${avg_ms} ms"