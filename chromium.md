## Chromium

Electron depends on Chromium, an open source initiative developed by Google that powers Google Chrome. Different parts of Electron hook into existing classes and functions in Chromium, and we use many of their helpers as well as follow a significant number of their development patterns. I've included a primer to some different aspects of Chromium that will hlp you become familiar with them as they pop up in different parts of the Electron codebase.

[Chromium University](https://www.chromium.org/developers/tech-talk-videos)
   * a series of videos discussing various aspct of Chromium's design philosophy and overarching architecture

[Chromium Development Calendar](https://chromiumdash.appspot.com/schedule)
   * Chromium has a very predicatable release schedule around when they cut and release each successive canary, beta, and stable version
   * See [release cycle](https://chromium.googlesource.com/chromium/src/+/master/docs/process/release_cycle.md) for more information

Chromium and Electron both use what's known as [Multi-Process Architecture](https://www.chromium.org/developers/design-documents/multi-process-architecture). You'll want to be familiar with this, as it determines a lot of the way code is written in Electron.

### [Getting Around The Source Code](https://www.chromium.org/developers/how-tos/getting-around-the-chrome-source-code)

These are the top-level projects in Chromium's source.

* `android_webview`: Provides a facade over src/content suitable for integration into the android platform. NOT intended for usage in * individual android applications (APK). More information about the Android WebView source code organization.
* `apps`: Chrome packaged apps.
* `base`: Common code shared between all sub-projects. This contains things like string manipulation, generic utilities, etc. Add things here only if it must be shared between more than one other top-level project. 
* `breakpad`: Google's open source crash reporting project. This is pulled directly from Google Code's Subversion repository.
* `build`: Build-related configuration shared by all projects.
* `cc`: The Chromium compositor implementation.
* `chrome`: The Chromium browser (see below).
* `chrome/test/data`: Data files for running certain tests.
* `components`:  directory for components that have the Content Module as the uppermost layer they depend on.
* `content`: The core code needed for a multi-process sandboxed browser (see below). More information about why we have separated out this code.
* `device`: Cross-platform abstractions of common low-level hardware APIs.
* `net`: The networking library developed for Chromium. This can be used separately from Chromium when running our simple test_shell in the webkit repository. See also chrome/common/net.
* `sandbox`: The sandbox project which tries to prevent a hacked renderer from modifying the system.
* `skia + third_party/skia`: Google's Skia graphics library. Our additional classes in ui/gfx wrap Skia.
* `sql`: Our wrap around sqlite.
* `testing`: Contains Google's open-sourced GTest code which we use for unit testing.
* `third_party`: 200+ small and large "external" libraries such as image decoders, compression libraries and the web engine Blink (here because it inherits license limitations from WebKit). Adding new packages.
* `.../blink/renderer`: The web engine responsible for turning HTML, CSS and scripts into paint commands and other state changes. 
tools
* `ui/gfx`: Shared graphics classes. These form the base of Chromium's UI graphics.
* `ui/views`: A simple framework for doing UI development, providing rendering, layout and event handling. Most of the browser UI is implemented in this system. This directory contains the base objects. Some more browser-specific objects are in chrome/browser/ui/views.
* `url`: Google's open source URL parsing and canonicalization library.
* `v8:` The V8 Javascript library. This is pulled directly from Google Code's Subversion repository.

**NOTA BENE:** In particular, we care about `base`, `content`, `net`, `third_party`, and `v8` (see [v8](v8.md) for more!).

### Blink

Blink is a rendering engine of the web platform, which can be found in Chromium's source code under `//third_party/blink`. Roughly speaking, Blink implements everything that renders content inside a browser tab:
* Implement the specs of the web platform (e.g., HTML standard), including DOM, CSS and Web IDL
* Embed V8 and run JavaScript
* Request resources from the underlying network stack
* Build DOM trees
* Calculate style and layout
* Embed Chrome Compositor and draw graphics

[How Blink Works](https://docs.google.com/document/d/1aitSOucL0VHZa9Z2vbRJSyAIsAz24kX8LFByQ5xQnUg) is a high-level overview doc explaining what it does and how.

[Content public APIs](https://cs.chromium.org/chromium/src/content/public/) are the API layer that enables embedders to embed the rendering engine. Content public APIs must be carefully maintained because they are exposed to embedders (that's us!).

[Blink public APIs](https://cs.chromium.org/chromium/src/third_party/blink/public/?q=blink/public&sq=package:chromium&dr) are the API layer that exposes functionalities from //third_party/blink/ to Chromium. This API layer is just historical artifact inherited from WebKit. In the WebKit era, Chromium and Safari shared the implementation of WebKit, so the API layer was needed to expose functionalities from WebKit to Chromium and Safari. Now that Chromium is the only embedder of //third_party/blink/, the API layer does not make sense. We're actively decreasing # of Blink public APIs by moving web-platform code from Chromium to Blink (the project is called Onion Soup).

### Development Patterns

* [`base::Optional`](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/optional.md)
* [`Callback<> and Bind()`](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/callback.md)