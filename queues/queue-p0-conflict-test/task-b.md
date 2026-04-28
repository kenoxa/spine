---
task_id: task-b
entry_skill: /do-build
terminal_artifact: .scratch/queue-p0-conflict-test-task-b/build-status.json
max_iterations: 3
---

Edit the file `queues/queue-p0-conflict-test/conflict-subject.md`.

Change the line:

```
conflict_value: 1
```

to:

```
conflict_value: 3
```

No other changes. Commit the change with message:
`test(p0): task-b sets conflict_value to 3`

Acceptance: `grep -q 'conflict_value: 3' queues/queue-p0-conflict-test/conflict-subject.md` exits 0.
