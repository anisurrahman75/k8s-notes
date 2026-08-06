#!/usr/bin/env bash
set -Eeuo pipefail

child=''
cleanup() {
  if [[ -n $child ]] && kill -0 "$child" 2>/dev/null; then
    kill -TERM "$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

bash -c 'trap "exit 0" TERM; while :; do sleep 30 & wait $!; done' &
child=$!
sleep 0.1

printf 'Lab shell PID: %s\nChild PID: %s\n\n' "$$" "$child"
ps -o pid,ppid,nlwp,stat,cmd -p "$$,$child"
printf '\nSelected /proc/%s/status fields:\n' "$child"
awk '/^(Name|State|Pid|PPid|Threads|NSpid|Uid|Gid):/ {print}' "/proc/$child/status"
printf '\nCommand line: '
tr '\0' ' ' <"/proc/$child/cmdline"
printf '\n\nFile descriptors:\n'
ls -l "/proc/$child/fd"
printf '\nNamespace identities (shell -> child):\n'
for ns in pid mnt net uts ipc user; do
  printf '%-5s %-20s -> %s\n' "$ns" "$(readlink "/proc/$$/ns/$ns")" "$(readlink "/proc/$child/ns/$ns")"
done
printf '\nCgroup membership:\n'
cat "/proc/$child/cgroup"
printf '\nCleanup will terminate only PID %s.\n' "$child"

