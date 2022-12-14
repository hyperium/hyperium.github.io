---
title:  Getting Started with a Server
layout: guide
---

Let's start by making a "Hello, World!" server, and expand from there.

First we need to declare our dependencies, let's add the following to our `Cargo.toml`:

```toml
[dependencies]
hyper = { version = "1.0.0-rc.1", features = ["full"] }
tokio = { version = "1", features = ["full"] }
http-body-util = "0.1.0-rc.1" 
```

Next, we need to add some imports in our `main.rs` file:

```rust
use std::convert::Infallible;
use std::net::SocketAddr;

use http_body_util::Full;
use hyper::body::Bytes;
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response};
use tokio::net::TcpListener;
# fn main() {}
```

## Creating a Service

A [`Service`][service] lets us define how our server will respond to 
incoming requests. It represents an async function that takes a 
[`Request`][request] and returns a `Future`. When the processing of this
future is complete, it will resolve to a [`Response`][response] or an error.

Hyper provides a utility for creating a `Service` from a function that should 
serve most usecases: [`service_fn`][service_fn]. We will use this to create 
a service from our `hello` function below when we're ready to start our 
server.

```rust
# use std::convert::Infallible;
# use http_body_util::Full;
# use hyper::body::Bytes;
# use hyper::{Request, Response};
async fn hello(_: Request<hyper::body::Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    Ok(Response::new(Full::new(Bytes::from("Hello, World!"))))
}
```

Using this function as a service, we tell our server to respond to all requests 
with a default `200 OK` status. The response `Body` will contain our friendly
greeting as a single chunk of bytes, and the `Content-Length` header will be 
set automatically.

## Starting the Server

Lastly, we need to hook up our `hello` service into a running hyper server.

We'll dive in to the specifics of some of these things in another guide.

```rust
# use std::convert::Infallible;
# use std::net::SocketAddr;
# 
# use http_body_util::Full;
# use hyper::body::Bytes;
# use hyper::server::conn::http1;
# use hyper::service::service_fn;
# use hyper::{Request, Response};
# use tokio::net::TcpListener;
# async fn hello(
#     _: Request<hyper::body::Incoming>,
# ) -> Result<Response<Full<Bytes>>, Infallible> {
#     Ok(Response::new(Full::new(Bytes::from("Hello World!"))))
# }
#[tokio::main]
async fn main() {
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));

    // We create a TcpListener and bind it to 127.0.0.1:3000
    let listener = TcpListener::bind(addr).await?;

    // We start a loop to continuously accept incoming connections
    loop {
        let (stream, _) = listener.accept().await?;

        // Spawn a tokio task to serve multiple connections concurrently
        tokio::task::spawn(async move {
            // Finally, we bind the incoming connection to our `hello` service
            if let Err(err) = http1::Builder::new()
                // `service_fn` converts our function in a `Service`
                .serve_connection(stream, service_fn(hello))
                .await
            {
                println!("Error serving connection: {:?}", err);
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

[service]: {{ site.docs_url }}/hyper/service/trait.Service.html
[service_fn]: {{ site.docs_url }}/hyper/service/fn.service_fn.html
[request]: {{ site.docs_url }}/hyper/struct.Request.html
[response]: {{ site.docs_url }}/hyper/struct.Response.html
[parts]: {{ site.docs_url }}/http/0.2.8/http/response/struct.Parts.html
[example]: {{ site.examples_url }}/hello.rs
[impl service]: {{ site.examples_url }}/service_struct_impl.rs
