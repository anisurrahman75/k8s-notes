#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# -eq 1 ]] || { echo "Usage: $0 EXACT.scope" >&2; exit 2; }
scope=$1
[[ $scope =~ ^mt5-lab-[0-9]+-[0-9]+\.scope$ ]] || { echo 'Refusing non-lab scope name.' >&2; exit 2; }
systemctl --user status "$scope" --no-pager || true
printf '\nSelected systemd properties:\n'
systemctl --user show "$scope" -p Id -p ActiveState -p SubState -p ControlGroup \
  -p CPUQuotaPerSecUSec -p CPUWeight -p MemoryHigh -p MemoryMax -p TasksMax
printf '\nCgroup tree:\n'; systemd-cgls --user-unit "$scope" || true

cg=$(systemctl --user show "$scope" -p ControlGroup --value)
[[ $cg == /* && $cg != *'..'* ]] || { echo 'Unsafe/empty ControlGroup.' >&2; exit 1; }
path="/sys/fs/cgroup$cg"
[[ -d $path ]] || { echo "Cgroup no longer exists: $path" >&2; exit 1; }
human() { numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || printf '%s bytes\n' "$1"; }
show() {
  local file=$1 value
  [[ -r $path/$file ]] || return 0
  value=$(<"$path/$file")
  printf '\n[%s]\n%s\n' "$file" "$value"
  if [[ $file == memory.current && $value =~ ^[0-9]+$ ]]; then printf 'human: '; human "$value"; fi
  if [[ $file == memory.high || $file == memory.max ]]; then
    if [[ $value == max ]]; then echo 'human: unlimited at this cgroup'; elif [[ $value =~ ^[0-9]+$ ]]; then printf 'human: '; human "$value"; fi
  fi
}
for file in cpu.max cpu.weight cpu.stat memory.current memory.high memory.max memory.events memory.stat pids.current pids.max cgroup.procs cgroup.threads; do show "$file"; done

printf '\nProcesses and membership:\n'
while read -r pid; do
  [[ -r /proc/$pid/status ]] || continue
  comm=$(<"/proc/$pid/comm")
  args=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)
  rel=$(awk -F: '$1=="0" {print $3}' "/proc/$pid/cgroup")
  printf 'pid=%s comm=%q cgroup=%q cmd=%q\n' "$pid" "$comm" "$rel" "$args"
done <"$path/cgroup.procs"
printf '\nWine/MT5 host process tree (verify every relevant row uses %s):\n' "$cg"
ps -eo pid,ppid,cgroup,cmd --forest | grep -E 'PID|wine|wineserver|terminal64\.exe' || true
cat <<'EOF'

cpu.stat: nr_periods is elapsed quota periods; nr_throttled counts periods that hit quota;
throttled_usec is cumulative delayed time. Rising values prove CPU throttling.
memory.events: rising oom/oom_kill counters since baseline indicate OOM activity/kills.
EOF

