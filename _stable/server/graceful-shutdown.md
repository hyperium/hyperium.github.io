---
title:  Gracefully Shutdown a Server
layout: guide
redirect_from:
    - /guides/server/graceful-shutdown
---

hyper's server connections have the ability to initiate a graceful shutdown. A common desire is to coordinate graceful shutdown across all active connections. This is what we'll tackle in this guide.

> A **graceful shutdown** is when a connection stops allowing _new_ requests, while allowing currently in-flight requests to complete.

In order to do, we'll need several pieces:

1. A signal for when to start the shutdown.
2. An accept loop handling newly received connections.
3. A watcher to coordinate the shutdown.

## Determine a shutdown signal

You can use any mechanism to signal that graceful shutdown should begin. That could be an process signal handler, a timer, a special HTTP request, or anything else.

We're going to use a `CTRL+C` signal handler for this guide. Tokio has simple support for making one, let's try:

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

## Modify your server accept loop

> **Unstable**: The code discussed in this guide is in `hyper-util`,
> which is not as stable as that which is in `hyper`. It is production
> ready, but changes may come more frequently.

We're assuming you have an accept loop for your server, similar to what was shown in the [Hello World](hello-world.md) guide. So, we're just going to modify it here:

```rust
# extern crate hyper;
# extern crate http_body_util;
# extern crate hyper_util;
# extern crate tokio;
# mod no_run {
# use std::convert::Infallible;
# use std::net::SocketAddr;
#
# use http_body_util::Full;
# use hyper::body::Bytes;
# use hyper::server::conn::http1;
# use hyper::service::service_fn;
# use hyper::{Request, Response};
# use hyper_util::rt::TokioIo;
# use tokio::net::TcpListener;
# async fn shutdown_signal() {}
# async fn hello(
#     _: Request<hyper::body::Incoming>,
# ) -> Result<Response<Full<Bytes>>, Infallible> {
#     Ok(Response::new(Full::new(Bytes::from("Hello World!"))))
# }
# async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
# let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
let listener = TcpListener::bind(addr).await?;
// specify our HTTP settings (http1, http2, auto all work)
let mut http = http1::Builder::new();
// the graceful watcher
let graceful = hyper_util::server::graceful::GracefulShutdown::new();
// when this signal completes, start shutdown
let mut signal = std::pin::pin!(shutdown_signal());

// Our server accept loop
loop {
    tokio::select! {
        Ok((stream, _addr)) = listener.accept() => {
            let io = TokioIo::new(stream);
            let conn = http.serve_connection(io, service_fn(hello));
            // watch this connection
            let fut = graceful.watch(conn);
            tokio::spawn(async move {
                if let Err(e) = fut.await {
                    eprintln!("Error serving connection: {:?}", e);
                }
            });
        },

        _ = &mut signal => {
            drop(listener);
            eprintln!("graceful shutdown signal received");
            // stop the accept loop
            break;
        }
    }
}

// Now start the shutdown and wait for them to complete
// Optional: start a timeout to limit how long to wait.

tokio::select! {
    _ = graceful.shutdown() => {
        eprintln!("all connections gracefully closed");
    },
    _ = tokio::time::sleep(std::time::Duration::from_secs(10)) => {
        eprintln!("timed out wait for all connections to close");
    }
}
# Ok(())
# }
# }
# fn main() {}
```

