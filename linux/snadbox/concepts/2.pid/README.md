# **PID Namespaces**

> **Prerequisite:** [../1.namespaces/](../1.namespaces/README.md)

## **Files in this folder**

| # | File | Topic |
|---|------|-------|
| 1 | [1.first-namespace.md](1.first-namespace.md) | Hands-on: become PID 1 |
| 2 | [2.fork-rule.md](2.fork-rule.md) | Why `--fork` is mandatory |
| 3 | [3.mount-proc.md](3.mount-proc.md) | Why `--mount-proc` is mandatory |
| 4 | [4.pid1-semantics.md](4.pid1-semantics.md) | Signals, and why PID 1's death kills everything |
| 5 | [5.reaping.md](5.reaping.md) | Zombies, `tini`, and the Kubernetes gotchas |
| 6 | [6.debugging.md](6.debugging.md) | Mapping host PID ↔ container PID, nesting |

---

## **The Idea**

> A PID namespace gives processes their **own PID number space**, starting at 1.

Four consequences follow from that one sentence:

1. The first process in the namespace **is PID 1** and inherits `init` semantics.
2. A process can **only signal what it can see** — `kill(9999)` inside hits *its* 9999, not the host's.
3. The namespace is **hierarchical** — a parent sees and signals every descendant, never the reverse.
4. A process has **N PIDs**, one per namespace level it belongs to.

```
        HOST PID NAMESPACE
        ┌──────────────────────────────────────┐
        │ 1 systemd    2444 pipewire           │
        │                                      │
        │ 428107 sleep ──┐                     │
        │                │ same process        │
        │   ┌────────────▼──────────────┐      │
        │   │ CHILD PID NAMESPACE       │      │
        │   │  1 sleep                  │      │
        │   └───────────────────────────┘      │
        └──────────────────────────────────────┘
         host can signal down ▼ ; child cannot look up ▲
```

---

## **The one structural quirk**

**A running process can never change its PID namespace.** Its PID is assigned at creation and is immutable. `unshare(CLONE_NEWPID)` and `setns(CLONE_NEWPID)` only affect **future children**.

That single fact explains:

* why `/proc/self/ns/` has a separate **`pid_for_children`** entry
* why `unshare -p` **requires `--fork`** ([2.fork-rule.md](2.fork-rule.md))
* why `nsenter --pid` leaves your shell behind in the old namespace

---

## **The two rules to memorise**

```bash
#  -p ALWAYS with -f            (the namespace applies to children only)
#  -p ALWAYS with --mount-proc  (else ps/top still show the host)

unshare -Urpf --mount-proc bash
```

---

**Start here → [1.first-namespace.md](1.first-namespace.md)**
