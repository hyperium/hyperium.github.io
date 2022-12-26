---
title: Advanced Client Usage
layout: guide
---

Once you've done all the setup in the [simple guide][], you probably
have more advanced requests you need to make. In this guide, we'll
make a `POST` request to [http://httpbin.org/post](http://httpbin.org/post), 
and make multiple requests at the same time.

## Making a POST

Like we did in the getting started guide, we can prepare a request 
before giving it to the client by using the `Request::builder` method.
Since we want to post some JSON, and not just simply get a resource,
that's what we'll do.

We'll reuse the setup code we did in the getting started guide.

```rust
# extern crate http_body_util;
# extern crate hyper;
use http_body_util::Full;
use hyper::Method;
```

After a quick addition to imports, let’s prepare our POST `Request`:

```rust
# extern crate http_body_util;
# extern crate hyper;
# extern crate tokio;
# use http_body_util::Full;
# use hyper::body::Bytes;
# use hyper::{Method, Request};
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
# let authority = url.authority().unwrap().clone();
let req = Request::builder()
    .method(Method::POST)
    .uri(url)
    .header(hyper::header::HOST, authority.as_str())
    .header(hyper::header::CONTENT_TYPE, "application/json")
    .body(Full::new(Bytes::from(r#"{"library":"hyper"}"#)))?;
# let mut res = sender.send_request(req).await?;
# Ok(())
# }
# fn main() {}
```

Using the convenient request builder, we set the [`Method`][Method] to `POST`,
added our URL and HOST header like before, and set the `content-type` header to 
describe our payload. Lastly, we used the [`Full`][Full] utility to add a 
single-chunk body containing our JSON bytes.

Now, we can give that to the `client` with the `request` method:


```rust
# extern crate http_body_util;
# extern crate hyper;
# extern crate tokio;
# use http_body_util::Full;
# use hyper::body::Bytes;
# use hyper::{Method, Request};
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
# let authority = url.authority().unwrap().clone();
# let req = Request::builder()
# .method(Method::POST)
# .uri(url)
# .header(hyper::header::HOST, authority.as_str())
# .header(hyper::header::CONTENT_TYPE, "application/json")
# .body(Full::new(Bytes::from(r#"{"library":"hyper"}"#)))?;
// let req = ...

// POST it using the SendRequest we set up earlier
let mut res = sender.send_request(req).await?;

// Print the status
println!("Response status: {}", res.status());
# Ok(())
# }
# fn main() {}
```

## Multiple Requests

While `await` allows us to write "asynchronous" code in a way that looks
"synchronous", to take full advantage of it, we can make multiple requests
in parallel instead of serially.

We're going to take advantage of "joining" futures.

Now, we'll create some `async` blocks to describe each future, but since they
are lazy, we can start them in parallel. Since we'll need to create a `SendRequest`
for each, lets extract some of our setup code from the getting started guide into a 
helper function.

First lets add a couple of new imports:
```rust
# extern crate http_body_util;
# extern crate hyper;
# extern crate tokio;
use std::convert::Infallible;
use http_body_util::combinators::BoxBody;
use hyper::client::conn::http1::SendRequest;
```

```rust
# extern crate http_body_util;
# extern crate hyper;
# extern crate tokio;
# use std::convert::Infallible;
# use hyper::body::Bytes;
# use http_body_util::combinators::BoxBody;
# use tokio::net::TcpStream;
# use hyper::client::conn::http1::SendRequest;
# type Result<T> = std::result::Result<T, Box<dyn std::error::Error + Send + Sync>>;
async fn prepare_sender(addr: &str) -> Result<SendRequest<BoxBody<Bytes, Infallible>>> {
    let stream = TcpStream::connect(addr).await?;

    let (sender, conn) = hyper::client::conn::http1::handshake(stream).await?;

    tokio::task::spawn(async move {
        if let Err(err) = conn.await {
            println!("Connection failed: {:?}", err);
        }
    });

    Ok(sender)
}
# fn main() {}
```

We'll simply pass in the address to connect to, the host and port from our URL, and return
a `SendRequest` with a boxed trait object as it's body type, allowing us some freedom in
which type of body we return. We only care that it implements the `HttpBody` trait, that its
data is `Bytes` and since we're only using `Full` and `Empty` we can use `Infallible` for the
error type.

Now that we have that out of the way, we can create our async blocks and execute them concurrently.

```rust
# extern crate http_body_util;
# extern crate hyper;
# extern crate tokio;
# use std::convert::Infallible;
# use http_body_util::{BodyExt, Empty, Full};
# use http_body_util::combinators::BoxBody;
# use hyper::body::Bytes;
# use hyper::{Method, Request};
# use tokio::net::TcpStream;
# use hyper::client::conn::http1::SendRequest;
# type Result<T> = std::result::Result<T, Box<dyn std::error::Error + Send + Sync>>;
# async fn prepare_sender(addr: &str) -> Result<SendRequest<BoxBody<Bytes, Infallible>>> {
# let stream = TcpStream::connect(addr).await?;
# let (sender, conn) = hyper::client::conn::http1::handshake::<_, BoxBody<Bytes, Infallible>>(stream).await?;
# tokio::task::spawn(async move {
# if let Err(err) = conn.await {
# println!("Connection failed: {:?}", err);
# }
# });
# Ok(sender)
# }
# async fn run() -> Result<()> {
# let url = "http://httpbin.org/ip".parse::<hyper::Uri>()?;
# let host = url.host().expect("uri has no host");
# let port = url.port_u16().unwrap_or(80);
# let addr = format!("{}:{}", host, port);
# let mut sender = prepare_sender(&addr).await?;
# let authority = url.authority().unwrap().clone();
# let req = Request::builder()
# .method(Method::POST)
# .uri(url)
# .header(hyper::header::HOST, authority.as_str())
# .header(hyper::header::CONTENT_TYPE, "application/json")
# .body(Full::new(Bytes::from(r#"{"library":"hyper"}"#)).boxed())?;
# let mut res = sender.send_request(req).await?;
// We'll use a closure to create a request for each endpoint
let make_request = |url: &str| {
    Request::builder()
        .uri(url)
        .header(hyper::header::HOST, authority.as_str())
        .body(Empty::<Bytes>::new().boxed())
        .unwrap()
};

// And another closure for creating our `send_request` futures
let send_request = |req: Request<BoxBody<Bytes, Infallible>>| async {
    let mut sender = prepare_sender(&addr).await?;
    let res = sender.send_request(req).await?;

    // Collect the body of the response and return it as Bytes
    Ok::<_, Box<dyn std::error::Error + Send + Sync>>(res.collect().await?.to_bytes())
};

// Wait on both of our futures concurrently:
let (ip, headers) = tokio::try_join!(
    send_request(make_request("http://httpbin.org/ip")),
    send_request(make_request("http://httpbin.org/headers"))
)?;

// Convert the response bytes to a string slice and print it
println!("Ip: {}", std::str::from_utf8(ip.as_ref()).unwrap());
println!(
    "Headers: {}",
    std::str::from_utf8(headers.as_ref()).unwrap()
);
# Ok(())
# }
# fn main() {}
```

[simple guide]: ./basic.md
[Request]: {{ site.legacy_docs_url }}/hyper/struct.Request.html
[Method]: {{ site.legacy_docs_url }}/hyper/struct.Method.html
