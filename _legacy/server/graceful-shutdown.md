---
title:  Gracefully Shutdown a Server
layout: guide
redirect_from: 
    - /guides/server/graceful-shutdown
---

hyper `Server`s have the ability to "gracefully" shutdown. This means stopping to accept new requests, and shutting down once all in-progress requests have completed.

We're going to assume you already have server code working, such as from following the [Hello World](hello-world.md) or [Echo](echo.md) guides.

The `Server` type has a `with_graceful_shutdown` method that is passed a `Future` of your choosing. Once that `Future` completes, the `Server` will start the shutdown process. It could be any `Future`, such as a `oneshot` channel. In this guide, we'll setup a signal handler to listen for the user pressing `CTRL+C`.

First, let's create a `shutdown_signal` async function:

```rust
# extern crate tokio;
async fn shutdown_signal() {
    // Wait for the CTRL+C signal
    tokio::signal::ctrl_c()
        .await
        .expect("failed to install CTRL+C signal handler");
}
# fn main() {}
```

Next, we can plug this into an existing server:

```rust
# extern crate hyper;
# extern crate tokio;
# mod no_run {
# use std::convert::Infallible;
# use std::net::SocketAddr;
# use hyper::{Body, Request, Response, Server};
# use hyper::service::{make_service_fn, service_fn};
# async fn hello_world(_req: Request<Body>) -> Result<Response<Body>, Infallible> {
#     Ok(Response::new("Hello, World".into()))
# }
# async fn shutdown_signal() {}
#[tokio::main]
async fn main() {
#    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
#    let make_svc = make_service_fn(|_conn| async {
#        Ok::<_, Infallible>(service_fn(hello_world))
#    });
    // Constructed `addr` and `make_svc` from your app above..

    // And construct the `Server` like normal...
    let server = Server::bind(&addr).serve(make_svc);

    // And now add a graceful shutdown signal...
    let graceful = server.with_graceful_shutdown(shutdown_signal());

    // Run this server for... forever!
    if let Err(e) = graceful.await {
        eprintln!("server error: {}", e);
    }
}
# }
# fn main() {}
```
