#!/usr/bin/env bash
# usage: bash tools/run_bots.sh <bot> <map> <difficulty> <runs> <jobs>
BOT=${1:-greedy}; MAP=${2:-plains}; DIFF=${3:-0}; RUNS=${4:-200}; JOBS=${5:-8}
GODOT="${GODOT:-godot}"
NAME="${BOT}_${MAP}_d${DIFF}"
PER=$(( (RUNS + JOBS - 1) / JOBS ))
mkdir -p bot_reports/parts
rm -f bot_reports/parts/${NAME}_*
for (( j=0; j<JOBS; j++ )); do
  START=$(( 1 + j * PER ))
  COUNT=$(( RUNS - j * PER ))
  [ "$COUNT" -gt "$PER" ] && COUNT=$PER
  [ "$COUNT" -le 0 ] && break
  "$GODOT" --headless --path . --script res://tools/bot_sim.gd -- \
    --bot="$BOT" --map="$MAP" --difficulty="$DIFF" \
    --seed-start="$START" --runs="$COUNT" \
    --out="bot_reports/parts/${NAME}_$j.csv" > "bot_reports/parts/${NAME}_$j.log" 2>&1 &
done
wait
OUT="bot_reports/${NAME}.csv"
FIRST=1
for f in bot_reports/parts/${NAME}_*.csv; do
  if [ $FIRST -eq 1 ]; then cat "$f" > "$OUT"; FIRST=0; else tail -n +2 "$f" >> "$OUT"; fi
done
if grep -q "SCRIPT ERROR" bot_reports/parts/${NAME}_*.log; then
  echo "WARNING: script errors found in bot logs"
fi
"$GODOT" --headless --path . --script res://tools/bot_summary.gd -- --in="$OUT"