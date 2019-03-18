# The Language Circus: From Native to JS in Electron

## Background

At its core, Electron doesn't remove the need for platform-specific functionality to be written in a given system language.

In reality, it obfuscates the system languages away from you so that you, a developer, can focus on a single simplified API surface area in JavaScript.

How does that work, though? How does something implemented in Objective-C (for mac-specific functionality) or C++ get to JavaScript so it's available to an end-user through our API?

To trace this pathway, start with the [`app` module](https://electronjs.org/docs/api/app).

By opening the `app.ts` file inside our `lib/` directory, you'll find the following line of code towards the top:

```js
const binding = process.electronBinding('app')
```

This line points towards the mechanism behind how native module methods are bound to a JavaScript prototype and exposed to the end-user.

[gif here]

This function is created by the header and [implementation file](https://github.com/electron/electron/tree/master/atom/common/api/atom_bindings.cc) for the `ElectronBindings` class, created to address this problem. 


### `process.electronBinding`

These files add the `process.electronBinding` function, which behaves like `process.binding`. `process.binding` functions as `require` does within JS, except that it allow users to `require` native code instead of other code written in JS. This custom `process.electronBinding` function confers the ability to load native code from Electron instead.

When a top-level JavaScript module (like `app`) requires this native code, though, how does that module know what shape it's in? Where are the methods exposed up to JavaScript, and how? What about the properties?

### `native_mate`

Answers to this question can be found in `native_mate`:  a fork of Chromium's [`gin` library](https://chromium.googlesource.com/chromium/src.git/+/lkgr/gin/) that makes it easier to marshal types between C++ and JavaScript.

Inside `native_mate/native_mate` there's a header and implementation file for `object_template_builder`. This is what allow us to form modules in native code whose shape conforms to what JavaScript developers would expect.

### `mate::ObjectTemplateBuilder`

This class (taken from `gin`) is a handy utility for creation of [`v8::ObjectTemplate`](https://v8docs.nodesource.com/node-0.8/db/d5f/classv8_1_1_object_template.html), which is used to create objects at runtime.

Let's migrate to the implementation file for the app module, which we find at [`atom_api_app.cc`](https://github.com/electron/electron/tree/master/atom/browser/api/atom_api_app.cc) At the bottom we'll find code like the following:

```js
  mate::ObjectTemplateBuilder(isolate, prototype->PrototypeTemplate())
    .SetMethod("getGPUInfo", &App::GetGPUInfo)
```

In the above line, `.SetMethod` is called on `mate::ObjectTemplateBuilder`. `.SetMethod` can be called on any instances of the `ObjectTemplateBuilder` class to set methods in JavaScript, with the following syntax:

```js
  .SetMethod("method_name", &function_to_bind)
```

This class also contains functions to set properties on a module:

```js
  .SetProperty("property_name", &getter_function_to_bind)
```

or

```js
  .SetProperty("property_name", &getter_function_to_bind, &setter_function_to_bind)
```

An example of the latter can be found in [`atom_api_notification.cc`](https://github.com/electron/electron/tree/master/atom/browser/api/atom_api_notification.cc) (native implementation for the [`notification` module](https://electronjs.org/docs/api/notification)). Towards the bottom see:

```js
void Notification::BuildPrototype(v8::Isolate* isolate,
                                  v8::Local<v8::FunctionTemplate> prototype) {
  prototype->SetClassName(mate::StringToV8(isolate, "Notification"));
  mate::ObjectTemplateBuilder(isolate, prototype->PrototypeTemplate())
      .MakeDestroyable()
      .SetMethod("show", &Notification::Show)
      .SetMethod("close", &Notification::Close)
      .SetProperty("title", &Notification::GetTitle, &Notification::SetTitle)
...
```
