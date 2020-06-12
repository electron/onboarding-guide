# Electron

Electron is primarily comprised of three languages for its externally-facing functionality: JavaScript, C++, and Objective-C. At its core, Electron doesn't remove the need for platform-specific functionality to be written in a given system languages, it just obfuscates the system languages away from you so that you, a developer, to focus on a single simplified API surface area in JavaScript.

## Getting Around the Source Code

```diff
Electron
├── build/ - Build configuration files needed to build with GN.
├── buildflags/ - Determines the set of features that can be conditionally built.
├── chromium_src/ - Source code copied from Chromium that isn't part of the content layer.
├── default_app/ - A default app run when Electron is started without
|                  providing a consumer app.
├── docs/ - Electron's documentation.
|   ├── api/ - Documentation for Electron's externally-facing modules and APIs.
|   ├── development/ - Documentation to aid in developing for and with Electron.
|   ├── fiddles/ - A set of code snippets one can run in Electron Fiddle.
|   ├── images/ - Images used in documentation.
|   └── tutorial/ - Tutorial documents for various aspects of Electron.
├── lib/ - JavaScript/TypeScript source code.
|   ├── browser/ - Main process initialization code.
|   |   ├── api/ - API implementation for main process modules.
|   |   └── remote/ - Code related to the remote module as it is 
|   |                 used in the main process.
|   ├── common/ - Relating to logic needed by both main and renderer processes.
|   |   └── api/ - API implementation for modules that can be used in
|   |              both the main and renderer processes
|   ├── isolated_renderer/ - Handles creation of isolated renderer processes when
|   |                        contextIsolation is enabled.
|   ├── renderer/ - Renderer process initialization code.
|   |   ├── api/ - API implementation for renderer process modules.
|   |   ├── extension/ - Code related to use of Chrome Extensions
|   |   |                in Electron's renderer process.
|   |   ├── remote/ - Logic that handes use of the remote module in
|   |   |             the main process. 
|   |   └── web-view/ - Logic that handles the use of webviews in the
|   |                   renderer process.
|   ├── sandboxed_renderer/ - Logic that handles creation of sandboxed renderer
|   |   |                     processes.
|   |   └── api/ - API implementation for sandboxed renderer processes.
|   └── worker/ - Logic that handles proper functionality of Node.js
|                 environments in Web Workers.
├── patches/ - Patches applied on top of Electron's core dependencies
|   |          in order to handle differences between our use cases and
|   |          default functionality.
|   ├── boringssl/ - Patches applied to Google's fork of OpenSSL, BoringSSL.
|   ├── chromium/ - Patches applied to Chromium.
|   ├── node/ - Patches applied on top of Node.js.
|   └── v8/ - Patches applied on top of Google's V8 engine.
├── shell/ - C++ source code.
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
├── spec/ - Components of Electron's test suite run in the renderer process.
├── spec-main/ - Components of Electron's test suite run in the main process.
└── BUILD.gn - Building rules of Electron.
```

Any given module is either a **browser** module (meaning it runs in the main process only), a **renderer** module (renderer process only), or a **common** module, meaning it can run in both the browser and renderer processes.

`lib/` and `shell/` generally mirror each other in directory structure, and are where the modules themselves are implemented. By knowing what type a module is, you can use this knowledge to find out where it lives.

## Other Important Directories

* **.circleci** - Config file for CI with CircleCI.
* **.github** - GitHub-specific config files including issues templates and CODEOWNERS.
* **dist** - Temporary directory created by `script/create-dist.py` script
  when creating a distribution.
* **external_binaries** - Downloaded binaries of third-party frameworks which
  do not support building with `gn`.
* **node_modules** - Third party node modules used for building.
* **npm** - Logic for installation of Electron via npm.
* **out** - Temporary output directory of `ninja`.
* **script** - Scripts used for development purpose like building, packaging,
  testing, etc.
```diff
script/ - The set of all scripts Electron runs for a variety of purposes.
├── codesign/ - Fakes codesigning for Electron apps; used for testing.
├── lib/ - Miscellaneous python utility scripts.
└── release/ - Scripts run during Electron's release process.
    ├── notes/ - Generates release notes for new Electron versions.
    └── uploaders/ - Uploads various release-related files during release.
```
* **tools** - Helper scripts used by GN files.
  * Scripts put here should never be invoked by users directly, unlike those in `script`.
* **typings** - TypeScript typings for Electron's internal code.
* **vendor** - Source code for some third party dependencies, including `boto` and `requests`.

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

**Nota Bene:** A bunch of stuff in our source code is prefixed with `atom_` because Electron [used to be called `atom-shell`](https://electronjs.org/blog/electron).

## Versioning

Starting with Electron `v2.0.0`, we use Node's [semantic versioning](https://docs.npmjs.com/about-semantic-versioning) for its releases. 
 * Each new "breaking change" -- such as a new version of Node or Chromium or V8 -- is treated as a **major** change and so that release would get a new major version number, e.g. bumping from `6.0.0` to `7.0.0`.
 * New non-breaking features are **minor** changes, e.g. bumping from `v6.0.0` to `v6.1.0`.
 * A release that contains only bugfixes is a **patch** change, e.g. bumping from `v6.0.0` to `v6.0.1`.

Our production / stabilization branches follow this naming scheme. For example, the branchname for the version of Electron released as `8.0.1` is [8-x-y](https://github.com/electron/electron/tree/8-x-y).

For branches older than v8, each minor version had it's own branch, a la `7-1-x` and `7-0-x`.

Further reading: [blog post](https://electronjs.org/blog/electron-2-semantic-boogaloo), [documentation](https://electronjs.org/docs/tutorial/electron-versioning)
