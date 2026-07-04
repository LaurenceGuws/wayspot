# Wayspot Project Memory

This directory is local memory for Wayspot.
The live source of truth is:

- `current.yaml`
- `sprint.yaml`
- `references.yaml`

`artifacts.jsonl` is historical Wayspot memory until explicitly archived.

Agents read local memory in this order:

1. `AGENTS.md`
2. `.agent/history/README.md`
3. `.agent/history/current.yaml`
4. `.agent/history/sprint.yaml`
5. `.agent/history/references.yaml`
6. repo `README.md`

The qagent project provided the copied way-of-work framework. Its live memory is
not authority for Wayspot.

Comments are planned production code. Planning and memory are production artifacts.

Only the user and coordinating agent may rewrite live memory by default.
Workers may propose exact memory edits unless explicitly authorized to write.
