---
title: Getting Started with a Client
layout: guide
---

To start with, we'll just get a simple `GET` request to a webpage working,
so we can see all the moving parts. First, we need our dependencies.
Let's tell Cargo about our dependencies by having this in the Cargo.toml.

## Dependencies

```toml
[dependencies]
hyper = { version = "1.0.0-rc.1", features = ["full"] }
tokio = { version = "1", features = ["full"] }
http-body-util = "0.1.0-rc.1"
```

Now, we need to import pieces to use from our dependencies:

```rust
# extern crate http_body_util;
# extern crate hyper;
# extern crate tokio;
use http_body_util::Empty;
use hyper::Request;
use hyper::body::Bytes;
use tokio::net::TcpStream;
# fn main() {}
```

## Runtime

Now, we'll make a request in the `main` of our program. This may seem
like a bit of work just to make a simple request, and you'd be correct,
but the point here is just to show all the setup required. Once you have this,
you are set to make thousands of client requests efficiently.

We have to setup some sort of runtime. You can use whichever async runtime you'd
like, but for this guide we're going to use tokio. If you've never used futures 
in Rust before, you may wish to read through [Tokio's guide on Futures][Tokio-Futures].

```rust
# extern crate tokio;
# mod no_run {
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    // This is where we will setup our HTTP client requests.

    Ok(())
}
# }
# fn main() {}
```

## Setup

To get started we'll need to get a few things setup. For this guide we're
going to send a GET [`Request`][Request] to [http://httpbin.org/ip](http://httpbin.org/ip), 
which will return a `200 OK` and the Requester's IP address in the body. 

We need to open a TCP connection to the remote host using a hostname and port,
which in this case is `httpbin.org` and the default port for HTTP: `80`. With our
connection opened, we pass it in to the `client::conn::http1::handshake` function,
performing a handshake to verify the remote is ready to receive our requests. 

A successful handshake will give us a [Connection][Connection] future that processes
all HTTP state, and a [SendRequest][SendRequest] struct that we can use to send our 
`Request`s on the connection. 

To start driving the HTTP state we have to poll the `Connection`, so to finish our 
setup we'll spawn a `tokio::task` and `await` it.

```rust
# extern crate http_body_util;
# extern crate hyper;
# extern crate tokio;
# use http_body_util::Empty;
# use hyper::body::Bytes;
# use hyper::Request;
# use tokio::net::TcpStream;
# async fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
// Parse our URL...
let url = "http://httpbin.org/ip".parse::<hyper::Uri>()?;

// Get the host and the port
let host = url.host().expect("uri has no host");
let port = url.port_u16().unwrap_or(80);

let address = format!("{}:{}", host, port);

// Open a TCP connection to the remote host
let stream = TcpStream::connect(address).await?;

// Perform a TCP handshake
let (mut sender, conn) = hyper::client::conn::http1::handshake(stream).await?;

// Spawn a task to poll the connection, driving the HTTP state
tokio::task::spawn(async move {
    if let Err(err) = conn.await {
        println!("Connection failed: {:?}", err);
    }
});
# let authority = url.authority().unwrap().clone();
# let req = Request::builder()
#     .uri(url)
#     .header(hyper::header::HOST, authority.as_str())
#     .body(Empty::<Bytes>::new())?;
# let mut res = sender.send_request(req).await?;
# Ok(())
# }
# fn main() {}
```

## GET

Now that we've set up our connection, we're ready to construct and send our first `Request`! 
Since `SendRequest` doesn't require absolute-form `URI`s we are required to include a `HOST` 
header in our requests. And while we can send our `Request` with an empty `Body`, we need to
explicitly set it, which we'll do with the [`Empty`][Empty] utility struct.

All we need to do now is pass the `Request` to `SendRequest::send_request`, this returns a 
future which will resolve to the [`Response`][Response] from `httpbin.org`. We'll print the
status of the response to see that it returned the expected `200 OK` status.

```rust
# extern crate http_body_util;
# extern crate hyper;
# extern crate tokio;
# use http_body_util::Empty;
# use hyper::body::Bytes;
# use hyper::Request;
# use tokio::net::TcpStream;
# async fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
# let url = "http://httpbin.org/ip".parse::<hyper::Uri>()?;
# let host = url.host().expect("uri has no host");
# let port = url.port_u16().unwrap_or(80);
# let addr = format!("{}:{}", host, port);
# let stream = TcpStream::connect(addr).await?;
# let (mut sender, conn) = hyper::client::conn::http1::handshake(stream).await?;
# tokio::task::spawn(async move {
# if let Err(err) = conn.await {
# println!("Connection failed: {:?}", err);
# }
# });
// The authority of our URL will be the hostname of the httpbin remote
let authority = url.authority().unwrap().clone();

// Create an HTTP request with an empty body and a HOST header
let req = Request::builder()
    .uri(url)
    .header(hyper::header::HOST, authority.as_str())
    .body(Empty::<Bytes>::new())?;

// Await the response...
let mut res = sender.send_request(req).await?;

println!("Response status: {}", res.status());
# Ok(())
# }
# fn main() {}
```

## Response bodies

We know that sending a GET `Request` to `httpbin.org/ip` will return our IP address in
the `Response` body. To see the returned body, we'll simply write it to `stdout`.

Bodies in hyper are asynchronous streams of [`Frame`][Frame]s, so we don't have to wait for the
whole body to arrive, buffering it into memory, and then writing it out. We can simply 
`await` each `Frame` and write them directly to `stdout` as they arrive!

In addition to importing `stdout`, we'll need to make use of the `BodyExt` trait:

```rust
# extern crate http_body_util;
# extern crate tokio;
use http_body_util::BodyExt;
use tokio::io::{stdout, AsyncWriteExt as _};
```

```rust
# extern crate http_body_util;
# extern crate hyper;
# extern crate tokio;
# use http_body_util::{BodyExt, Empty};
# use hyper::body::Bytes;
# use hyper::Request;
# use tokio::net::TcpStream;
# use tokio::io::{self, AsyncWriteExt as _};
# async fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
# let url = "http://httpbin.org/ip".parse::<hyper::Uri>()?;
# let host = url.host().expect("uri has no host");
# let port = url.port_u16().unwrap_or(80);
# let addr = format!("{}:{}", host, port);
# let stream = TcpStream::connect(addr).await?;
# let (mut sender, conn) = hyper::client::conn::http1::handshake(stream).await?;
# tokio::task::spawn(async move {
#     if let Err(err) = conn.await {
#         println!("Connection failed: {:?}", err);
#     }
# });
# let authority = url.authority().unwrap().clone();
# let req = Request::builder()
# .uri(url)
# .header(hyper::header::HOST, authority.as_str())
# .body(Empty::<Bytes>::new())?;
# let mut res = sender.send_request(req).await?;
// Stream the body, writing each frame to stdout as it arrives
while let Some(next) = res.frame().await {
    let frame = next?;
    if let Some(chunk) = frame.data_ref() {
        io::stdout().write_all(&chunk).await?;
    }
}
# Ok(())
# }
# fn main() {}
```
And that's it! You can see the [full example here][example].

[Tokio]: https://tokio.rs
[Tokio-Futures]: https://tokio.rs/tokio/tutorial/async
[StatusCode]: {{ site.docs_url }}/hyper/struct.StatusCode.html
[Response]: {{ site.docs_url }}/hyper/struct.Response.html
[Request]: {{ site.docs_url }}/hyper/struct.Request.html
[Connection]: {{ site.docs_url }}/hyper/client/conn/http1/struct.Connection.html
[SendRequest]: {{ site.docs_url }}/hyper/client/conn/http1/struct.SendRequest.html
[Frame]: {{ site.docs_url }}/hyper/body/struct.Frame.html
[Empty]: {{ site.http_body_util_url }}/http_body_util/struct.Empty.html

[example]: {{ site.examples_url }}/client.rs
