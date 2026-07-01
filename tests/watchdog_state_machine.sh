#!/usr/bin/env bash
set -euo pipefail

IP_BAD_THRESHOLD=2
API_BAD_THRESHOLD=3
RESUME_GOOD_THRESHOLD=2

reset_machine() {
  state="healthy"
  ip_bad_count=0
  api_bad_count=0
  resume_good_count=0
  last_action="none"
}

handle_event() {
  local event="$1"
  last_action="none"

  case "$event" in
    ok)
      ip_bad_count=0
      api_bad_count=0
      case "$state" in
        paused|resume-pending)
          resume_good_count=$((resume_good_count + 1))
          if [ "$resume_good_count" -ge "$RESUME_GOOD_THRESHOLD" ]; then
            state="healthy"
            resume_good_count=0
            last_action="resume"
          else
            state="resume-pending"
          fi
          ;;
        *)
          state="healthy"
          resume_good_count=0
          ;;
      esac
      ;;
    ip_drift)
      resume_good_count=0
      ip_bad_count=$((ip_bad_count + 1))
      if [ "$ip_bad_count" -ge "$IP_BAD_THRESHOLD" ]; then
        state="paused"
        last_action="pause"
      elif [ "$state" = "resume-pending" ]; then
        state="paused"
      else
        state="degraded"
      fi
      ;;
    api_fail)
      resume_good_count=0
      api_bad_count=$((api_bad_count + 1))
      if [ "$api_bad_count" -ge "$API_BAD_THRESHOLD" ]; then
        state="paused"
        last_action="pause"
      elif [ "$state" = "resume-pending" ]; then
        state="paused"
      else
        state="degraded"
      fi
      ;;
    wake_gap)
      resume_good_count=0
      if [ "$state" = "paused" ]; then
        state="resume-pending"
      else
        state="degraded"
      fi
      last_action="validate"
      ;;
    *)
      printf 'unknown event: %s\n' "$event" >&2
      exit 1
      ;;
  esac
}

assert_state() {
  local expected_state="$1"
  local expected_action="$2"
  local label="$3"

  if [ "$state" != "$expected_state" ] || [ "$last_action" != "$expected_action" ]; then
    printf 'FAIL %s: state=%s action=%s expected_state=%s expected_action=%s\n' \
      "$label" "$state" "$last_action" "$expected_state" "$expected_action" >&2
    exit 1
  fi
}

reset_machine
handle_event ip_drift
assert_state degraded none "one ip drift degrades only"
handle_event ip_drift
assert_state paused pause "two ip drifts pause"

reset_machine
handle_event api_fail
assert_state degraded none "one api failure degrades only"
handle_event api_fail
assert_state degraded none "two api failures stay degraded"
handle_event api_fail
assert_state paused pause "three api failures pause"

reset_machine
handle_event ip_drift
handle_event ip_drift
assert_state paused pause "setup paused from ip drift"
handle_event ok
assert_state resume-pending none "first healthy check waits"
handle_event ok
assert_state healthy resume "second healthy check resumes"

reset_machine
handle_event ip_drift
handle_event ip_drift
handle_event ok
assert_state resume-pending none "setup resume pending"
handle_event api_fail
assert_state paused none "failure during resume pending returns to paused"

reset_machine
handle_event wake_gap
assert_state degraded validate "wake gap from healthy forces validation"

printf 'watchdog state machine ok\n'
