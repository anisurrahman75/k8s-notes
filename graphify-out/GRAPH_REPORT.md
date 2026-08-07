# Graph Report - linux/systemd  (2026-08-07)

## Corpus Check
- Corpus is ~289 words - fits in a single context window. You may not need a graph.

## Summary
- 23 nodes · 21 edges · 5 communities (4 shown, 1 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 1 edges (avg confidence: 0.95)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Resource Control and Isolation|Resource Control and Isolation]]
- [[_COMMUNITY_Learning Lab Structure|Learning Lab Structure]]
- [[_COMMUNITY_systemd Foundations|systemd Foundations]]
- [[_COMMUNITY_Units and Service Lifecycle|Units and Service Lifecycle]]
- [[_COMMUNITY_Further Resources|Further Resources]]

## God Nodes (most connected - your core abstractions)
1. `systemd Learning Plan` - 7 edges
2. `systemctl` - 4 edges
3. `Go CPU and Memory Burner Demo` - 4 edges
4. `systemd` - 3 edges
5. `systemd Overview` - 2 edges
6. `Init System` - 2 edges
7. `systemd-run` - 2 edges
8. `CPU and Resource Limits` - 2 edges
9. `Bubblewrap (bwrap)` - 2 edges
10. `PID 1` - 1 edges

## Surprising Connections (you probably didn't know these)
- `systemd Overview` --references--> `systemctl`  [EXTRACTED]
  linux/systemd/README.md → linux/systemd/README.md  _Bridges community 2 → community 3_
- `systemd Learning Plan` --references--> `Go CPU and Memory Burner Demo`  [EXTRACTED]
  linux/systemd/prompt.md → linux/systemd/prompt.md  _Bridges community 1 → community 0_

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Resource Control and Isolation Learning Flow** — systemd_prompt_systemd_run, systemd_prompt_go_resource_burner, systemd_prompt_cpu_and_resource_limits, systemd_prompt_cgroups, systemd_prompt_bwrap [EXTRACTED 1.00]
- **systemd Learning Content Structure** — systemd_prompt_concept_directory, systemd_prompt_demo_directory, systemd_prompt_quiz_section [EXTRACTED 1.00]

## Communities (5 total, 1 thin omitted)

### Community 0 - "Resource Control and Isolation"
Cohesion: 0.33
Nodes (6): Bubblewrap (bwrap), Control Groups (cgroups), CPU and Resource Limits, Complete Filesystem Isolation, Go CPU and Memory Burner Demo, systemd-run

### Community 1 - "Learning Lab Structure"
Cohesion: 0.33
Nodes (6): Concept Notes Directory, Demo Project Directory, Quiz Section, Short Human-Style Notes, systemd, systemd Learning Plan

### Community 2 - "systemd Foundations"
Cohesion: 0.40
Nodes (5): Init System, PID 1, Process Management, systemd, systemd Overview

### Community 3 - "Units and Service Lifecycle"
Cohesion: 0.50
Nodes (4): Boot Service Enablement, Service Lifecycle Management, systemctl, systemd Units

## Knowledge Gaps
- **12 isolated node(s):** `PID 1`, `Process Management`, `systemd Units`, `Service Lifecycle Management`, `Boot Service Enablement` (+7 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `systemd Learning Plan` connect `Learning Lab Structure` to `Resource Control and Isolation`?**
  _High betweenness centrality (0.173) - this node is a cross-community bridge._
- **Why does `Go CPU and Memory Burner Demo` connect `Resource Control and Isolation` to `Learning Lab Structure`?**
  _High betweenness centrality (0.139) - this node is a cross-community bridge._
- **Why does `systemctl` connect `Units and Service Lifecycle` to `systemd Foundations`?**
  _High betweenness centrality (0.078) - this node is a cross-community bridge._
- **What connects `PID 1`, `Process Management`, `systemd Units` to the rest of the system?**
  _14 weakly-connected nodes found - possible documentation gaps or missing edges._