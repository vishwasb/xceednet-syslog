#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE="/remotelogs/syslog_location_prefixes.txt"
OUTPUT_FILE="/remotelogs/syslog_recon_rpt.csv"

# --- Read input into maps keyed by LOCATION_PREFIX ---
declare -A LOC_URL IS_SUB LOGS_BY_XN IS_LOC_DISABLED IS_OP_DISABLED IS_ISP_DISABLED ONLINE_CNT
while IFS='|' read -r id url prefix is_sub logs_by_x loc_dis op_dis isp_dis online_cnt || [[ -n "${prefix:-}" ]]; do
  [[ -z "${prefix:-}" ]] && continue
  LOC_URL["$prefix"]="$url"
  IS_SUB["$prefix"]="${is_sub:-0}"
  LOGS_BY_XN["$prefix"]="${logs_by_x:-0}"
  IS_LOC_DISABLED["$prefix"]="${loc_dis:-0}"
  IS_OP_DISABLED["$prefix"]="${op_dis:-0}"
  IS_ISP_DISABLED["$prefix"]="${isp_dis:-0}"
  ONLINE_CNT["$prefix"]="${online_cnt:-0}"
done < "$INPUT_FILE"

# --- Collect active prefix|ip from filesystem (last 2 days) ---
declare -A ACTIVE_PARENT_PREFIX ACTIVE_PAIR
while IFS= read -r -d '' path; do
  [[ "$path" == */remotelogs/message\ * ]] && continue
  rel="${path#/remotelogs/}"
  prefix="${rel%%/*}"
  ip="${rel#*/}"; ip="${ip%%/*}"
  [[ "${IS_SUB[$prefix]:-0}" == "0" ]] && ACTIVE_PARENT_PREFIX["$prefix"]=1
  ACTIVE_PAIR["$prefix|$ip"]=1
done < <(find /remotelogs -type f -mtime -2 -name "syslog" -print0)

# --- HTML header ---
{
  printf 'MIME-Version: 1.0\n'
  printf 'Content-Type: text/html; charset=utf8\n'
  printf 'from: XNLogUser<alerts@xceednet.com>\n'
  printf 'Subject: Syslog Reconciliation - Daily Report\n'
  cat <<'HTML'
<html>
<head>
<style>
table, th, td { border:1px solid black; border-collapse:collapse; }
td { padding:5px; }
th { padding:5px; text-align:center; font-weight:bold; background-color:lightblue; }
tr:nth-child(even) { background-color:#f2f200; }
</style>
</head>
<body>
<h2>Syslog Reconciliation - Daily Report</h2>
HTML
} > "$OUTPUT_FILE"

# ===== Section 1 =====
{
  printf "<h3>1. Either Location/Operator/ISP is disabled OR the setting for logs_maintained_by_xceednet is FALSE but syslogs are still getting generated</h3>\n"
  printf "<table><tr><th>URL</th><th>Syslog Prefix</th><th>NAS IP</th><th>Error Description</th></tr>\n"

  # collect rows as: PREFIX<TAB>HTML
  declare -a buf=()
  for key in "${!ACTIVE_PAIR[@]}"; do
    prefix="${key%%|*}"
    ip="${key#*|}"
    [[ "${IS_SUB[$prefix]:-0}" == "1" ]] && continue

    loc_dis="${IS_LOC_DISABLED[$prefix]:-0}"
    op_dis="${IS_OP_DISABLED[$prefix]:-0}"
    isp_dis="${IS_ISP_DISABLED[$prefix]:-0}"
    logs_by_xn="${LOGS_BY_XN[$prefix]:-0}"

    msg=""
    if   [[ "$loc_dis" == "1" ]]; then msg="Location Status is Disabled"
    elif [[ "$op_dis"  == "1" ]]; then msg="Operator Status is Disabled"
    elif [[ "$isp_dis" == "1" ]]; then msg="ISP Status is Disabled"
    elif [[ "$logs_by_xn" == "0" ]]; then msg="Syslogs are not maintained by Xceednet"
    else
      continue
    fi

    url="${LOC_URL[$prefix]:-}"        # <- safe default prevents “unbound variable”
    buf+=("$prefix"$'\t'"<tr><td>${url}</td><td>${prefix}</td><td>${ip}</td><td>${msg}</td></tr>")
  done

  # sort and emit
  if ((${#buf[@]})); then
    mapfile -t sorted < <(printf '%s\n' "${buf[@]}" | sort -t$'\t' -k1,1)
    for line in "${sorted[@]}"; do printf "%s\n" "${line#*$'\t'}"; done
  fi
  printf "</table><br><br>\n"
} >> "$OUTPUT_FILE"

# ===== Section 2 =====
{
  printf "<h3>2. Location is Active AND the setting for logs_maintained_by_xceednet is TRUE but syslogs are NOT getting generated</h3>\n"
  printf "<table>\n<tr><th>URL</th><th>Syslog Prefix</th></tr>\n"

  declare -a buf=()
  while IFS='|' read -r _id url prefix is_sub logs_by_x loc_dis op_dis isp_dis online_cnt; do
    [[ "${is_sub:-0}" == "1" ]] && continue
    if [[ "${loc_dis:-0}" == "0" && "${op_dis:-0}" == "0" && "${isp_dis:-0}" == "0" \
          && "${logs_by_x:-0}" == "1" && "${online_cnt:-0}" != "0" \
          && -z "${ACTIVE_PARENT_PREFIX[$prefix]:-}" ]]; then
      buf+=("$prefix"$'\t'"<tr><td>${url}</td><td>${prefix}</td></tr>")
    fi
  done < "$INPUT_FILE"

  if ((${#buf[@]})); then
    mapfile -t sorted < <(printf '%s\n' "${buf[@]}" | sort -t$'\t' -k1,1)
    for line in "${sorted[@]}"; do printf "%s\n" "${line#*$'\t'}"; done
  fi
  printf "</table><br><br>\n"
} >> "$OUTPUT_FILE"

# ===== Section 3 =====
{
  printf "<h3>3. Log files with large size.</h3>\n"
  printf "<table>\n<tr><th>File Size</th><th>Online Subscribers<br>Count</th><th>URL</th><th>Syslog File</th></tr>\n"

  declare -a buf=()
  while IFS= read -r -d '' line; do
    size_bytes="${line%% *}"
    path="${line#* }"
    rel="${path#/remotelogs/}"
    prefix="${rel%%/*}"
    size_human="$(numfmt --to=iec --format="%.0f" "$size_bytes" 2>/dev/null || echo "$size_bytes")"
    url="${LOC_URL[$prefix]:-}"
    online="${ONLINE_CNT[$prefix]:-0}"
    # store as: size_bytes<TAB>prefix<TAB>HTML
    buf+=("$size_bytes"$'\t'"$prefix"$'\t'"<tr><td style='text-align:center'>${size_human}</td><td style='text-align:center'>${online}</td><td>${url}</td><td>${path}</td></tr>")
  done < <(find /remotelogs -type f -name "syslog" -size +256M -printf '%s %p\0')

  if ((${#buf[@]})); then
    # sort by size desc, then prefix asc
    mapfile -t sorted < <(printf '%s\n' "${buf[@]}" | sort -t$'\t' -k1,1nr -k2,2)
    for line in "${sorted[@]}"; do
      printf "%s\n" "${line#*$'\t'*$'\t'}"
    done
  fi
  printf "</table></body></html>\n"
} >> "$OUTPUT_FILE"
#cat $OUTPUT_FILE | /usr/sbin/ssmtp vishwas@xceednet.com
cat $OUTPUT_FILE | /usr/sbin/ssmtp support@xceednet.com
