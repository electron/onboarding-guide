# Blink

Blink is a rendering engine of the web platform, which can be found in Chromium's source code under `//third_party/blink`. Roughly speaking, Blink implements everything that renders content inside a browser tab:

* Implement the specs of the web platform (e.g., HTML standard), including DOM, CSS and Web IDL
* Embed V8 and run JavaScript
* Request resources from the underlying network stack
* Build DOM trees
* Calculate style and layout
* Embed Chrome Compositor and draw graphics

[How Blink Works](https://docs.google.com/document/d/1aitSOucL0VHZa9Z2vbRJSyAIsAz24kX8LFByQ5xQnUg) is a high-level overview doc explaining what it does and how.

[Content public APIs](https://cs.chromium.org/chromium/src/content/public/) are the API layer that enables embedders to embed the rendering engine. Content public APIs must be carefully maintained because they are exposed to embedders (that's us!).
* Also see this [Content API](https://www.chromium.org/developers/content-module/content-api) document.

[Blink public APIs](https://cs.chromium.org/chromium/src/third_party/blink/public/?q=blink/public&sq=package:chromium&dr) are the API layer that exposes functionalities from //third_party/blink/ to Chromium. This API layer is just historical artifact inherited from WebKit. In the WebKit era, Chromium and Safari shared the implementation of WebKit, so the API layer was needed to expose functionalities from WebKit to Chromium and Safari. Now that Chromium is the only embedder of //third_party/blink/, the API layer does not make sense. Chromium is actively decreasing the number of Blink public APIs by moving web-platform code from Chromium to Blink (the project is called Onion Soup).