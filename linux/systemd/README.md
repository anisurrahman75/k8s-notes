# systemd lab

Short notes plus one deliberately noisy Go process. The same binary is used to
learn services, transient units, cgroup limits, and bubblewrap isolation.

## Route

1. [What systemd manages](concepts/systemd.md)
2. [Run without writing a unit](concepts/systemd-run.md)
3. [Control CPU and memory](concepts/resource-control.md)
4. [Understand cgroups and sandboxing](concepts/cgroups-and-isolation.md)
5. [Build a tiny filesystem with bubblewrap](concepts/bubblewrap.md)
6. [Run the lab](demo/README.md)
7. [Quiz yourself](quiz/questions.md), then check the [answers](quiz/answers.md)

## Five-minute version

```bash
cd linux/systemd/demo
./scripts/build.sh

# Direct: one CPU worker, 64 MiB, stops after 5 seconds.
./bin/resource-burner -duration=5s

# Foreground transient scope with cgroup limits.
./scripts/run-scope.sh -duration=10s

# Empty filesystem + namespace isolation.
./scripts/run-bwrap.sh -cpu-workers=0 -memory-mib=8 -duration=3s
```

Watch a running transient unit:

```bash
systemctl --user status resource-burner-demo.scope
systemctl --user show resource-burner-demo.scope \
  -p ControlGroup -p CPUUsageNSec -p MemoryCurrent -p MemoryPeak
systemd-cgtop --user
```

The defaults intentionally consume one CPU and 64 MiB. Always give experiments
a `-duration` until you are comfortable stopping units with `systemctl`.

## Layout

```text
concepts/       small topic notes
demo/           Go source, scripts, and a persistent service unit
quiz/           questions and separate answers
prompt.md       original brief
resources.md    primary manuals and further reading
```
