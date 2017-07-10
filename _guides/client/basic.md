---
title: Getting Started with a Client
---

To start with, we'll just get a simple `GET` request to a webpage working,
so we can see all the moving parts. First, we need our dependencies. We need 
to tell Cargo our dependencies first, by having this in the Cargo.toml.

```toml
[dependencies]
hyper = "0.1"
futures = "0.1"
tokio-core = "0.1"
```

Now, we are ready to import the dependencies in our Rust file.
```rust
extern crate futures;
extern crate hyper;
extern crate tokio_core;
```

We need to import pieces to use from our dependencies:

```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
use std::io::{self, Write};
use futures::{Future, Stream};
use hyper::Client;
use tokio_core::reactor::Core;
# fn main() {}
```

Now, we'll make a request in the `main` of our program. This may seem
like a bit of work just to make a simple request, and you'd be correct,
but the point here is just to show all the setup required. Once you have this,
you are set to make thousands of client requests efficiently.

```rust
# extern crate hyper;
# extern crate tokio_core;
# use hyper::Client;
# use tokio_core::reactor::Core;
# fn run() -> Result<(), Box<::std::error::Error>> {
let mut core = Core::new()?;
let client = Client::new(&core.handle());
# Ok(())
# }
# fn main() {}
```

We have to create a `Core`, which is a Tokio event loop,
to drive our asynchronous request to completion. With a `Core`, we can then create
a hyper [`Client`][Client] that will be registered to our event loop.

```rust
# extern crate hyper;
# extern crate tokio_core;
# use hyper::Client;
# use tokio_core::reactor::Core;
# fn run() -> Result<(), Box<::std::error::Error>> {
# let mut core = Core::new()?;
# let client = Client::new(&core.handle());
let uri = "http://httpbin.org/ip".parse()?;
let work = client.get(uri);
# Ok(())
# }
# fn main() {}
```

Calling `client.get` returns a `Future` that will eventually be fulfilled with a
[`Response`][Response].

```rust
# extern crate hyper;
# extern crate futures;
# extern crate tokio_core;
# use futures::Future;
# use hyper::Client;
# use tokio_core::reactor::Core;
# fn run() -> Result<(), Box<::std::error::Error>> {
# let mut core = Core::new()?;
# let client = Client::new(&core.handle());
# let uri = "http://httpbin.org/ip".parse()?;
let work = client.get(uri).map(|res| {
    println!("Response: {}", res.status());
});
# Ok(())
# }
# fn main() {}
```

We chain on the success of that [`Future`][Future] using `map`,
and print out the [`StatusCode`][StatusCode] of the response. If it isn't on fire,
the server should have responded with a `200 OK` status.

The `map` combinator is useful when your next piece of work doesn't need to
return any more `Future`s. But what if we do?

```rust
# extern crate hyper;
# extern crate futures;
# extern crate tokio_core;
# use std::io::{self, Write};
# use futures::{Future, Stream};
# use hyper::Client;
# use tokio_core::reactor::Core;
# fn run() -> Result<(), Box<::std::error::Error>> {
# let mut core = Core::new()?;
# let client = Client::new(&core.handle());
# let uri = "http://httpbin.org/ip".parse()?;
let work = client.get(uri).and_then(|res| {
    println!("Response: {}", res.status());

    res.body().for_each(|chunk| {
        io::stdout()
            .write_all(&chunk)
            .map(|_| ())
            .map_err(From::from)
    })
});
# Ok(())
# }
# fn main() {}

```

We can use the `and_then` combinator instead, saying that after that `Future`
is ready, we plan to return a new `Future`.

Then, we access the body of the `Response`. The body is just a [`Stream`][Stream] of
chunks of data. A `Stream` will yield its items as they become available. In our case,
we want to write each chunk to the standard out, so we make use of the [`for_each`][ForEach]
combinator of `Stream`. The `for_each` combinator actually returns a `Future` that yields
success when every item of the `Stream` has been successfully processed. That means that
the `Future` returned from our `and_then` call will be fulfilled once the full response body
has been read and written to `stdout`.

If we just stopped there, we'd have a program that doesn't actually do anything. The last
line is **super** important. After all, futures are lazy, so the future in `work` won't
actually do anything until poked, repeatedly. We can tell our event loop (the `Core`) to
"run" the future in `work` until it succeeds or fails.

```rust
# extern crate hyper;
# extern crate tokio_core;
# use hyper::Client;
# use tokio_core::reactor::Core;
# fn run() -> Result<(), Box<::std::error::Error>> {
# let mut core = Core::new()?;
# let client = Client::new(&core.handle());
# let uri = "http://httpbin.org/ip".parse()?;
# let work = client.get(uri);
core.run(work)?;
# Ok(())
# }
# fn main() {}
```

Once that line has completed, all the work in the HTTP request and respose and chained
`and_then` has finished.

Here's the full example:

```rust
extern crate futures;
extern crate hyper;
extern crate tokio_core;

use std::io::{self, Write};
use futures::{Future, Stream};
use hyper::Client;
use tokio_core::reactor::Core;

# fn run() -> Result<(), Box<::std::error::Error>> {
# let mut core = Core::new()?;
# let client = Client::new(&core.handle());
# let uri = "http://httpbin.org/ip".parse()?;
# let work = client.get(uri);
let mut core = Core::new()?;
let client = Client::new(&core.handle());

let uri = "http://httpbin.org/ip".parse()?;
let work = client.get(uri).and_then(|res| {
    println!("Response: {}", res.status());

    res.body().for_each(|chunk| {
        io::stdout()
            .write_all(&chunk)
            .map_err(From::from)
    })
});
core.run(work)?;
# Ok(())
# }
# fn main() {}
```

And that's it!

[Client]: {{ site.docs_url }}/hyper/struct.Client.html
[StatusCode]: {{ site.docs_url }}/hyper/enum.StatusCode.html
[Response]: {{ site.docs_url }}/hyper/client/struct.Response.html
[Future]: {{ site.futures_url }}/futures/future/trait.Future.html
[Stream]: {{ site.futures_url }}/futures/stream/trait.Stream.html
[ForEach]: {{ site.futures_url }}/futures/stream/trait.Stream.html#method.for_each
