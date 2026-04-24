#!/bin/sh
# _rate_limit.sh — shared rate-limit / fast-failure detection helper.
# Used by both use-envoy and run-queue scripts. Source this file; do not execute directly.

# is_fast_failure <stderr_log>
# Returns 0 if the log contains a rate-limit, auth, or model-rejection pattern; 1 otherwise.
is_fast_failure() {
    [ -f "$1" ] || return 1
    grep -qiE 'rate[ _-]limit|rate_limited|hit a rate limit|quota|credits.*exhaust|out of usage|increase.*limit|not logged in|not authenticated|authorization.*error|usage.limit|too many requests|overloaded|credit balance|payment.*past due|account.*disabled|cannot use this model' "$1"
}
