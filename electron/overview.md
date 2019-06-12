# Electron

Electron is primarily comprised of three languages for its externally-facing functionality: JavaScript, C++, and Objective-C. At its core, Electron doesn't remove the need for platform-specific functionality to be written in a given system languages, it just obfuscates the system languages away from you so that you, a developer, to focus on a single simplified API surface area in JavaScript.

## Getting Around the Source Code

```diff
Electron
├── atom/ - C++ source code.
|   ├── app/ - System entry code.
|   ├── browser/ - The frontend including the main window, UI, and all of the
|   |   |          main process things. This talks to the renderer to manage web
|   |   |          pages.
|   |   ├── ui/ - Implementation of UI stuff for different platforms.
|   |   |   ├── cocoa/ - Cocoa specific source code.
|   |   |   ├── win/ - Windows GUI specific source code.
|   |   |   └── x/ - X11 specific source code.
|   |   ├── api/ - The implementation of the main process APIs.
|   |   ├── net/ - Network related code.
|   |   ├── mac/ - Mac specific Objective-C source code.
|   |   └── resources/ - Icons, platform-dependent files, etc.
|   ├── renderer/ - Code that runs in renderer process.
|   |   └── api/ - The implementation of renderer process APIs.
|   └── common/ - Code that used by both the main and renderer processes,
|       |         including some utility functions and code to integrate node's
|       |         message loop into Chromium's message loop.
|       └── api/ - The implementation of common APIs, and foundations of
|                  Electron's built-in modules.
├── chromium_src/ - Source code copied from Chromium. See below.
├── default_app/ - The default page to show when Electron is started without providing an app.
├── docs/ - Documentations.
├── lib/ - JavaScript source code.
|   ├── browser/ - Javascript main process initialization code.
|   |   └── api/ - Javascript API implementation.
|   ├── common/ - JavaScript used by both the main and renderer processes
|   |   └── api/ - Javascript API implementation.
|   └── renderer/ - Javascript renderer process initialization code.
|       └── api/ - Javascript API implementation.
├── native_mate/ - A fork of Chromium's gin library that makes it easier to marshal
|                  types between C++ and JavaScript.
├── spec/ - Automatic tests.
└── BUILD.gn - Building rules of Electron.
```

Any given module is either a **browser** module (meaning it runs in the main process only), a **renderer** module (renderer process only), or a **common** module, meaning it can run in both the browser and renderer processes.

`lib/` and `atom/` generally mirror each other in directory structure, and are where the modules themselves are implemented. By knowing what type a module is, you can use this knowledge to find out where it lives.

### Example: the `Dialog` module

* This is a **main** process module, so we can expect that if we navigate to `lib/browser/api` that it will exist there as a top-level js file (`dialog.js`).
  * We also know from this that we can find its native implementation api files inside `atom/browser/api`!
  * Dialogs are specific to platforms, though, so we'll need to also fall down from `atom_api_dialog.[h|cc]` into more specific file dialog implementations.
    * For this, we wander into `atom/browser/ui` where we see specific implementations for MacOS, Windows, and Linux (GTK).

A hierarchy chart is shown below. Any given module is implemented along the spectrum from JavaScript to C++ to Objective-C, depending on the needs of that specific module and the way that it connects to Chromium. Sometimes whole methods will exist entirely in JS, sometimes they'll be sanitized or otherwise manipulated in JS and then passed to native implementations, and sometimes they'll be entirely native.

```ascii
+-------------------------------------------------------------------------+
|                                                                         |
|                            +---------------+                            |
|                            |   dialog.js   |                            |
|                            +---------------+                            |
|                                    |                                    |
|                                    |                                    |
|                       +------------------------+                        |
|                       | atom_api_dialog.[h|cc] |                        |
|                       +------------+-----------+                        |
|                        /           |           \                        |
|                       /            |            \                       |
|                      /             |             \                      |
|                     /              |              \                     |
|  +--------------------+ +----------+---------+  +--------------------+  |
|  | file_dialog_gtk.cc | | file_dialog_win.cc |  | file_dialog_mac.mm |  |
|  +--------------------+ +--------------------+  +--------------------+  |
|                                                                         |
+-------------------------------------------------------------------------+
```

**Nota Bene:** A bunch of stuff in our source code is inside the `atom/` folder and prefixed with `atom_` because Electron [used to be called `atom-shell`](https://electronjs.org/blog/electron).

## Versioning

Starting with Electron 2.0.0, we use Node's [semantic versioning](https://docs.npmjs.com/about-semantic-versioning) for its releases. 
 * Each new "breaking change" -- such as a new version of Node or Chromium or V8 -- is treated as a **major** change and so that release would get a new major version number, e.g. bumping from 6.0.0 to 7.0.0.
 * New non-breaking features are **minor** changes, e.g. bumping from 6.0.0 to 6.1.0.
 * A release that contains only bugfixes is a **patch** change, e.g. bumping from 6.0.0 to 6.0.1.

Our production / stabilization branches follow this naming scheme. For example, the branchname for 6.0.x is [6-0-x](https://github.com/electron/electron/tree/6-0-x).

Futher reading: [blog post](https://electronjs.org/blog/electron-2-semantic-boogaloo), [documentation](https://electronjs.org/docs/tutorial/electron-versioning)
