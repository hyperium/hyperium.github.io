---
title:  Getting Started with a Server
layout: guide
---

Let's start by making a "Hello, World!" server, and expand from there.

First, we need our dependencies. Let's tell Cargo about our dependencies by having this in the `Cargo.toml`.

```toml
[dependencies]
hyper = "0.12"
```

Now lets start on our `main.rs`, and add some imports:

```rust
extern crate hyper;
```

We also need to `use` a few things:

```rust
# extern crate hyper;
use hyper::{Body, Request, Response, Server};
use hyper::rt::Future;
use hyper::service::service_fn_ok;
# fn main() {}
```

## Creating a Service

A [`Service`][service] lets you define how to respond to incoming requests.
While it is possible to implement the trait directly, there are a few patterns
that are common when using Hyper. We've included some helpers for when these
patterns fit our needs.

In this example, we don't have any state to carry around, so we really just
need a simple function:

```rust
# extern crate hyper;
# use hyper::{Body, Request, Response};
# fn main() {}
const PHRASE: &str = "Hello, World!";

fn hello_world(_req: Request<Body>) -> Response<Body> {
    Response::new(Body::from(PHRASE))
}
```

As soon as we get a request, nothing is stopping us from knowing the response
immediately! That function will be used when starting our server.

That new `Response` will by default have a `200 OK` status code, and the `Body`
is able to tell that it is made from a static string, and is able to add a
`Content-Length` header for us automatically.

## Starting the Server

Lastly, we need to hook up our `hello_world` service into a running hyper
Server.

We'll dive in to the specifics of some of these things in another guide.

```rust
# extern crate hyper;
# use hyper::{Body, Request, Response, Server};
# use hyper::rt::Future;
# use hyper::service::service_fn_ok;
# const PHRASE: &str = "Hello, World!";
# fn hello_world(_req: Request<Body>) -> Response<Body> {
#     Response::new(Body::from(PHRASE))
# }
# fn run() {
// This is our socket address...
let addr = ([127, 0, 0, 1], 3000).into();

// A `Service` is needed for every connection, so this
// creates one from our `hello_world` function.
let new_svc = || {
    // service_fn_ok converts our function into a `Service`
    service_fn_ok(hello_world)
};

let server = Server::bind(&addr)
    .serve(new_svc)
    .map_err(|e| eprintln!("server error: {}", e));

// Run this server for... forever!
hyper::rt::run(server);
# }
# fn main() {}
```

To see all the snippets put together, check out the [full example][example]!

[service]: {{ site.docs_url }}/hyper/service/trait.Service.html
[example]: {{ site.examples_url }}/hello.rs
