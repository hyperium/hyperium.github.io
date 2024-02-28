---
title:  Runtime
layout: guide
permalink: /guides/1/init/runtime/
---

With hyper v1.0 removing `tokio` as runtime dependency, a new runtime trait `hyper::rt` is introduced. If you still want to use `tokio`, a `tokio` implementation for `hyper::rt` is provided by `hyper-util` crate.

## Building your own `hyper::rt` implementations with `Tokio`

Let's build a simple `hyper::rt` implementations with the help of tokio. First, make sure you have `tokio` as a dependency in your `Cargo.toml`:

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
```

Now, let's try to write a simple executor `hyper::rt::Executor`, we'll call it `TokioExecutor`:

```rust
# extern crate hyper;
/// Future executor that utilises `tokio` threads.
#[non_exhaustive]
#[derive(Default, Debug, Clone)]
pub struct TokioExecutor {}
```

the trait `hyper::rt::Executor` expects an `execute` method that asks the runtime to execute futures. `tokio` allows this easily with `tokio::spawn`

```rust
# extern crate hyper;
# extern crate tokio;

use std::future::Future;

use hyper::rt::Executor;

# #[non_exhaustive]
# #[derive(Default, Debug, Clone)]
# pub struct TokioExecutor {}

impl<Fut> Executor<Fut> for TokioExecutor
where
    Fut: Future + Send + 'static,
    Fut::Output: Send + 'static,
{
    fn execute(&self, fut: Fut) {
        tokio::spawn(fut);
    }
}
```

We now have a working `hyper::rt::Executor` with Tokio, and is ready to be supplied to anything that requires `Executor`. For example, with the auto connection from hyper-util:

```rust
# extern crate hyper;
# extern crate hyper_util;
# extern crate tokio;

use std::future::Future;

use hyper_util::server::conn::auto;
use hyper::rt::Executor;

# #[non_exhaustive]
# #[derive(Default, Debug, Clone)]
# pub struct TokioExecutor {}

# impl<Fut> Executor<Fut> for TokioExecutor
# where
#     Fut: Future + Send + 'static,
#     Fut::Output: Send + 'static,
# {
#     fn execute(&self, fut: Fut) {
#         tokio::spawn(fut);
#     }
# }

impl TokioExecutor {
    pub fn new() -> Self {
        Self {}
    }
}

auto::Builder::new(TokioExecutor::new());
```

## Using `hyper::rt` implementations with tokio in hyper-util

The crate `hyper-util` provides implementations for `hyper::rt` traits with Tokio. To use, we'll need to have `hyper-util` as a dependency.

```toml
[dependencies]
hyper-util = { version = "0.1", features = ["full"] }
```

Then you'll simply need to import and use it as in the example above

```rust
# extern crate hyper;
# extern crate hyper_util;

use hyper::rt::Executor;
use hyper_util::rt::TokioExecutor;
use hyper_util::server::conn::auto;

auto::Builder::new(TokioExecutor::new());
```

There are more implementations in the hyper_util crate. Check out the docs on [`hyper_util::rt`][] for more details.

[`hyper_util::rt`]: https://docs.rs/hyper-util/latest/hyper_util/rt/index.html
