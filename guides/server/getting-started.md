---
title:  Getting Started with a Server
---

Let's start by making a "Hello, World!" server, and expand from there.

## Creating a Service

A [`Service`][service] is how you define how to serve incoming requests
with outgoing responses. Let's define a simple one, naming it after what
we expect our service to do.

```rust,ignore
struct HelloWorld;
```

Next, we need to implement [`Service`][service] for `HelloWorld`:

```rust,ignore
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
```

