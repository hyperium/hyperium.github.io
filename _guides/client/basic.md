---
title: Getting Started with a Client
---

To start with, we'll just get a simple `GET` request to a webpage working,
so we can see all the moving parts. First, we need our dependencies.
Let's tell Cargo about our dependencies by having this in the Cargo.toml.

## Dependencies

```toml
[dependencies]
hyper = "0.12"
```

Now, we are ready to import the dependencies in our Rust file.

```rust
extern crate hyper;
```

We need to import pieces to use from our dependencies:

```rust
# extern crate hyper;
use std::io::{self, Write};
use hyper::Client;
use hyper::rt::{self, Future, Stream};
# fn main() {}
```

## Runtime

Now, we'll make a request in the `main` of our program. This may seem
like a bit of work just to make a simple request, and you'd be correct,
but the point here is just to show all the setup required. Once you have this,
you are set to make thousands of client requests efficiently.

We have to setup some sort of runtime. By default, hyper can make use of the
[Tokio runtime][Tokio], via `hyper::rt`. If you've never used futures in Rust
before, you may wish to read through [Tokio's guide on Futures][Tokio-Futures].


```rust
# extern crate hyper;
# use hyper::rt;
fn main() {
    rt::run(rt::lazy(|| {
        // This is main future that the runtime will execute.
        //
        // The `lazy` is because we don't want any of this executing *right now*,
        // but rather once the runtime has started up all its resources.
        //
        // This is where we will setup our HTTP client requests.
# Ok::<(), ()>(())
    }));
}
```

## GET

We can now create a hyper [`Client`][Client] that will be registered to our runtime.

Calling `client.get` returns a `Future` that will eventually be fulfilled with a
[`Response`][Response].

```rust
# extern crate hyper;
# use hyper::Client;
# use hyper::rt::{self, Future, Stream};
# fn run() {
# rt::run(rt::lazy(|| {
// still inside rt::run...
let client = Client::new();

let uri = "http://httpbin.org/ip".parse().unwrap();

client
    .get(uri)
    .map(|res| {
        println!("Response: {}", res.status());
    })
    .map_err(|err| {
        println!("Error: {}", err);
    })
# }));
# }
# fn main() {}
```

We chain on the success of that [`Future`][Future] using `map`,
and print out the [`StatusCode`][StatusCode] of the response. If it isn't on fire,
the server should have responded with a `200 OK` status.

## Response bodies

The `map` combinator is useful when your next piece of work doesn't need to
return any more `Future`s. But what if we do? `and_then`!

```rust
# extern crate hyper;
# use std::io::{self, Write};
# use hyper::Client;
# use hyper::rt::{self, Future, Stream};
# fn run() {
# rt::run(rt::lazy(|| {
// still inside rt::run...
let client = Client::new();

let uri = "http://httpbin.org/ip".parse().unwrap();

client
    .get(uri)
    .and_then(|res| {
        println!("Response: {}", res.status());
        res
            .into_body()
            // Body is a stream, so as each chunk arrives...
            .for_each(|chunk| {
                io::stdout()
                    .write_all(&chunk)
                    .map_err(|e| {
                        panic!("example expects stdout is open, error={}", e)
                    })
            })
    })
    .map_err(|err| {
        println!("Error: {}", err);
    })
# }));
# }
# fn main() {}
```

We can use the `and_then` combinator instead, saying that after that `Future`
is ready, we plan to return a new `Future`.

Then, we access the body of the `Response`. The body is just a [`Stream`][Stream] of
chunks of data. A `Stream` will yield its items as they become available. In our case,
we want to write each chunk to the standard out, so we make use of the [`for_each`][ForEach]
combinator of `Stream`. The `for_each` combinator actually returns a `Future` that yields
success when every item of the `Stream` has been successfully processed. That means that
the `Future` returned from our `and_then` call will be fulfilled once the full response body
has been read and written to `stdout`.

And that's it! You can see the [full example here][example].

[Client]: {{ site.docs_url }}/hyper/struct.Client.html
[Tokio]: https://tokio.rs
[Tokio-Futures]: https://tokio.rs/docs/getting-started/futures/
[StatusCode]: {{ site.docs_url }}/hyper/struct.StatusCode.html
[Response]: {{ site.docs_url }}/hyper/struct.Response.html
[Future]: {{ site.futures_url }}/futures/future/trait.Future.html
[Stream]: {{ site.futures_url }}/futures/stream/trait.Stream.html
[ForEach]: {{ site.futures_url }}/futures/stream/trait.Stream.html#method.for_each
[example]: {{ site.examples_url }}/client.rs
