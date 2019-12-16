---
title: Advanced Client Usage
---

Once you've done all the setup in the [simple guide][], you probably
have more advanced requests you need to make. In this guide, we'll
make a `POST` request, and make multiple requests at the same time.

## Making a POST

We can prepare a [`Request`][Request] before giving it to the client.
Since we want to post some JSON, and not just simply get a resource,
that's what we'll do.

```rust
# extern crate hyper;
use hyper::{Body, Method, Request, Uri};
# fn main() {}
```

After a quick addition to imports, let's prepare a `Request`:

```rust
# extern crate hyper;
# extern crate tokio;
# mod no_run {
# use hyper::{Body, Method, Request};
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let req = Request::builder()
        .method(Method::POST)
        .uri("http://httpbin.org/post")
        .header("content-type", "application/json")
        .body(Body::from(r#"{"library":"hyper"}"#))?;

    // We'll send it in a second...

    Ok(())
# }
# }
# fn main() {}
```

Using a convenient request builder, we set the [`Method`][Method] to `POST`,
add a URL, and some headers describing our payload. Lastly, a call to `body`
with our JSON bytes.

Now, we can give that to the `client` with the `request` method:


```rust
# extern crate hyper;
# use hyper::{Client, Request};
# async fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
# let req = Request::default();
// let req = ...

let client = Client::new();

// POST it...
let resp = client.request(req).await?;

println!("Response: {}", resp.status());
# Ok(())
# }
# fn main() {}
```

## Multiple Requests

While `await` allows us to write "asynchronous" code in a way that looks
"synchronous", to take full advantage of it, we can make multiple requests
in parallel instead of serially.

We're going to take advantage of "joining" futures, and so need to update our
imports again:

```toml
[dependencies]
hyper = "0.13"
tokio = { version = "0.2", features = ["full"] }
futures = "0.3"
```

Now, we'll create some `async` blocks to describe each future, but since they
are lazy, we can start them in parallel.

```rust
# extern crate hyper;
# extern crate futures;
# use hyper::{Client, Request, Uri};
# async fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
let client = Client::new();

let ip_fut = async {
    let resp = client.get(Uri::from_static("http://httpbin.org/ip")).await?;
    hyper::body::to_bytes(resp.into_body()).await
};
let headers_fut = async {
    let resp = client.get(Uri::from_static("http://httpbin.org/headers")).await?;
    hyper::body::to_bytes(resp.into_body()).await
};

// Wait on both them at the same time:
let (ip, headers) = futures::try_join!(ip_fut, headers_fut)?;
#
# Ok(())
# }
# fn main() {}
```

[simple guide]: ./basic.md
[Request]: {{ site.docs_url }}/hyper/struct.Request.html
[Method]: {{ site.docs_url }}/hyper/struct.Method.html
