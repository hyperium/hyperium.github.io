---
title: Echo, echo, echo
---

You already have a [Hello World server](../hello-world)? Excellent! Usually,
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

Before we get started we need to add some new imports:

```rust
use hyper::body::Frame;
use hyper::{Method, StatusCode};
use http_body_util::{combinators::BoxBody, BodyExt};
# fn main() {}
```

Next, we need to make some changes to our `Service` function, but as you can see
it's still just an async function that takes a `Request` and returns a `Response`
future, and you can pass it to your server just like we did for the `hello` service.

Unlike our `hello` service where we didn't care about the request body and 
we always returned a single chunk of bytes containing our greeting, we're now
going to want a bit more freedom in how we shape our response `Body`. To achieve
this we will change the type of the `Body` in our `Response` to a boxed trait object. 
We only care that the response body implements the [Body](https://docs.rs/http-body/1.0.0-rc1/http_body/trait.Body.html) trait, that its data is `Bytes` and its error is a `hyper::Error`.

```rust
# use bytes::Bytes;
# use http_body_util::{combinators::BoxBody, BodyExt, Empty, Full};
# use hyper::{Method, Request, Response, StatusCode};
async fn echo(
    req: Request<hyper::body::Incoming>,
) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
    match (req.method(), req.uri().path()) {
        (&Method::GET, "/") => Ok(Response::new(full(
            "Try POSTing data to /echo",
        ))),
        (&Method::POST, "/echo") => {
            // we'll be back
        },

        // Return 404 Not Found for other routes.
        _ => {
            let mut not_found = Response::new(empty());
            *not_found.status_mut() = StatusCode::NOT_FOUND;
            Ok(not_found)
        }
    }
}
// We create some utility functions to make Empty and Full bodies
// fit our broadened Response body type.
fn empty() -> BoxBody<Bytes, hyper::Error> {
    Empty::<Bytes>::new()
        .map_err(|never| match never {})
        .boxed()
}
fn full<T: Into<Bytes>>(chunk: T) -> BoxBody<Bytes, hyper::Error> {
    Full::new(chunk.into())
        .map_err(|never| match never {})
        .boxed()
}
# fn main() {}
```

We built a super simple routing table just by matching on the `method` and `path` 
of an incoming `Request`. If someone requests `GET /`, our service will let them 
know they should try our echo powers out. We also check for `POST /echo`, but 
currently don't do anything about it.

Our third rule catches any other method and path combination, and changes the 
`StatusCode` of the `Response`. The default status of a `Response` is HTTP’s 
`200 OK` (`StatusCode::OK`), which is correct for the other routes. But the third 
case will instead send back `404 Not Found`.

## Body Streams

Now let's get that echo in place. An HTTP body is a stream of 
`Frames`, each [Frame](https://docs.rs/http-body/1.0.0-rc1/http_body/struct.Frame.html) 
containing parts of the `Body` data or trailers. So rather than reading the entire `Body` 
into a buffer before sending our response, we can stream each frame as it arrives. 
We'll start with the simplest solution, and then make alterations exercising more complex 
things you can do with the `Body` streams.

First up, plain echo. Both the `Request` and the `Response` have body streams,
and by default, you can easily pass the `Body` of the `Request` into a `Response`.

```rust
# use bytes::Bytes;
# use http_body_util::{combinators::BoxBody, BodyExt, Empty, Full};
# use hyper::{Method, Request, Response, StatusCode};
# async fn echo(
#    req: Request<hyper::body::Incoming>,
# ) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
#    match (req.method(), req.uri().path()) {
// Inside the match from before
(&Method::POST, "/echo") => Ok(Response::new(req.into_body().boxed())),
#        _ => unreachable!(),
#    }
# }
# fn main() {}
```

Running our server now will echo any data we `POST` to `/echo`. That was easy.
What if we wanted to uppercase all the text? We could use a `map` on our streams.

## Body mapping

Every data `Frame` of our body stream is a chunk of bytes, which we can conveniently
represent using the `Bytes` type from hyper. It can be easily converted into other
typical containers of bytes.

Next, let's add a new `/echo/uppercase` route, mapping each byte in the data `Frame`s
of our request body to uppercase, and returning the stream in our `Response`:

```rust
# use bytes::Bytes;
# use http_body_util::{combinators::BoxBody, BodyExt, Empty, Full};
# use hyper::body::Frame;
# use hyper::{Method, Request, Response, StatusCode};
# async fn echo(
#    req: Request<hyper::body::Incoming>,
# ) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
#    match (req.method(), req.uri().path()) {
// Yet another route inside our match block...
(&Method::POST, "/echo/uppercase") => {
    // Map this body's frame to a different type
    let frame_stream = req.into_body().map_frame(|frame| {
        let frame = if let Some(data) = frame.into_data() {
            // Convert every byte in every Data frame to uppercase
            data.iter()
                .map(|byte| byte.to_ascii_uppercase())
                .collect::<Bytes>()
        } else {
            Bytes::new()
        };

        Frame::data(frame)
    });

    Ok(Response::new(frame_stream.boxed()))
},
#         _ => unreachable!(),
#     }
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

We want to collect the entire request body and map the result into our `reverse` 
function, then return the eventual result. If we import the `http_body_util::BodyExt`
extension trait, we can call the `collect` method on our body, which will drive the
stream to completion, collecting all the data and trailer frames into a `Collected` type.
We can easily turn the `Collected` body into a single `Bytes` by calling its `into_bytes` 
method.

```rust
# use bytes::Bytes;
# use http_body_util::{combinators::BoxBody, BodyExt, Empty, Full};
# use hyper::{Method, Request, Response, StatusCode};
# async fn echo(
#    req: Request<hyper::body::Incoming>,
# ) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
#    match (req.method(), req.uri().path()) {
// Yet another route inside our match block...
(&Method::POST, "/echo/reversed") => {
    // Await the whole body to be collected into a single `Bytes`...
    let whole_body = req.collect().await?.to_bytes();

    // Iterate the whole body in reverse order and collect into a new Vec.
    let reversed_body = whole_body.iter()
        .rev()
        .cloned()
        .collect::<Vec<u8>>();

    Ok(Response::new(full(reversed_body)))
},
#         _ => unreachable!(),
#     }
# }
# fn main() {}
```

You can see a compiling [example here][example].

[example]: {{ site.examples_url }}/echo.rs
