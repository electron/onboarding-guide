# From Native to JS

How does something implemented in Objective-C or C++ get to JavaScript so it can be used by an end-user through our API?

If we look at a given module in the `lib/` folder, let's say `app.ts`, we'll see the following line of code:

```js
const bindings = process.atomBinding('app')
```

This line is our first clue to how we get access to the methods we implemented in native code for the app module. In that line above was `atomBinding`, so our next step is to go find out more about what that is and how it enables this access.

We find it in `atom/common/api/atom_binding`. These files add the `process.atomBinding` function, which behaves like `process.linkedBinding` but load native code from Electron instead. `process.linkedBinding` functions essentially as `require` does within JS, except that it allow for us to `require` native code instead of other code written in JS.

Not quite done yet, though. When we require this native code, how do we know what shape it's in? Where do we set the methods that we're exposing up to JavaScript? What about the properties?

For this, we turn to `native_mate`. `native_mate` is a fork of Chromium's `gin` library (see [../chromium/overview.md] for more) that makes it easier to marshal type between C++ and JavaScript. Inside `native_mate/native_mate` we can find a header and implementation file for `object_template_builder`, which is what allow us to form modules in native code whose shape conforms to what we'd expect them to look like. `object_template_builder` is a handy utility for creation of [`v8::ObjectTemplate`](https://v8docs.nodesource.com/node-0.8/db/d5f/classv8_1_1_object_template.html).

Let's go to `atom/api/browser/atom_api_app.cc` for a second. At the bottom we'll find code like the following:

```js
  mate::ObjectTemplateBuilder(isolate, prototype->PrototypeTemplate())
    .SetMethod("getGPUInfo", &App::GetGPUInfo)
```

We see `.SetMethod` being called on `mate::ObjectTemplateBuilder`. We can call this on instances of the `ObjectTemplateBuilder` to set methods in JavaScript, with the following syntax:

```js
  .SetMethod("method_name", &function_to_bind)
```

This class also contains functions to allow us to set properties on a module:

```js
  .SetProperty("property_name", &getter_function_to_bind)
```

or

```js
  .SetProperty("property_name", &getter_function_to_bind, &setter_function_to_bind)
```

For an example of the latter, we can turn to `atom_api_notification.cc` (native implementation for the notification module) and at the bottom see:

```js
void Notification::BuildPrototype(v8::Isolate* isolate,
                                  v8::Local<v8::FunctionTemplate> prototype) {
  prototype->SetClassName(mate::StringToV8(isolate, "Notification"));
  mate::ObjectTemplateBuilder(isolate, prototype->PrototypeTemplate())
      .MakeDestroyable()
      .SetMethod("show", &Notification::Show)
      .SetMethod("close", &Notification::Close)
      .SetProperty("title", &Notification::GetTitle, &Notification::SetTitle)
      .SetProperty("subtitle", &Notification::GetSubtitle,
                   &Notification::SetSubtitle)
      .SetProperty("body", &Notification::GetBody, &Notification::SetBody)
      .SetProperty("silent", &Notification::GetSilent, &Notification::SetSilent)
      .SetProperty("hasReply", &Notification::GetHasReply,
                   &Notification::SetHasReply)
      .SetProperty("replyPlaceholder", &Notification::GetReplyPlaceholder,
                   &Notification::SetReplyPlaceholder)
      .SetProperty("sound", &Notification::GetSound, &Notification::SetSound)
      .SetProperty("actions", &Notification::GetActions,
                   &Notification::SetActions)
      .SetProperty("closeButtonText", &Notification::GetCloseButtonText,
                   &Notification::SetCloseButtonText);
}
```