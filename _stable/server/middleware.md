---
title: Getting Started with a Server Middleware
layout: guide
---

As [Upgrade](https://hyper.rs/guides/1/upgrading/) mentioned, hyper v1 is not depended on tower for the Service trait. When we want to add tower-like middleware, there are 2 kind of approach to make it.

Let's create a Logger middleware in [hello-world server](https://hyper.rs/guides/1/server/hello-world/) for instance:

Add tower dependency first

```rust
[dependencies]
hyper = { version = "1", features = ["full"] }
tokio = { version = "1", features = ["full"] }
http-body-util = "0.1"
hyper-util = { version = "0.1", features = ["full"] }
tower = { version = "0.4.13" } // here
```

## Option 1: Use hyper Service trait

Implement hyper Logger middleware

```rust
use hyper::{body::Incoming, service::Service}; // using hyper Service trait
use tower::{Layer, Service};

#[derive(Debug, Clone)]
pub struct Logger<S> {
    inner: S,
}

type Req = hyper::Request<Incoming>;

impl<S> Service<Req> for Logger<S>
where
    S: Service<Req>,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = S::Future;
    fn call(&self, req: Req) -> Self::Future {
        println!("processing request: {} {}", req.method(), req.uri().path());
        self.inner.call(req)
    }
}
```

Then this can be used in server:

```rust
use std::{convert::Infallible, net::SocketAddr};

use hyper::{
    body::{Bytes, Incoming},
    server::conn::http1,
    Request, Response,
};

use http_body_util::Full;
use hyper_util::rt::TokioIo;
use tokio::net::TcpListener;
use tower::ServiceBuilder;
async fn hello(_: Request<Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    Ok(Response::new(Full::new(Bytes::from("Hello, World!"))))
}
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    let listener = TcpListener::bind(addr).await?;
    loop {
        let (stream, _) = listener.accept().await?;
        let io = TokioIo::new(stream);
        tokio::spawn(async move {
            // N.B. should use hyper service_fn here, since it's required to be implemented hyper Service trait!
            let svc = hyper::service::service_fn(hello);
            let svc = ServiceBuilder::new().layer_fn(Logger::new).service(svc);
            if let Err(err) = http1::Builder::new().serve_connection(io, svc).await {
                eprintln!("server error: {}", err);
            }
        });
    }
}
```

## Option 2: use hyper TowerToHyperService trait

[hyper_util::service::TowerToHyperService](https://docs.rs/hyper-util/latest/hyper_util/service/struct.TowerToHyperService.html) trait is an adapter to convert tower Service to hyper Service.

Now implement a tower Logger middleware

```rust
use hyper::body::Incoming;
use tower::Service;

#[derive(Debug, Clone)]
pub struct Logger<S> {
    inner: S,
}
impl<S> Logger<S> {
    pub fn new(inner: S) -> Self {
        Logger { inner }
    }
}
type Req = hyper::Request<Incoming>;
impl<S> Service<Req> for Logger<S>
where
    S: Service<Req> + Clone,
{
    type Response = S::Response;

    type Error = S::Error;

    type Future = S::Future;

    fn poll_ready(
        &mut self,
        cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, req: Req) -> Self::Future {
        println!("processing request: {} {}", req.method(), req.uri().path());
        self.inner.call(req)
    }
}
```

Then use it in the server:

```rust
use std::{convert::Infallible, net::SocketAddr};

use hyper::{
    body::{Bytes, Incoming},
    server::conn::http1,
    Request, Response,
};

use http_body_util::Full;
use hyper_util::{rt::TokioIo, service::TowerToHyperService};
use tokio::net::TcpListener;
use tower::ServiceBuilder;
use crate::logger::Logger as Logger;
async fn hello(_: Request<Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    Ok(Response::new(Full::new(Bytes::from("Hello, World!"))))
}
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    let listener = TcpListener::bind(addr).await?;
    loop {
        let (stream, _) = listener.accept().await?;
        let io = TokioIo::new(stream);
        tokio::spawn(async move {
            // N.B. should use tower service_fn here, since it's reuqired to be implemented tower Service trait before convert to hyper Service!
            let svc = tower::service_fn(hello);
            let svc = ServiceBuilder::new().layer_fn(Logger::new).service(svc);
            // Convert it to hyper service
            let svc = TowerToHyperService::new(svc);
            if let Err(err) = http1::Builder::new().serve_connection(io, svc).await {
                eprintln!("server error: {}", err);
            }
        });
    }
}
```
