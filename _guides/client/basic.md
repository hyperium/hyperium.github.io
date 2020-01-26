---
title: Getting Started with a Client
---

To start with, we'll just get a simple `GET` request to a webpage working,
so we can see all the moving parts. First, we need our dependencies.
Let's tell Cargo about our dependencies by having this in the Cargo.toml.

## Dependencies

```toml
[dependencies]
hyper = "0.13"
```

Now, we are ready to import the dependencies in our Rust file.

```rust
extern crate hyper;
```

We need to import pieces to use from our dependencies:

```rust
# extern crate hyper;
use hyper::Client;
# fn main() {}
```

## Runtime

Now, we'll make a request in the `main` of our program. This may seem
like a bit of work just to make a simple request, and you'd be correct,
but the point here is just to show all the setup required. Once you have this,
you are set to make thousands of client requests efficiently.

We have to setup some sort of runtime. By default, hyper can make use of the
[Tokio runtime][Tokio]. If you've never used futures in Rust
before, you may wish to read through [Tokio's guide on Futures][Tokio-Futures].


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

## GET

We can now create a hyper [`Client`][Client] that will be registered to our runtime.

Calling `client.get` returns a `Future` that will eventually be fulfilled with a
[`Response`][Response].

```rust
# extern crate hyper;
# use hyper::Client;
# async fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
// Still inside `async fn main`...
let client = Client::new();

// Parse an `http::Uri`...
let uri = "http://httpbin.org/ip".parse()?;

// Await the response...
let resp = client.get(uri).await?;

println!("Response: {}", resp.status());
# Ok(())
# }
# fn main() {}
```

## Response bodies

Bodies in hyper are always streamed asynchronously. But it's easy to `await`
for each chunk as it comes in! We'll make use of the `HttpBody` trait.

We'll also simply write the body to `stdout`. So, some new imports:

```rust
# extern crate hyper;
# extern crate tokio;
use hyper::body::HttpBody as _;
use tokio::io::{stdout, AsyncWriteExt as _};
```

```rust
# extern crate hyper;
# extern crate tokio;
# use hyper::Client;
# use hyper::body::HttpBody as _;
# use tokio::io::{stdout, AsyncWriteExt as _};
# async fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
// Previously...
let client = Client::new();
let uri = "http://httpbin.org/ip".parse()?;
let mut resp = client.get(uri).await?;
println!("Response: {}", resp.status());

// And now...
while let Some(chunk) = resp.body_mut().data().await {
    stdout().write_all(&chunk?).await?;
}
#
# Ok(())
# }
# fn main() {}
```

And that's it! You can see the [full example here][example].

[Client]: {{ site.docs_url }}/hyper/client/struct.Client.html
[Tokio]: https://tokio.rs
[Tokio-Futures]: https://tokio.rs/docs/getting-started/futures/
[StatusCode]: {{ site.docs_url }}/hyper/struct.StatusCode.html
[Response]: {{ site.docs_url }}/hyper/struct.Response.html
[example]: {{ site.examples_url }}/client.rs
