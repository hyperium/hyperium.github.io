---
title: Response Strategies
layout: guide
---

## Overview

The [Echo, echo, echo](echo.md) guide discusses how to transform
request bodies into response bodies, and the [Handling
Posts](handle_post.md) guide discusses processing more complex request
bodies. We will now look into more advanced ways of generating
responses.

Two basic approaches are examined. The first handles blocking i/o or
long processing times. These require a separate thread and the
`futures` crate's channels. We will discuss the threaded approach in
the context of serving files to a client, but this is readily adapted
to database access and/or complex page rendering. A working example of
file serving is included in the hyper distribution at
[send_file.rs](https://github.com/hyperium/hyper/blob/master/examples/send_file.rs).

The second approach illustrates how to use `tokio` aware i/o. We will
illustrate it by accessing a simple web based api. In some ways this
is simpler than the threaded approach, but the setup of our server is
more complex. We will need access to the underlying `tokio` engine to
handle our queries. A working example of web api access is included in
the hyper distribution at
[web_api.rs](https://github.com/hyperium/hyper/blob/master/examples/web_api.rs).

We start with extracting the query information from the request (which
can be from form parameters, cookies, headers, etc, but this guide
will simply use the request path). This information is used to create
the response future (`Service::Future`, which is `Box<Future<Item =
Self::Response, Error = Self::Error>>` here). Finally, the response
body stream is assigned.

All the operations that can affect the response status code need to
take place in the response future, not the response body stream. The
response body stream cannot change the status of the response. For
example, if that stream tries to open a file that does not exist, it
cannot return a 404. The file needs to be opened before the body
stream is created and the handle passed to the stream.

## File Serving

At the time of this writing, there is no cross platform way of
accessing the filesystem with futures. We will use blocking I/O in a
separate thread. This generalizes to anything that needs to run in a
separate thread, such as database access or long computations.

### Simple File Serving

We will start with a simple approach that reads the entire file into a
buffer. This is only appropriate for small quanities of data, such as
a single data base row, or situations where all the long processing
takes place before the buffer is generated.

```rust
# extern crate futures;
# extern crate hyper;
# use futures::Future;
# use futures::sync::oneshot;
# use hyper::Response;
# use hyper::error::Error;
# use std::io;
# use std::thread;
fn simple_file_send(f: &str) -> Box<Future<Item = Response, Error = hyper::Error>> {
    let filename = f.to_string(); // we need to copy for lifetime issues
    let (tx, rx) = oneshot::channel();
#	thread::spawn(move || {tx.send(Response::new().with_body("filler to compile"))});
#   Box::new(rx.map_err(|e| Error::from(io::Error::new(io::ErrorKind::Other, e))))
# }
# fn main() {}
```

For small files, we can do all the work with a single
`futures::sync::oneshot::channel` to communicate with our spawned
thread.


```rust
# extern crate futures;
# extern crate hyper;
# use futures::Future;
# use futures::sync::oneshot;
# use hyper::header::ContentLength;
# use hyper::{Response, StatusCode};
# use hyper::error::Error;
# use std::io;
# use std::fs::File;
# use std::thread;
# fn simple_file_send(f: &str) -> Box<Future<Item = Response, Error = hyper::Error>> {
#    let filename = f.to_string(); // we need to copy for lifetime issues
#    let (tx, rx) = oneshot::channel();
    thread::spawn(move || {
	    let not_found: &[u8] = b"not found";
        let mut file = match File::open(filename) {
            Ok(f) => f,
            Err(_) => {
                tx.send(Response::new()
                        .with_status(StatusCode::NotFound)
                        .with_header(ContentLength(not_found.len() as u64))
                        .with_body(not_found))
                    .expect("Send error on open");
                return;
            },
        };
#	});
#   Box::new(rx.map_err(|e| Error::from(io::Error::new(io::ErrorKind::Other, e))))
# }
# fn main() {}
```

First, we attempt to open the file, returning a 404 if the file does
not exist.

```rust
# extern crate futures;
# extern crate hyper;
# use futures::Future;
# use futures::sync::oneshot;
# use hyper::header::ContentLength;
# use hyper::{Response, StatusCode};
# use hyper::error::Error;
# use std::io::{self, copy};
# use std::fs::File;
# use std::thread;
# fn simple_file_send(f: &str) -> Box<Future<Item = Response, Error = hyper::Error>> {
#    let filename = f.to_string(); // we need to copy for lifetime issues
#    let (tx, rx) = oneshot::channel();
#    thread::spawn(move || {
#        let mut file = File::open(filename).unwrap();
        let mut buf: Vec<u8> = Vec::new();
        match copy(&mut file, &mut buf) {
            Ok(_) => {
                let res = Response::new()
                    .with_header(ContentLength(buf.len() as u64))
                    .with_body(buf);
                tx.send(res).expect("Send error on successful file read");
            },
            Err(_) => {
                tx.send(Response::new().with_status(StatusCode::InternalServerError)).
                    expect("Send error on error reading file");
            },
        };
    });
#   Box::new(rx.map_err(|e| Error::from(io::Error::new(io::ErrorKind::Other, e))))
# }
# fn main() {}
```

Next we read whole file into a `Vec<u8>` buffer. We send a Response
with the buffer as the body out the transmit channel. On an error, we
instead return an Internal Service Error.

```rust
# extern crate futures;
# extern crate hyper;
# use futures::Future;
# use futures::sync::oneshot;
# use hyper::Response;
# use hyper::error::Error;
# use std::io;
# use std::thread;
# fn simple_file_send(f: &str) -> Box<Future<Item = Response, Error = hyper::Error>> {
#    let filename = f.to_string(); // we need to copy for lifetime issues
#    let (tx, rx) = oneshot::channel();
#	thread::spawn(move || {tx.send(Response::new().with_body("filler to compile"))});
    Box::new(rx.map_err(|e| Error::from(io::Error::new(io::ErrorKind::Other, e))))
}
# fn main() {}
```

Finally, we box the receive side of the channel as the Response
future. Note that we need to map the channel's error to a
`hyper::Error`.

There are two principle drawbacks to this approach. First, since we
read the entire file into memory, serving many large files has the
potential to exhaust our memory. Second, we cannot start sending data
until the file has been read, increasing the latency of our response
for larger files.

### Streaming Files

We can address the problem of the single channel approach by using a
second `mpsc::channel` to stream the file in smaller chunks. We need
to use two channels because the Response body stream cannot change the
status of the Response, but some i/o operations, e.g. `File::open`,
may return errors requiring a different response. These operations all
need to take place before the Response future is sent over the
oneshot, before the loop that streams the Response body is started.

```rust
# extern crate futures;
# extern crate hyper;
# use futures::Future;
# use futures::sync::oneshot;
# use hyper::header::ContentLength;
# use hyper::{Response, StatusCode};
# use hyper::error::Error;
# use std::io;
# use std::fs::File;
# use std::thread;
fn stream_file(f: &str) -> Box<Future<Item = Response, Error = hyper::Error>> {
    let filename = f.to_string(); // we need to copy for lifetime issues
    let (tx, rx) = oneshot::channel();
    thread::spawn(move || {
	    let not_found: &[u8] = b"not found";
        let mut file = match File::open(filename) {
            Ok(f) => f,
            Err(_) => {
                tx.send(Response::new()
                        .with_status(StatusCode::NotFound)
                        .with_header(ContentLength(not_found.len() as u64))
                        .with_body(not_found))
                    .expect("Send error on open");
                return;
            },
        };
#	});
#   Box::new(rx.map_err(|e| Error::from(io::Error::new(io::ErrorKind::Other, e))))
# }
# fn main() {}
```

We begin the same as the simple approach.

```rust
# extern crate futures;
# extern crate hyper;
# use futures::Future;
# use futures::sync::{mpsc, oneshot};
# use hyper::header::ContentLength;
# use hyper::{Response, StatusCode};
# use hyper::error::Error;
# use std::io::{self, copy};
# use std::fs::File;
# use std::thread;
# fn simple_file_send(f: &str) -> Box<Future<Item = Response, Error = hyper::Error>> {
#    let filename = f.to_string(); // we need to copy for lifetime issues
#    let (tx, rx) = oneshot::channel();
#    thread::spawn(move || {
#        let mut file = File::open(filename).unwrap();
        let (mut tx_body, rx_body) = mpsc::channel(1);
        let res = Response::new().with_body(rx_body);
        tx.send(res).expect("Send error on successful file read");
#	});
#   Box::new(rx.map_err(|e| Error::from(io::Error::new(io::ErrorKind::Other, e))))
# }
# fn main() {}
```

Here we create an `mpsc::channel` for the response body. We create a
Response with the receive side of the `mpsc::channel` as the body, and
send it out the `oneshot::channel`.


```rust
# extern crate futures;
# extern crate hyper;
# use futures::{Future, Sink};
# use futures::sync::{mpsc, oneshot};
# use hyper::header::ContentLength;
# use hyper::{Chunk, Response, StatusCode};
# use hyper::error::Error;
# use std::io::{self, Read};
# use std::fs::File;
# use std::thread;
# fn simple_file_send(f: &str) -> Box<Future<Item = Response, Error = hyper::Error>> {
#    let filename = f.to_string(); // we need to copy for lifetime issues
#    let (tx, rx) = oneshot::channel();
#    thread::spawn(move || {
#        let mut file = File::open(filename).unwrap();
#        let (mut tx_body, rx_body) = mpsc::channel(1);
#        let res = Response::new().with_body(rx_body);
#        tx.send(res).expect("Send error on successful file read");
        let mut buf = [0u8; 4096];
        loop {
            match file.read(&mut buf) {
                Ok(n) => {
                    if n == 0 {
                        // eof
                        tx_body.close().expect("panic closing");
                        break;
                    } else {
                        let chunk: Chunk = buf.to_vec().into();
                        match tx_body.send(Ok(chunk)).wait() {
                            Ok(t) => { tx_body = t; },
                            Err(_) => { break; }
                        };
                    }
                },
                Err(_) => { break; }
            }
        }
    });
    Box::new(rx.map_err(|e| Error::from(io::Error::new(io::ErrorKind::Other, e))))
}
# fn main() {}
```

We create a buffer, and loop through file sending buffer sized chunks
until we reach the end of the file. On errors we simply exit the
thread, but in practice some sort of logging would be appropriate.
Finally, we box up the receive channel of the oneshot as in the simple
case.

When in doubt, use the two channel streaming approach. This will work
with small data quanities at a small overhead cost, and scale safely
to large quantities of data.

## Web Services

Using `tokio` aware i/o removes the need for separate
threads. However, building the server is more complex so we can pass a
handle to the tokio reactor to our service. Our service needs this
handle to launch `tokio` based i/o.

Mapping the responses to our web queries to the bodies of our
responses does not result in a `hyper::Body`. The most straightforward
way of dealing with this is to use a trait object as the body type of
our Service::Response.

### The ResponseExamples Service

We need a handle to a tokio reactor to create web queries, so we make
it part of our `Service`:

```rust
# extern crate tokio_core;
struct ResponseExamples(tokio_core::reactor::Handle);
```

The various transforms we need to perfom on our web request streams to
get to our response body streams result in some fairly complex
types. The easiest way to deal with these is to define our
Service::Response to use a trait object instead of `hyper::Body`. Our
code will be more clear if we define this as a type:

```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use futures::{Future, Stream};
# use hyper::{Body, Chunk, Request, Response, Error};
# use hyper::server::Service;
pub type ResponseStream = Box<Stream<Item=Chunk, Error=Error>>;

# struct ResponseExamples(tokio_core::reactor::Handle);
impl Service for ResponseExamples {
    type Request = Request;
    type Response = Response<ResponseStream>;
    type Error = hyper::Error;
    type Future = Box<Future<Item = Self::Response, Error = Self::Error>>;
#    fn call(&self, req: Request) -> Self::Future {
#        let body: ResponseStream = Box::new(Body::from("filler to compile"));
#        Box::new(futures::future::ok(Response::new().with_body(body)))
#    }
# }
# fn main() {}
```

Since `hyper::Body` implements `Stream<Item=Chunk, Error=Error>`, it
can be easily converted to this type with `Box`, for example:

```rust
# extern crate futures;
# extern crate hyper;
# use futures::Stream;
# use hyper::{Body, Chunk, Error};
# pub type ResponseStream = Box<Stream<Item=Chunk, Error=Error>>;
# fn main() {
let body: ResponseStream = Box::new(Body::from("A simple response"));
# }
```

#### /web_api

For the purposes of this example, we will include a web api to test
against, but normally one would connect to a different service. Our
web api is a simple uppercasing as discussed in [Echo, echo,
echo](echo.md):

```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use futures::{Future, Stream};
# use hyper::{Body, Chunk, Post, Request, Response, Error};
# use hyper::server::Service;
# use std::ascii::AsciiExt;
# pub type ResponseStream = Box<Stream<Item=Chunk, Error=Error>>;
# struct ResponseExamples(tokio_core::reactor::Handle);
# impl Service for ResponseExamples {
#    type Request = Request;
#    type Response = Response<ResponseStream>;
#    type Error = hyper::Error;
#    type Future = Box<Future<Item = Self::Response, Error = Self::Error>>;
#    fn call(&self, req: Request) -> Self::Future {
#          match (req.method(), req.path()) {
            (&Post, "/web_api") => {
                let body: ResponseStream = Box::new(req.body().map(|chunk| {
                    let upper = chunk.iter()
                        .map(|byte| byte.to_ascii_uppercase())
                        .collect::<Vec<u8>>();
                    Chunk::from(upper)
                }));
                Box::new(futures::future::ok(Response::new().with_body(body)))
            },
#			(_, _) => {
#               let body: ResponseStream = Box::new(Body::from("filler to compile"));
#               Box::new(futures::future::ok(Response::new().with_body(body)))
#           }
# 	    }
# 	}
# }
# fn main() {}
```

#### /test.html

Here we make our query to a web service.

```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use futures::{Future, Stream};
# use hyper::{Body, Chunk, Client, Get, Post, Request, Response, Error};
# use hyper::server::Service;
# pub type ResponseStream = Box<Stream<Item=Chunk, Error=Error>>;
static LOWERCASE: &[u8] = b"i am a lower case string";

# struct ResponseExamples(tokio_core::reactor::Handle);
# impl Service for ResponseExamples {
#    type Request = Request;
#    type Response = Response<ResponseStream>;
#    type Error = hyper::Error;
#    type Future = Box<Future<Item = Self::Response, Error = Self::Error>>;
#    fn call(&self, req: Request) -> Self::Future {
#          match (req.method(), req.path()) {
            (&Get, "/test.html") => {
                let client = Client::configure().build(&self.0);
                let mut req = Request::new(Post, "http://127.0.0.1:1337/web_api".parse().unwrap());
                req.set_body(LOWERCASE);
                let web_res_future = client.request(req);
#                Box::new(web_res_future.map(|web_res| {
#                    let body: ResponseStream = Box::new(web_res.body().map(|b| {
#                        Chunk::from(format!("before: '{:?}'<br>after: '{:?}'",
#                                            std::str::from_utf8(LOWERCASE).unwrap(),
#                                            std::str::from_utf8(&b).unwrap()))
#                    }));
#                    Response::new().with_body(body)
#                }))
#            },
#			(_, _) => {
#               let body: ResponseStream = Box::new(Body::from("filler to compile"));
#               Box::new(futures::future::ok(Response::new().with_body(body)))
#           }
# 	    }
# 	}
# }
# fn main() {}
```

We start by creating a hyper client with a post request. Client
programming is discussed in detail in the Client portion of these
guides. The [Advanced Client Usage](../client/advanced.md) page discusses
how to create and process Posts. Since we already have a handle to the
tokio reactor, we do not need to create one here. `web_res_future` is
a Future containing the results of our query.

```rust
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use futures::{Future, Stream};
# use hyper::{Body, Chunk, Client, Get, Post, Request, Response, Error};
# use hyper::server::Service;
# pub type ResponseStream = Box<Stream<Item=Chunk, Error=Error>>;
# static LOWERCASE: &[u8] = b"i am a lower case string";
# struct ResponseExamples(tokio_core::reactor::Handle);
# impl Service for ResponseExamples {
#    type Request = Request;
#    type Response = Response<ResponseStream>;
#    type Error = hyper::Error;
#    type Future = Box<Future<Item = Self::Response, Error = Self::Error>>;
#    fn call(&self, req: Request) -> Self::Future {
#          match (req.method(), req.path()) {
#            (&Get, "/test.html") => {
#                let lowercase = b"i am a lower case string";
#                let client = Client::configure().build(&self.0);
#                let mut req = Request::new(Post, "http://127.0.0.1:1337/web_api".parse().unwrap());
#                req.set_body(LOWERCASE);
#                let web_res_future = client.request(req);
                Box::new(web_res_future.map(|web_res| {
                    let body: ResponseStream = Box::new(web_res.body().map(|b| {
                        Chunk::from(format!("before: '{:?}'<br>after: '{:?}'",
                                            std::str::from_utf8(LOWERCASE).unwrap(),
                                            std::str::from_utf8(&b).unwrap()))
                    }));
                    Response::new().with_body(body)
                }))
            },
#			(_, _) => {
#               let body: ResponseStream = Box::new(Body::from("filler to compile"));
#               Box::new(futures::future::ok(Response::new().with_body(body)))
#           }
# 	    }
# 	}
# }
# fn main() {}
```

Here we map the `web_res_future` into a `Response`. Within that
mapping, we map the web query's body into a body for our
`Response`. In this case it is a simple before and after
comparison. We `Box` the `Response` and return it as our result.

In this example, any errors in `web_res_future` are simply passed on
in our response. More robust design would unpack those errors and set
appropriate status codes. Retries or default responses may also be
implemented depending on the application.

### Building the Server

In earlier examples, we could let Http::bind take care of creating and
running the tokio objects. However, since we wish to create outgoing
http connections in addition to handling incoming, we need to set
things up ourselves.

```rust,no_run
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use futures::{Future, Stream};
# use hyper::{Body, Chunk, Request, Response, Error};
# use hyper::server::{Http, Service};
# pub type ResponseStream = Box<Stream<Item=Chunk, Error=Error>>;
# struct ResponseExamples(tokio_core::reactor::Handle);
# impl Service for ResponseExamples {
#    type Request = Request;
#    type Response = Response<ResponseStream>;
#    type Error = hyper::Error;
#    type Future = Box<Future<Item = Self::Response, Error = Self::Error>>;
#    fn call(&self, req: Request) -> Self::Future {
#        let body: ResponseStream = Box::new(Body::from("filler to compile"));
#        Box::new(futures::future::ok(Response::new().with_body(body)))
#    }
# }
# fn main() {
    let addr = "127.0.0.1:1337".parse().unwrap();
    let mut core = tokio_core::reactor::Core::new().unwrap();
    let server_handle = core.handle();
    let client_handle = core.handle();
#    let serve = Http::new().serve_addr_handle(&addr, &server_handle, move || Ok(ResponseExamples(client_handle.clone()))).unwrap();
#    println!("Listening on http://{} with 1 thread.", serve.incoming_ref().local_addr());
#    let h2 = server_handle.clone();
#    server_handle.spawn(serve.for_each(move |conn| {
#        h2.spawn(conn.map(|_| ()).map_err(|err| println!("serve error: {:?}", err)));
#        Ok(())
#    }).map_err(|_| ()));
#    core.run(futures::future::empty::<(), ()>()).unwrap();
# }
```

Create the tokio core. `server_handle` is for server support handled
by `Http::bind` in other guides. `client_handle` is the `Core` handle
that we will use when creating web requests.

```rust,no_run
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use futures::{Future, Stream};
# use hyper::{Body, Chunk, Request, Response, Error};
# use hyper::server::{Http, Service};
# pub type ResponseStream = Box<Stream<Item=Chunk, Error=Error>>;
# struct ResponseExamples(tokio_core::reactor::Handle);
# impl Service for ResponseExamples {
#    type Request = Request;
#    type Response = Response<ResponseStream>;
#    type Error = hyper::Error;
#    type Future = Box<Future<Item = Self::Response, Error = Self::Error>>;
#    fn call(&self, req: Request) -> Self::Future {
#        let body: ResponseStream = Box::new(Body::from("filler to compile"));
#        Box::new(futures::future::ok(Response::new().with_body(body)))
#    }
# }
# fn main() {
#    let addr = "127.0.0.1:1337".parse().unwrap();
#    let mut core = tokio_core::reactor::Core::new().unwrap();
#    let server_handle = core.handle();
#    let client_handle = core.handle();
    let serve = Http::new().serve_addr_handle(&addr, &server_handle, move || Ok(ResponseExamples(client_handle.clone()))).unwrap();
    println!("Listening on http://{} with 1 thread.", serve.incoming_ref().local_addr());
#    let h2 = server_handle.clone();
#    server_handle.spawn(serve.for_each(move |conn| {
#        h2.spawn(conn.map(|_| ()).map_err(|err| println!("serve error: {:?}", err)));
#        Ok(())
#    }).map_err(|_| ()));
#    core.run(futures::future::empty::<(), ()>()).unwrap();
# }
```

Set up the `serve` `Stream`, which is a `futures::stream::Stream` of
`Connections`.


```rust,no_run
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use futures::{Future, Stream};
# use hyper::{Body, Chunk, Request, Response, Error};
# use hyper::server::{Http, Service};
# pub type ResponseStream = Box<Stream<Item=Chunk, Error=Error>>;
# struct ResponseExamples(tokio_core::reactor::Handle);
# impl Service for ResponseExamples {
#    type Request = Request;
#    type Response = Response<ResponseStream>;
#    type Error = hyper::Error;
#    type Future = Box<Future<Item = Self::Response, Error = Self::Error>>;
#    fn call(&self, req: Request) -> Self::Future {
#        let body: ResponseStream = Box::new(Body::from("filler to compile"));
#        Box::new(futures::future::ok(Response::new().with_body(body)))
#    }
# }
# fn main() {
#    let addr = "127.0.0.1:1337".parse().unwrap();
#    let mut core = tokio_core::reactor::Core::new().unwrap();
#    let server_handle = core.handle();
#    let client_handle = core.handle();
#    let serve = Http::new().serve_addr_handle(&addr, &server_handle, move || Ok(ResponseExamples(client_handle.clone()))).unwrap();
#    println!("Listening on http://{} with 1 thread.", serve.incoming_ref().local_addr());
    let h2 = server_handle.clone();
    server_handle.spawn(serve.for_each(move |conn| {
        h2.spawn(conn.map(|_| ()).map_err(|err| println!("serve error: {:?}", err)));
        Ok(())
    }).map_err(|_| ()));
#    core.run(futures::future::empty::<(), ()>()).unwrap();
# }
```

Set up processing for each incoming connection.


```rust,no_run
# extern crate futures;
# extern crate hyper;
# extern crate tokio_core;
# use futures::{Future, Stream};
# use hyper::{Body, Chunk, Request, Response, Error};
# use hyper::server::{Http, Service};
# pub type ResponseStream = Box<Stream<Item=Chunk, Error=Error>>;
# struct ResponseExamples(tokio_core::reactor::Handle);
# impl Service for ResponseExamples {
#    type Request = Request;
#    type Response = Response<ResponseStream>;
#    type Error = hyper::Error;
#    type Future = Box<Future<Item = Self::Response, Error = Self::Error>>;
#    fn call(&self, req: Request) -> Self::Future {
#        let body: ResponseStream = Box::new(Body::from("filler to compile"));
#        Box::new(futures::future::ok(Response::new().with_body(body)))
#    }
# }
# fn main() {
#    let addr = "127.0.0.1:1337".parse().unwrap();
#    let mut core = tokio_core::reactor::Core::new().unwrap();
#    let server_handle = core.handle();
#    let client_handle = core.handle();
#    let serve = Http::new().serve_addr_handle(&addr, &server_handle, move || Ok(ResponseExamples(client_handle.clone()))).unwrap();
#    println!("Listening on http://{} with 1 thread.", serve.incoming_ref().local_addr());
#    let h2 = server_handle.clone();
#    server_handle.spawn(serve.for_each(move |conn| {
#        h2.spawn(conn.map(|_| ()).map_err(|err| println!("serve error: {:?}", err)));
#        Ok(())
#    }).map_err(|_| ()));
    core.run(futures::future::empty::<(), ()>()).unwrap();

# }
```

Run the Core to listen for connections.
