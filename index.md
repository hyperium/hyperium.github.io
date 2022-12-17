---
layout: home
---

```rust
# extern crate tokio;
# extern crate hyper;
# extern crate http_body_util;
# mod no_run {
use std::{convert::Infallible, net::SocketAddr, error::Error};
use http_body_util::Full;
use hyper::{Request, Response, body::Bytes, service::service_fn};
use hyper::server::conn::http1;
use tokio::net::TcpListener;

async fn hello(
    _: Request<hyper::body::Incoming>,
) -> Result<Response<Full<Bytes>>, Infallible> {
    Ok(Response::new(Full::new(Bytes::from("Hello World!"))))
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error + Send + Sync>> {
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));

    let listener = TcpListener::bind(addr).await?;

    loop {
        let (stream, _) = listener.accept().await?;

        tokio::task::spawn(async move {
            if let Err(err) = http1::Builder::new()
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
