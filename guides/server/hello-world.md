---
title:  Getting Started with a Server
layout: guide
---

Let's start by making a "Hello, World!" server, and expand from there.

First, some imports in our `main.rs`:

```rust
extern crate hyper;
extern crate futures;
```

We also need to `use` a few things:

```rust
# extern crate hyper;
use hyper::header::ContentLength;
use hyper::server::{Http, Request, Response, Service};
# fn main() {}
```

## Creating a Service

A [`Service`][service] is how you define how to serve incoming requests
with outgoing responses. Let's define a simple one, naming it after what
we expect our service to do.

```rust
struct HelloWorld;
```

Next, we need to implement [`Service`][service] for `HelloWorld`:

```rust
# extern crate futures;
# extern crate hyper;
# use hyper::header::ContentLength;
# use hyper::server::{Service, Request, Response};
# struct HelloWorld;
const PHRASE: &'static str = "Hello, World!";

impl Service for HelloWorld {
    // boilerplate hooking up hyper's server types
    type Request = Request;
    type Response = Response;
    type Error = hyper::Error;
    // The future representing the eventual Response your call will
    // resolve to. This can change to whatever Future you need.
    type Future = futures::future::FutureResult<Self::Response, Self::Error>;

    fn call(&self, _req: Request) -> Self::Future {
        // We're currently ignoring the Request
        // And returning an 'ok' Future, which means it's ready
        // immediately, and build a Response with the 'PHRASE' body.
        futures::future::ok(
            Response::new()
                .with_header(ContentLength(PHRASE.len() as u64))
                .with_body(PHRASE)
        )
    }
}
# fn main() {}
```

## Starting the Server

Lastly, we need to hook up our `HelloWorld` service into a running hyper
Server.

We'll dive in to the specifics of some of these things in another guide.
This just sets up an `Http` protocol, binds it to a socket address we
want, and then runs it forever.

```rust,no_run
# extern crate futures;
# extern crate hyper;
# use hyper::header::ContentLength;
# use hyper::server::{Http, Service, Request, Response};
# struct HelloWorld;
# const PHRASE: &'static str = "Hello, World!";
#
# impl Service for HelloWorld {
#     // boilerplate hooking up hyper's server types
#     type Request = Request;
#     type Response = Response;
#     type Error = hyper::Error;
#     // The future representing the eventual Response your call will
#     // resolve to. This can change to whatever Future you need.
#     type Future = futures::future::FutureResult<Self::Response, Self::Error>;
#
#     fn call(&self, _req: Request) -> Self::Future {
#         unimplemented!()
#     }
# }
fn main() {
    let addr = "127.0.0.1:3000".parse().unwrap();
    let server = Http::new().bind(&addr, || Ok(HelloWorld)).unwrap();
    server.run().unwrap();
}
```

[service]: /hyper/master/hyper/server/trait.Service.html
