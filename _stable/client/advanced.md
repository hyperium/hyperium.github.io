---
title: Advanced Client Usage
layout: guide
---

Once you've done all the setup in the [simple guide][], you probably
have more advanced requests you need to make. In this guide, we'll
make a `POST` request to [http://httpbin.org/post](http://httpbin.org/post), 
and we'll make multiple requests at the same time.

## Making a POST

Like we did in the getting started guide, we can prepare a [`Request`][Request] 
before giving it to the client by utilizing the request builder.

We'll reuse the setup code we used in the getting started guide, but we
need to add some imports:

```rust
# extern crate http_body_util;
# extern crate hyper;
use http_body_util::Full;
use hyper::Method;
```

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
// We'll get the hostname from the URL like before...
let authority = url.authority().unwrap().clone();

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

You'll noticed that we now explicitly set the [`Method`][Method], we didn't have
to do that before since the builder defaults to `GET`. In addition to setting the method,
we added our URL and `HOST` header like before, and we set the `content-type` header
to describe our payload. Lastly, we used the [`Full`][Full] utility to construct our
request with a single-chunk body containing our JSON bytes.

Now, we can pass it to the `SendRequest` we set up earlier:

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

// POST it using the `SendRequest::send_request` method
let mut res = sender.send_request(req).await?;

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
// A simple type alias for errors.
type BoxError = Box<dyn std::error::Error + Send + Sync>;

async fn prepare_sender(addr: &str) -> Result<SendRequest<BoxBody<Bytes, Infallible>>, BoxError> {
    let stream = TcpStream::connect(addr).await?;

    let (sender, conn) = hyper::client::conn::http1::handshake(stream).await?;

    // We have to remember to spawn a task to poll the connection,
    // if we don't `SendRequest` will do nothing.
    tokio::task::spawn(async move {
        if let Err(err) = conn.await {
            println!("Connection failed: {:?}", err);
        }
    });

    Ok(sender)
}
# fn main() {}
```

We'll simply pass in the address to connect to, which is the host and port from our URL, and 
return a [`SendRequest`][SendRequest] with a boxed trait object as its body type, allowing us 
some freedom in which type of body we return. We only care that it implements the [`Body`][Body] 
trait, that its data is `Bytes`, and since we're only using [`Full`][Full] and [`Empty`][Empty] 
to construct our bodies we can use `Infallible` for the error type.

Now that we have that out of the way, we can create our `send_request` futures and run them
in parallel.

```rust
# extern crate http_body_util;
# extern crate hyper;
# extern crate tokio;
# use std::convert::Infallible;
# use std::result::Result;
# use http_body_util::{BodyExt, Empty};
# use http_body_util::combinators::BoxBody;
# use hyper::body::Bytes;
# use hyper::{Method, Request};
# use tokio::net::TcpStream;
# use hyper::client::conn::http1::SendRequest;
# type BoxError = Box<dyn std::error::Error + Send + Sync>;
# async fn prepare_sender(addr: &str) -> Result<SendRequest<BoxBody<Bytes, Infallible>>, BoxError> {
# let stream = TcpStream::connect(addr).await?;
# let (sender, conn) = hyper::client::conn::http1::handshake::<_, BoxBody<Bytes, Infallible>>(stream).await?;
# tokio::task::spawn(async move {
# if let Err(err) = conn.await {
# println!("Connection failed: {:?}", err);
# }
# });
# Ok(sender)
# }
# async fn run() -> Result<(), BoxError> {
# let url = "http://httpbin.org/ip".parse::<hyper::Uri>()?;
# let host = url.host().expect("uri has no host");
# let port = url.port_u16().unwrap_or(80);
# let addr = format!("{}:{}", host, port);
# let authority = url.authority().unwrap().clone();
// We'll use a closure to create a request for each endpoint
let make_request = |url: &str| {
    Request::builder()
        .uri(url)
        .header(hyper::header::HOST, authority.as_str())
        .body(Empty::<Bytes>::new().boxed())
        .unwrap()
};

// And another closure for creating our `send_request` futures
let send_request = |req: Request<BoxBody<Bytes, Infallible>>| {
    let addr = addr.clone();

    // Spawn a task for our futures to run them in parallel
    tokio::spawn(async move {
        let mut sender = prepare_sender(&addr.clone()).await?;
        let res = sender.send_request(req).await?;

        // Collect the body of the response and return it as Bytes
        Ok::<_, BoxError>(res.collect().await?.to_bytes())
    })
};

// Wait on both of our futures at the same time:
let (ip, headers) = tokio::try_join!(
    send_request(make_request("http://httpbin.org/ip")),
    send_request(make_request("http://httpbin.org/headers"))
)?;
# Ok(())
# }
# fn main() {}
```

[simple guide]: ./basic.md
[SendRequest]: {{ site.docs_url }}/hyper/client/conn/http1/struct.SendRequest.html
[Full]: {{ site.http_body_util_url }}/http_body_util/struct.Full.html
[Empty]: {{ site.http_body_util_url }}/http_body_util/struct.Empty.html
[Request]: {{ site.docs_url }}/hyper/struct.Request.html
[Method]: {{ site.docs_url }}/hyper/struct.Method.html
[Body]: {{ site.docs_url }}/hyper/body/trait.Body.html
