# There and Back Again: Interprocess Communication and Memory Management in Electron's `remote.require()`

## Electron's Multi-Process Architecture

Electron has a multiprocess architecture: Electron apps have **renderer processes** to load web pages and show a GUI, and exactly one **main process** to interact with the OS and handle application lifecycle events such as starting, exiting, and sleeping.

Calling native APIs from a web page is not allowed because of security issues and because of the ease of leaking resources. If you want to perform GUI operations in a web page, the web page's renderer process must communicate with the main process to request that the main process perform those operations. More background on the main and renderer processes is available in [Electron's documentation](https://electronjs.org/docs/tutorial/application-architecture#main-and-renderer-processes).

## Introducing `remote.require()`

[`remote.require()`](https://electronjs.org/docs/api/remote#remoterequiremodule) is a convenient way for renderers to talk to the main process. To the renderer process code using it, `remote.require()` looks like a [Node require() call](https://nodejs.org/api/modules.html#modules_require_id). However, the module is imported into the _main_ process and then proxied in the _renderer_ process. Electron users' code can invoke these proxies without needing to know or care about the inter-process communication (IPC) and resource management that's handled invisibly by Electron.

## A First Example: `doubleIt()`

Let's see how this looks in practice with a simple synchronous function. Using [electron-quick-start](https://github.com/electron/electron-quick-start) as a starting point, we'll export a new `doubleIt()` method from the main process in `main.js`:

```javascript=
exports.doubleIt = x => x + x;
```

In `renderer.js`, we'll add code for the renderer to import and invoke it:

```javascript=
const { remote } = require('electron');
const main = remote.require('./main.js');

const single = 2;
const double = main.doubleIt(single);
console.log(`single is ${single}, double is ${double}`);
```

As you'd expect, running this code looks like this:

```sh
single is 2, double is 4
```

The renderer made the call, but the main process did the doubling. It's literally as easy as `2 + 2 === 4` to Electron's users, but there’s actually a lot going on under the surface. Here's how it works:

## Round Trip #1: `remote.require()`

Defined [in](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/renderer/api/remote.js#L293) `electron/lib/renderer/api/remote.js`, `remote.require()` is a thin wrapper around two other functions:

```javascript=
exports.require = (module) => {
  const command = 'ELECTRON_BROWSER_REQUIRE'
  const meta = ipcRendererInternal.sendSync(command, contextId, module)
  return metaToValue(meta)
}
```

The third line shows the renderer process sending three strings to the main process:

1. `'ELECTRON_BROWSER_REQUIRE'`
2. `contextId`, an [internal](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/atom/renderer/renderer_client_base.cc#L115) string to uniquely identify the IPC caller's source [V8 context](https://v8.dev/docs/embed#contexts).
3. The user-provided module parameter (e.g. `./main.js`).

By following `ipcRendererInternal.sendSync()` a few steps ([1](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/renderer/ipc-renderer-internal.ts), [2](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/atom/renderer/api/atom_api_renderer_ipc.cc#L45), [3](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/atom/common/api/api_messages.h#L33a), [4](https://cs.chromium.org/chromium/src/ipc/ipc_message_macros.h?q=IPC_SYNC_MESSAGE_ROUTED3_1&sq=package:chromium&dr=CSs&l=518)), we learn that Electron processes use Chromium's IPC Messages to communicate. Chromium's internals are beyond this article's scope, but interested readers can learn more from its [source](https://cs.chromium.org/chromium/src/ipc/ipc_message_macros.h) and [documentation](https://www.chromium.org/developers/design-documents/inter-process-communication#Messages).

Over in the main process, this call is received [by]( https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/browser/rpc-server.js#L310) `lib/browser/rpc-server.js`:

```javascript=
 handleRemoteCommand('ELECTRON_BROWSER_REQUIRE', function (event, contextId, moduleName) {
   const customEvent = eventBinding.createWithSender(event.sender)
   event.sender.emit('remote-require', customEvent, moduleName)
   if (customEvent.returnValue === undefined) {
     if (customEvent.defaultPrevented) {
       throw new Error(`Blocked remote.require('${moduleName}')`)
     } else {
       customEvent.returnValue = process.mainModule.require(moduleName)
     }
   }

   return valueToMeta(event.sender, contextId, customEvent.returnValue)
 })
```

The `handleRemoteCommand()`  method on line `1` [is](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/browser/rpc-server.js#L281) a small helper that checks permissions, calls the wrapped function, and sends its return values / exceptions back to the calling process. Here, the wrapped function is the `ELECTRON_BROWSER_REQUIRE` handler which does three things:

1. Emit a [`remote-require` event](https://electronjs.org/docs/api/app#event-remote-require) in case the app developer wants to override the import.
2. If nothing's overridden in step 1, use Node's [`process.mainModule`](https://nodejs.org/api/process.html#process_process_mainmodule) to import `moduleName`.
3. The result from steps 1 and 2 is serialized by [`valueToMeta()`](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/browser/rpc-server.js#L69) and returned to `handleRemoteCommand()`, which sends it to the renderer process. The renderer's call to `ipcRendererInternal.sendSync()` finally returns with this `meta`. That's converted back into a value -- or, actually, a renderer process proxy of a main process value -- by `metaToValue()` and returned. The caller to `remote.require()` gets this proxy.

## `valueToMeta()` for a simple function

In the main process, [`valueToMeta()`](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/browser/rpc-server.js#L69) builds a `meta` to be sent over IPC. It's an involved process. For our `doubleIt()` example, the `value` being converted is the object returned by `process.mainModule.require()`, so [this](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/browser/rpc-server.js#L98) block builds the meta:

```javascript=
 } else if (meta.type === 'object' || meta.type === 'function') {
   meta.name = value.constructor ? value.constructor.name : ''

   // Reference the original value if it's an object, because when it's
   // passed to renderer we would assume the renderer keeps a reference of
   // it.
   meta.id = objectsRegistry.add(sender, contextId, value)
   meta.members = getObjectMembers(value)
   meta.proto = getObjectPrototype(value)
 } else if (meta.type === 'buffer') {
```

**`objectsRegistry`** [is](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/browser/objects-registry.js) a singleton in the main process. `valueToMeta()` uses it here to hold references to `value`s so that they're protected from V8 garbage collection while the renderer is using them. This is the meaning of the "the object keeps a reference of it" comment in the code above. We'll see `objectsRegistry` again later when the proxies' life cycles end.

`meta.id` is also noteworthy: That's a key for looking up objects in `objectsRegistry` and we'll need it later to invoke `doubleIt()` in Round Trip #2.

Next [is](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/browser/rpc-server.js#L35) `getObjectMembers()`. It's straightforward enough: it uses [`Object.getOwnPropertyNames()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/getOwnPropertyNames) and [`Object.getOwnPropertyDesciptor()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/getOwnPropertyDescriptor) to build an array of objects holding the methods' names, their types (method or accessor), whether they're enumerable, and so on.

Third and last is [`getObjectPrototype()`](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/browser/rpc-server.js#L59), which walks up `value`'s prototype chain and repeats the `getObjectMembers()` step for the prototype.

At last, that `meta` is serialized into JSON and that's what's returned back to the renderer process. For the `doubleIt()` example, it looks like this:

```json=
{
  type: 'object',
  name: 'Object',
  id: 1,
  members: [
    {
      name: 'doubleIt',
      enumerable: true,
      writable: false,
      type: 'method'
    }
  ],
  proto: null
}
```

## `metaToValue()` for a simple function

Back in the renderer, the above `meta` is received and sent to [`metaToValue()`](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/renderer/api/remote.js#L213) to be converted into something usable. Like `valueToMeta()`, this code is also lengthy due to all the types and special cases that it handles. And also like `valueToMeta()`, the control flow for `doubleIt()` is more straightforward. [This](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/renderer/api/remote.js#L110) is the main part:

```javascript=
const remoteMemberFunction = function (...args) {
  let command
  if (this && this.constructor === remoteMemberFunction) {
    command = 'ELECTRON_BROWSER_MEMBER_CONSTRUCTOR'
  } else {
    command = 'ELECTRON_BROWSER_MEMBER_CALL'
  }
  const ret = ipcRendererInternal.sendSync(command, contextId, metaId, member.name, wrapArgs(args))
  return metaToValue(ret)
}
```

So when this code runs in the renderer in our doubleIt example:

```javascript=
const { remote } = require('electron');
const main = remote.require('./main.js');
```

`main.doubleIt` is a `remoteMemberFunction`.

## Round Trip #2: `doubleIt()`

As seen in the above block, calling `main.doubleIt(2)` in the renderer process will send off an IPC message with the following arguments:

1. `ELECTRON_BROWSER_MEMBER_CALL`
2. `contextId`, an [internal](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/atom/renderer/renderer_client_base.cc#L115) string to uniquely identify the IPC caller's source [V8 context](https://v8.dev/docs/embed#contexts).
3. `metaId`, which comes from the `id` field of the `meta` that the main process returned during Round Trip #1. This is how the main process knows what function to call.
4. `member.name`
5. [`wrapArgs(args)`](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/renderer/api/remote.js#L28), which does what you'd expect to serialize function arguments for IPC. Here, the `args` being passed in is the `2` that we're doubling.

Over in the main process, the `handleRemoteCommand()` function we saw earlier [wraps](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/browser/rpc-server.js#L418) its `ELECTRON_BROWSER_MEMBER_CALL` handler:

```javascript=
handleRemoteCommand('ELECTRON_BROWSER_MEMBER_CALL', function (event, contextId, id, method, args) {
  args = unwrapArgs(event.sender, event.frameId, contextId, args)
  const obj = objectsRegistry.get(id)

  if (obj == null) {
    throwRPCError(`Cannot call function '${method}' on missing remote object ${id}`)
  }

  return callFunction(event, contextId, obj[method], obj, args)
})
```

metaId is a key for looking up objects in the `objectsRegistry`. We do that here to get a handle to the _real_ `doubleIt()` function.

[`callFunction()`](https://github.com/electron/electron/blob/3a091cdea46f7482d7fcf1be54f625e9a4989de5/lib/browser/rpc-server.js#L247) does what its name suggests. It has extra voodoo to handle async functions, but since `doubleIt()` is synchronous we can come back to that in the next discussion. The real `doubleIt()` is called and returns `4`. That `4` is converted into a meta by `valueToMeta()` and then sent back to the renderer:

```JSON=
{
  type: 'value',
  value: 4
}
```

When the renderer process gets this, the `ipcRendererInternal.sendSync()` command inside the `remoteMemberFunction` at `main.doubleIt` finally returns. The `meta` is deserialized with `metaToValue()` and -- finally -- `4` is returned to the code in `renderer.js`.

## Conclusion

In this article we walked through how Electron's `remote.require()` handles all the proxying and IPC necessary to proxy functions between the renderer and main processes. And even though all the function did was add `2 + 2`, you've learned how Electron manages memory across processes.

Since applications are rarely as direct as `2 + 2 === 4`, `remote.require()` also handles constructor functions, property accessors, async functions, promises, and much more. In part 2 we'll find out how Promise proxies are made and kept.
