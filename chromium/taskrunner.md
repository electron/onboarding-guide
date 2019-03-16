# `TaskRunner` & `SequencedTaskRunner` & `SingleThreadTaskRunner`

These are interfaces for posting `base::Callbacks` "tasks" to be run.

## `TaskRunner`

A `TaskRunner` is an object that runs posted tasks (in the form of
`Closure` objects).  The `TaskRunner` interface provides a way of decoupling task posting from the mechanics of how each task will be
run.  `TaskRunner `provides very weak guarantees as to how posted
tasks are run (or if they're run at all).  In particular, it only
guarantees:
* Posting a task will not run it synchronously.  That is, no
  `Post*Task` method will call `task.Run()` directly.
* Increasing the delay can only delay when the task gets run.
  That is, increasing the delay may not affect when the task gets
  run, or it could make it run later than it normally would, but
  it won't make it run earlier than it normally would.

NOTE: A very useful member function of TaskRunner is `PostTaskAndReply()`, which will post a task to a target `TaskRunner` and on completion post a "reply" task to the origin `TaskRunner`.

`TaskRunner` does not guarantee the order in which posted tasks are
run, whether tasks overlap, or whether they're run on a particular
thread.

**Relevant Functions:**

```cpp
// Posts the given task to be run.  Returns true if the task may be
// run at some point in the future, and false if the task definitely
// will not be run.
bool PostTask(const Location& from_here, OnceClosure task);

// Posts |task| on the current TaskRunner.  On completion, |reply|
// is posted to the thread that called PostTaskAndReply().  Both
// |task| and |reply| are guaranteed to be deleted on the thread
// from which PostTaskAndReply() is invoked.  This allows objects
// that must be deleted on the originating thread to be bound into
// the |task| and |reply| Closures.
bool PostTaskAndReply(const Location& from_here,
                        OnceClosure task,
                        OnceClosure reply);
```

## `SequencedTaskRunner`

A `SequencedTaskRunner` is a subclass of `TaskRunner` that provides
additional guarantees on the order that tasks are started, as well
as guarantees on when tasks are in sequence, i.e. one task finishes
before the other one starts.

Generally: Non-nested tasks with the same delay will run one by one in FIFO order.

Almost no subclass-specific methods are used in Electron's codebase, so you don't need to stress overly about knowing the specifics beyond the above.

## `SingleThreadTaskRunner`

A `SingleThreadTaskRunner` is a `SequencedTaskRunner` with one more
guarantee; all tasks are run on a single dedicated
thread.  Most use cases require only a `SequencedTaskRunner`, unless
there is a specific need to run tasks on only a single thread.
