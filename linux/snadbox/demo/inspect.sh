#!/usr/bin/env bash
# inspect.sh — look at a running minicontainer from the HOST side.
#
# This is `docker inspect` + `kubectl describe`, done by hand.
# Run ./minicontainer.sh in one terminal, then this in another.
#
# Usage:  ./inspect.sh [container-name]     # e.g. ./inspect.sh mc-12345
#         ./inspect.sh                      # auto-detect the only running one

set -uo pipefail

U=$(id -u)
CGROOT="/sys/fs/cgroup/user.slice/user-$U.slice/user@$U.service"

NAME="${1:-}"
if [ -z "$NAME" ]; then
  mapfile -t found < <(find "$CGROOT" -maxdepth 1 -name 'mc-*' -printf '%f\n' 2>/dev/null)
  case ${#found[@]} in
    0) echo "no minicontainer cgroups found under $CGROOT" >&2; exit 1 ;;
    1) NAME="${found[0]}" ;;
    *) echo "several running — pick one:"; printf '  %s\n' "${found[@]}"; exit 1 ;;
  esac
fi

CG="$CGROOT/$NAME"
[ -d "$CG" ] || { echo "no such cgroup: $CG" >&2; exit 1; }

PIDS=$(cat "$CG/cgroup.procs" 2>/dev/null)

# The `unshare` wrapper stays in the HOST pid namespace; only its child is the
# container's PID 1 (see ../concepts/2.pid/2.fork-rule.md). Pick the process
# whose NSpid line has two columns -- that one is really inside.
INIT=""
for p in $PIDS; do
  if [ "$(grep -c . <<<"$(grep NSpid "/proc/$p/status" 2>/dev/null | tr -s '\t' ' ' | cut -d' ' -f2-)")" -gt 0 ] &&
     [ "$(grep NSpid "/proc/$p/status" 2>/dev/null | tr -s '\t' ' ' | awk '{print NF}')" -ge 3 ]; then
    INIT="$p"; break
  fi
done
[ -n "$INIT" ] || INIT=$(echo "$PIDS" | head -1)

hr() { printf '\n\033[1m── %s \033[0m%s\n' "$1" "$(printf '%.0s─' $(seq 1 $((60 - ${#1}))))"; }

hr "cgroup: $NAME"
printf '  memory.max      %s\n' "$(cat "$CG/memory.max")"
printf '  memory.current  %s\n' "$(cat "$CG/memory.current")"
printf '  memory.peak     %s\n' "$(cat "$CG/memory.peak" 2>/dev/null)"
printf '  cpu.max         %s\n' "$(cat "$CG/cpu.max")"
printf '  pids.max        %s\n' "$(cat "$CG/pids.max")"
printf '  pids.current    %s\n' "$(cat "$CG/pids.current")"

hr "events (the receipts)"
sed 's/^/  memory.events: /' "$CG/memory.events"
grep -E 'nr_periods|nr_throttled|throttled_usec|usage_usec' "$CG/cpu.stat" | sed 's/^/  cpu.stat:      /'
sed 's/^/  pids.events:   /' "$CG/pids.events"

hr "pressure (PSI — rises BEFORE things die)"
printf '  cpu    %s\n' "$(head -1 "$CG/cpu.pressure")"
printf '  memory %s\n' "$(head -1 "$CG/memory.pressure")"

[ -n "$INIT" ] || { hr "no processes"; exit 0; }

hr "processes (host PID -> namespace PID)"
for p in $PIDS; do
  cmd=$(tr '\0\n' '  ' < "/proc/$p/cmdline" 2>/dev/null | tr -s ' ' | cut -c1-38)
  nsp=$(grep NSpid "/proc/$p/status" 2>/dev/null | tr -s '\t' ' ')
  note=""
  [ "$p" = "$INIT" ] && note="  <- container PID 1"
  [ "$(awk '{print NF}' <<<"$nsp")" -lt 3 ] && note="  <- unshare wrapper (still on the host)"
  printf '  %-8s %-38s %s%s\n' "$p" "$cmd" "$nsp" "$note"
done

hr "namespaces of PID $INIT"
for ns in user mnt pid uts ipc net cgroup; do
  mine=$(readlink "/proc/self/ns/$ns")
  theirs=$(readlink "/proc/$INIT/ns/$ns" 2>/dev/null)
  [ -z "$theirs" ] && continue
  if [ "$mine" = "$theirs" ]; then mark="shared with host"; else mark="ISOLATED"; fi
  printf '  %-7s %-22s %s\n' "$ns" "$theirs" "$mark"
done

hr "its filesystem, read from the host (no nsenter needed)"
printf '  ls /proc/%s/root/\n' "$INIT"
ls "/proc/$INIT/root/" 2>/dev/null | tr '\n' ' ' | sed 's/^/  /' ; echo
printf '  (that is the container rootfs — the host sees straight into it)\n'

hr "how to walk in"
cat <<EOF
  nsenter -t $INIT -a --preserve-credentials -- /bin/sh
  nsenter -t $INIT -m -- ls /            # borrow just its filesystem
  nsenter -t $INIT -p -- ps aux          # borrow just its process table
  sudo ls /proc/$INIT/root/              # read files without entering at all

  echo 1 > $CG/cgroup.kill               # kill the whole thing
EOF
echo
