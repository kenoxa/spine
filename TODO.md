# TODO

- implemnet do-history-recap
- svelte skill with autofixer script like we have in nestor
- auto-loading per glob like min description? 
- No built-in to-dos:
  Does not and will not support built-in to-dos. In my experience, to-do lists generally confuse models more than they help. They add state that the model has to track and update, which introduces more opportunities for things to go wrong.

	If you need task tracking, make it externally stateful by writing to a file: <session>/todo.md

	```md
	# TODO.md
	
	- [x] Implement user authentication
	- [x] Add database migrations
	- [ ] Write API documentation
	- [ ] Add rate limiting
	```

	The agent can read and update this file as needed. Using checkboxes keeps track of what's done and what remains. Simple, visible, and under your control.

	Or use the plan todo/step tracking (see below)
- No plan mode
  Does not and will not have a built-in plan mode. Telling the agent to think through a problem together with you, without modifying files or executing commands, is generally sufficient.

	If you need persistent planning across sessions, write it to a file: <session>/plan.md

	```md
	# PLAN.md

	## Tasks / ToDos

	- [ ] ....

	## Current Step

	...

	## Implementation Notes
	```

	The agent can read, update, and reference the plan as it works. Unlike ephemeral planning modes that only exist within a session, file-based plans can be shared across sessions, and can be versioned with your code.
