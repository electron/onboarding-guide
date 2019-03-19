# The Language Circus: From Native to JS in Electron

How do Electron's features written in C++ or Objective-C get to JavaScript so they're available to an end-user?

To trace this pathway, start with the [`app` module](https://electronjs.org/docs/api/app).

By opening the [`app.ts`](https://github.com/electron/electron/tree/master/lib/browser/api/app.ts) file inside our `lib/` directory, you'll find the following line of code towards the top:

```js
const binding = process.electronBinding('app')
```

This line points directly to Electron's mechanism for binding its C++/Objective-C modules to JavaScript for use by developers.

This function is created by the header and [implementation file](https://github.com/electron/electron/tree/master/atom/common/api/atom_bindings.cc) for the `ElectronBindings` class.

## `process.electronBinding`

These files add the `process.electronBinding` function, which behaves like Node.js’ `process.binding`. `process.binding` is a lower-level implementation of Node.js' [`require()`](https://nodejs.org/api/modules.html#modules_require_id) method, except it allows users to `require` native code instead of other code written in JS. This custom `process.electronBinding` function confers the ability to load native code from Electron.

When a top-level JavaScript module (like `app`) requires this native code, how is the state of that native code determined and set? Where are the methods exposed up to JavaScript? What about the properties?

## `native_mate`

Answers to this question can be found in `native_mate`:  a fork of Chromium's [`gin` library](https://chromium.googlesource.com/chromium/src.git/+/lkgr/gin/) that makes it easier to marshal types between C++ and JavaScript.

Inside `native_mate/native_mate` there's a header and implementation file for `object_template_builder`. This is what allow us to form modules in native code whose shape conforms to what JavaScript developers would expect.

### `mate::ObjectTemplateBuilder`

By considering every module in Electron to be an object, the mechanism behind using an object template creator becomes clearer. V8 implements the JavaScript (ECMAScript) specification, so its native functionality implementations can be directly correlated to implementations in JavaScript. For example, [`v8::ObjectTemplate`](https://v8docs.nodesource.com/node-0.8/db/d5f/classv8_1_1_object_template.html) gives us JavaScript objects without a dedicated constructor function and prototype. It uses `Object[.prototype]`, and in JavaScript would be equivalent to [`Object.create()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/create).

To see this in action, look to the implementation file for the app module: [`atom_api_app.cc`](https://github.com/electron/electron/tree/master/atom/browser/api/atom_api_app.cc) At the bottom is the following:

```cpp
mate::ObjectTemplateBuilder(isolate, prototype->PrototypeTemplate())
    .SetMethod("getGPUInfo", &App::GetGPUInfo)
```

In the above line, `.SetMethod` is called on `mate::ObjectTemplateBuilder`. `.SetMethod` can be called on any instances of the `ObjectTemplateBuilder` class to set methods on the [Object prototype](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/prototype) in JavaScript, with the following syntax:

```cpp
.SetMethod("method_name", &function_to_bind)
```

This is the JavaScript equivalent of:

```js
app.prototype.getGPUInfo = function () {
  // implementation here
}
```

This class also contains functions to set properties on a module:

```cpp
.SetProperty("property_name", &getter_function_to_bind)
```

or

```cpp
.SetProperty("property_name", &getter_function_to_bind, &setter_function_to_bind)
```

These would in turn be the JavaScript implementations of [Object.defineProperty](https://developer.mozilla.org/en/docs/Web/JavaScript/Reference/Global_Objects/Object/defineProperty):

```js
Object.defineProperty(app, 'myProperty', {
  get() {
    return _myProperty
  }
})
```

and

```js
Object.defineProperty(app, 'myProperty', {
  get() {
    return _myProperty
  }
  set(newPropertyValue) {
    _myProperty = newPropertyValue
  }
})
```

With this, it’s possible to create JavaScript objects formed with prototypes and properties as developers expect them, and more clearly reason about functions and properties implemented at this lower system level.
