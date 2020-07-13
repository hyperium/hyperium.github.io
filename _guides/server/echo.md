---
title: Echo, echo, echo
---

You already have a [Hello World server](hello-world.md)? Excellent! Usually,
servers do more than just spit out the same body for every request. To
exercise several more parts of hyper, this guide will go through
building an echo server.

An echo server will listen for incoming connections and send back the
request body as the response body on `POST` requests.

## Routing

First thing we will do, beyond renaming our service to `echo`, is setup some
routing. We want to have a route explaining instructions on how to use
our server, and another for receiving data. Oh, and we should also
handle the case when someone asks for a route we don't know!

We're going to be using more of the [futures][future-crate] crate, so let's add
that as a dependency:

```toml
[dependencies]
hyper = "0.13"
tokio = { version = "0.2", features = ["full"] }
futures = "0.3"
```

Then, we need to add some to our imports:

```rust
# extern crate hyper;
# extern crate futures;
use hyper::{Method, StatusCode};
# fn main() {}
```

And make some changes to your `Service`, such as returning a `Future` of a `Response`,
since we may not have one ready immediately:

```rust
# extern crate futures;
# extern crate hyper;
# use futures::future::{self, Future};
# use hyper::{Body, Method, Request, Response, StatusCode};
#
async fn echo(req: Request<Body>) -> Result<Response<Body>, hyper::Error> {
    let mut response = Response::new(Body::empty());

    match (req.method(), req.uri().path()) {
        (&Method::GET, "/") => {
            *response.body_mut() = Body::from("Try POSTing data to /echo");
        },
        (&Method::POST, "/echo") => {
            // we'll be back
        },
        _ => {
            *response.status_mut() = StatusCode::NOT_FOUND;
        },
    };

    Ok(response)
}
# fn main() {}
```

We built a super simple routing table just by matching on the `method`
and `path` of an incoming `Request`. If someone requests `GET /`, our
service will let them know they should try our echo powers out. We also
are checking for `POST /echo`, but currently don't do anything about it.

Our third rule catches any other method and path combination, and
changes the `StatusCode` of the `Response`. The default status of a
`Response` is HTTP's `200 OK` (`StatusCode::OK`), which is correct for
the other routes. But the third case will instead send back `404 Not
Found`.

## Body Streams

Now let's get that echo in place. We'll start with the simplest solution, and
then make alterations exercising more complex things you can do with the
`Body` streams.

First up, plain echo. Both the `Request` and the `Response` have body streams,
and by default, you can easily just pass the `Body` of the `Request` into the
`Response`.

```rust
# extern crate hyper;
# use hyper::{Body, Method, Request, Response};
# fn echo(req: Request<Body>) -> Response<Body> {
#     let mut response = Response::default();
#     match (req.method(), req.uri().path()) {
// inside that match from before
(&Method::POST, "/echo") => {
    *response.body_mut() = req.into_body();
},
#         _ => unreachable!(),
#     }
#     response
# }
# fn main() {}
```

Running our server now will echo any data we `POST` to `/echo`. That was easy.
What if we wanted to uppercase all the text? We could use a `map` on our streams.

### Body mapping

We're going to need a couple of extra imports, so let's add those to the top of the file:

```rust
# extern crate futures;
# extern crate hyper;
use futures::TryStreamExt as _;
# fn main() {}
```

A `Body` implements the `Stream` trait from futures, producing a bunch of
`Bytes`s, as data comes in. `Bytes` is just a convenient type from hyper
that represents a bunch of bytes. It can be easily converted into other
typical containers of bytes.

Next, let's add a new `/echo/uppercase` route mapping the body to uppercase:

```rust
# extern crate hyper;
# extern crate futures;
# use futures::TryStreamExt as _;
# use hyper::{Body, Method, Request, Response};
# fn echo(req: Request<Body>) -> Response<Body> {
#     let mut response = Response::default();
#     match (req.method(), req.uri().path()) {
// Yet another route inside our match block...
(&Method::POST, "/echo/uppercase") => {
    // This is actually a new `futures::Stream`...
    let mapping = req
        .into_body()
        .map_ok(|chunk| {
            chunk.iter()
                .map(|byte| byte.to_ascii_uppercase())
                .collect::<Vec<u8>>()
        });

    // Use `Body::wrap_stream` to convert it to a `Body`...
    *response.body_mut() = Body::wrap_stream(mapping);
},
#         _ => unreachable!(),
#     }
#     response
# }
# fn main() {}
```

And like that, we have two echo routes: `/echo` which does no transformation,
and `/echo/uppercase` which returns all bytes after converting them to ASCII
uppercase.

## Buffering the Request Body

What if we want our echo service to reverse the data it received and send it
back to us? We can't really stream the data as it comes in, since we need to
find the end before we can respond. To do this, we can explore how to easily
collect the full body.

In this case, we can't really generate a `Response` immediately. Instead, we
must wait for the full request body to be received.

We want to concatenate the request body, and map the result into our `reverse` function, and return the eventual result. We can make use of the `hyper::body::to_bytes` utility function to make this easy.

```rust
# extern crate hyper;
# use hyper::{Body, Method, Request, Response};
# async fn echo(req: Request<Body>) -> Result<Response<Body>, hyper::Error> {
#     let mut response = Response::default();
#     match (req.method(), req.uri().path()) {
// Yet another route inside our match block...
(&Method::POST, "/echo/reverse") => {
    // Await the full body to be concatenated into a single `Bytes`...
    let full_body = hyper::body::to_bytes(req.into_body()).await?;

    // Iterate the full body in reverse order and collect into a new Vec.
    let reversed = full_body.iter()
        .rev()
        .cloned()
        .collect::<Vec<u8>>();

    *response.body_mut() = reversed.into();
},
#         _ => unreachable!(),
#     }
#     Ok(response)
# }
# fn main() {}
```

You can see a compiling [example here][example].

[example]: {{ site.examples_url }}/echo.rs
[future-crate]: https://github.com/rust-lang-nursery/futures-rs
