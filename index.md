---
title: hyper.rs
layout: home
---

```rust
extern crate hyper;
extern crate service_fn;

use hyper::header::{ContentLength, ContentType};
use hyper::server::{Http, Response};
use service_fn::service_fn;

static TEXT: &'static str = "Hello, World!";

fn run() -> Result<(), hyper::Error> {
    let addr = ([127, 0, 0, 1], 3000).into();

    let hello = || Ok(service_fn(|_req|{
        Ok(Response::<hyper::Body>::new()
            .with_header(ContentLength(TEXT.len() as u64))
            .with_header(ContentType::plaintext())
            .with_body(TEXT))
    }));

    let server = Http::new().bind(&addr, hello)?;
    server.run()
}

# fn main() {}
```
