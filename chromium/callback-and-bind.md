# `Callback<>` and `Bind()`

[Chromium README](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/callback.md)

## Overview

`base::Callback` is a set of internally refcounted templated callback classes with different arities (number of arguments or operands that the function takes) and return values (including `void`). `base::Bind()` will bind arguments to a function pointer and returns a `base::Callback`. These provide a method for type-safe partial application of functions.

### Partial Application

Partial application (or “currying”) is the process of binding a subset of a function's arguments to produce another function that takes fewer arguments. This can be used to pass around a unit of delayed execution, much like lexical closures are used in other languages.

### `OnceCallback<>` & `RepeatingCallback<>`

`base::OnceCallback<>` and `base::RepeatingCallback<>` are callback classes.

`base::OnceCallback<>` is created by `base::BindOnce()`. This is a callback variant that is a move-only type and can be run only once. This moves out bound parameters from its internal storage to the bound function by default, so it‘s easier to use with movable types. This should be the preferred callback type: since the lifetime of the callback is clear, it’s simpler to reason about when a callback that is passed between threads is destroyed.

`base::RepeatingCallback<>` is created by `base::BindRepeating()`. This is a callback variant that is copyable that can be run multiple times. It uses internal ref-counting to make copies cheap. However, since ownership is shared, it is harder to reason about when the callback and the bound state are destroyed, especially when the callback is passed between threads.

`base::RepeatingCallback<>` is convertible to `base::OnceCallback<>` by the implicit conversion.

### Helper Wrappers for Arguments to `base::Bind()`

* `base::Unretained()` - disables the refcounting of member function receiver objects (which may not be of refcounted types) and the COMPILE_ASSERT on function arguments.
  * Implies you need to make sure the lifetime of the object lasts beyond when the callback can be invoked.
* `base::Owned()` - transfer ownership of a raw pointer to the returned `base::Callback` storage.
* `base::Passed()` - useful for passing a scoped object to a callback.    * The primary difference between `base::Owned()` and `base::Passed()` 
  is `base::Passed()` requires the function signature take the scoped type as a parameter, and thus allows for transferring ownership via `.release()`.
  * NOTE: since the scope of the scoped type is the function scope, that means the `base::Callback `must only be called once. Otherwise, it would be a potential use after free and a definite double delete. * Prefer base::Owned() to base::Passed() in general
* `base::ConstRef()` - passes an argument as a const reference instead of copying it into the internal callback storage. 
  * Generally should not be used, since it requires that the lifetime of the referent must live beyond when the callback can be invoked.
* `base::IgnoreResult()` - use this with the function pointer passed to `base::Bind()` to ignore the result
  * Useful to make the callback usable with a TaskRunner (see [TaskRunner](taskrunner.md)) which only takes `Closures` (callbacks with no parameters nor return values).

### Memory Management and Passing

Pass `base::Callback` objects by value if ownership is transferred; otherwise, pass it by const-reference. When you pass a `base::Callback` object to a function parameter, use `std::move()` if you don‘t need to keep a reference to it, otherwise, pass the object directly.

```cpp
// |Foo| just refers to |cb| but doesn't store it nor consume it.
bool Foo(const base::OnceCallback<void(int)>& cb) {
  return cb.is_null();
}

// |Bar| takes the ownership of |cb| and stores |cb| into |g_cb|.
base::OnceCallback<void(int)> g_cb;
void Bar(base::OnceCallback<void(int)> cb) {
  g_cb = std::move(cb);
}

// |Baz| takes the ownership of |cb| and consumes |cb| by Run().
void Baz(base::OnceCallback<void(int)> cb) {
  std::move(cb).Run(42);
}
```

### Some Generalized Examples

1. **Binding A Bare Function**

```cpp
int Return5() { return 5; }
base::OnceCallback<int()> func_cb = base::BindOnce(&Return5);
LOG(INFO) << std::move(func_cb).Run();  // Prints 5.
```

```cpp
int Return5() { return 5; }
base::RepeatingCallback<int()> func_cb = base::BindRepeating(&Return5);
LOG(INFO) << func_cb.Run();  // Prints 5.
```

2. **Binding a Class Method**

The first argument to bind is the member function to call, the second is the object on which to call it.

```cpp
class Ref : public base::RefCountedThreadSafe<Ref> {
 public:
  int Foo() { return 3; }
};
scoped_refptr<Ref> ref = new Ref();
base::Callback<void()> ref_cb = base::Bind(&Ref::Foo, ref);
LOG(INFO) << ref_cb.Run();  // Prints out 3.
```

3. **Running a Callback**

Callbacks can be run with their `Run` method, which has the same signature as the template argument to the callback. Note that `base::OnceCallback::Run` consumes the callback object and can only be invoked on a callback rvalue.

```cpp
void DoAThing(const base::Callback<void(int, std::string)>& callback) {
  callback.Run(5, "hello");
}

void DoAnotherThing(base::OnceCallback<void(int, std::string)> callback) {
  std::move(callback).Run(5, "hello");
}
```

`RepeatingCallbacks` can be run more than once (they don't get deleted or marked when run).

```cpp
void DoSomething(const base::RepeatingCallback<double(double)>& callback) {
  double myresult = callback.Run(3.14159);
  myresult += callback.Run(2.71828);
}
```

### Examples in the Electron Codebase

[Example 1](https://github.com/electron/electron/blob/master/atom/browser/api/atom_api_menu_mac.mm#L61) - In this example, we bind arguments to `MenuMac::OnClosed`, which is called when menus are closed on MacOS.
* We use `base::Bind`, which creates a `RepeatingCallback`
  * We don't just want the callback we pass to be run once, as people are likely to want to open and close a menu many times!
