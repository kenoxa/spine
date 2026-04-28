---
task_id: task-a
entry_skill: /do-build
terminal_artifact: .scratch/queue-p0-conflict-test-task-a/build-status.json
max_iterations: 3
---

Edit the file `queues/queue-p0-conflict-test/conflict-subject.md`.

Change the line:

```
conflict_value: 1
```

to:

```
conflict_value: 2
```

No other changes. Commit the change with message:
`test(p0): task-a sets conflict_value to 2`

Acceptance: `grep -q 'conflict_value: 2' queues/queue-p0-conflict-test/conflict-subject.md` exits 0.
