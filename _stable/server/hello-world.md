---
title:  Getting Started with a Server
layout: guide
---

Let's start by making a "Hello, World!" server, and expand from there.

First, we need to declare our dependencies, let's add the following to our `Cargo.toml`:

```toml
[dependencies]
hyper = { version = "1", features = ["full"] }
tokio = { version = "1", features = ["full"] }
http-body-util = "0.1"
hyper-util = { version = "0.1", features = ["full"] }
```

Next, we need to add some imports in our `main.rs` file:

```rust
# extern crate tokio;
# extern crate hyper;
# extern crate http_body_util;
# extern crate hyper_util;
use std::convert::Infallible;
use std::net::SocketAddr;

use http_body_util::Full;
use hyper::body::Bytes;
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response};
use hyper_util::rt::TokioIo;
use tokio::net::TcpListener;
# fn main() {}
```

## Creating a Service

A [`Service`][service] lets us define how our server will respond to 
incoming requests. It represents an async function that takes a 
[`Request`][request] and returns a `Future`. When the processing of this
future is complete, it will resolve to a [`Response`][response] or an error.

Hyper provides a utility for creating a `Service` from a function that should 
serve most use cases: [`service_fn`][service_fn]. We will use this to create 
a service from our `hello` function below when we're ready to start our 
server.

```rust
# extern crate hyper;
# extern crate http_body_util;
# use std::convert::Infallible;
# use http_body_util::Full;
# use hyper::body::Bytes;
# use hyper::{Request, Response};
# fn main() {}
async fn hello(_: Request<hyper::body::Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    Ok(Response::new(Full::new(Bytes::from("Hello, World!"))))
}
```

Using this function as a service, we tell our server to respond to all requests 
with a default `200 OK` status. The response `Body` will contain our friendly
greeting as a single chunk of bytes, and the `Content-Length` header will be 
set automatically.

## Starting the Server

Lastly, we need to hook up our `hello` service into a running Hyper server.

We'll dive in to the specifics of some of these things in another guide.

```rust
# extern crate tokio;
# extern crate hyper;
# extern crate http_body_util;
# extern crate hyper_util;
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
# async fn hello(
#     _: Request<hyper::body::Incoming>,
# ) -> Result<Response<Full<Bytes>>, Infallible> {
#     Ok(Response::new(Full::new(Bytes::from("Hello World!"))))
# }
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));

    // We create a TcpListener and bind it to 127.0.0.1:3000
    let listener = TcpListener::bind(addr).await?;

    // We start a loop to continuously accept incoming connections
    loop {
        let (stream, _) = listener.accept().await?;

        // Use an adapter to access something implementing `tokio::io` traits as if they implement
        // `hyper::rt` IO traits.
        let io = TokioIo::new(stream);

        // Spawn a tokio task to serve multiple connections concurrently
        tokio::task::spawn(async move {
            // Finally, we bind the incoming connection to our `hello` service
            if let Err(err) = http1::Builder::new()
                // `service_fn` converts our function in a `Service`
                .serve_connection(io, service_fn(hello))
                .await
            {
                eprintln!("Error serving connection: {:?}", err);
            }
        });
    }
}
# }
# fn main() {}
```

To see all the snippets put together, check out the [full example][example]!

Also, if `service_fn` doesn't meet your requirements and you'd like to implement 
`Service` yourself, see this [example][impl service].

## HTTP/2

This example uses the `http1` module to create a server that speaks HTTP/1.
In case you want to use HTTP/2, you can use the `http2` module with a few changes to the
http1 server. The http2 builder requires an executor to run. Executor should implement the `hyper::rt::Executor` trait.

To implement the Executor, check out the runtime [example][runtime].
To see the full example with HTTP/2, check out the [full example][example_http2]!

[service]: {{ site.hyper_docs_url }}/hyper/service/trait.Service.html
[service_fn]: {{ site.hyper_docs_url }}/hyper/service/fn.service_fn.html
[request]: {{ site.hyper_docs_url }}/hyper/struct.Request.html
[response]: {{ site.hyper_docs_url }}/hyper/struct.Response.html
[parts]: {{ site.http_docs_url }}/http/response/struct.Parts.html
[example]: {{ site.examples_url }}/hello.rs
[example_http2]: {{ site.examples_url }}/hello-http2.rs 
[runtime]: ../init/runtime.md
[impl service]: {{ site.examples_url }}/service_struct_impl.rs
