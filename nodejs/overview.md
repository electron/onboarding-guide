# Node.js

Electron depends on Node.js to allow consumers access to filesystem and networking capabilities, amongst other things. It is available to all consumers by default in Electron's main process, and can be conditionally enabled in renderer processes via `nodeIntegration`, a boolean flag passed to new renderer processes.

We try our best to use the stock version of Node.js that's bundled with a given version of Electron, but sometimes we can't provide users with the capabilities they need without patching certain aspects of Node.js to expose those capabilities and fit our use cases. As a result, we maintain a set of patches for Node.js, each of which can be found in Electron's source tree under `patches/node`.

Node.js' source code is backed by C++ in a similar manner to Electron, and so we hook into various aspects of it in order to most effective embed it into Electron itself. More information about the use of C++ in Node.js can be found [here](https://github.com/nodejs/node/blob/master/src/README.md).
