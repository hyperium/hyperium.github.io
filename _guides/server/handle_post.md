---
title: Handling Posts
layout: guide
---

## Overview

A common use case is to have a web page Post to the server a chunk of
data. The data could be, for example, html form data, or Json
submitted by XmlHttpRequest. The server will parse and validate the
data, process it (possibly including service calls to a database or
web service), and render a response. Responses can include web pages,
images, or chunks of Json. A basic example of form processing is
included in the hyper distribution,
[params.rs](https://github.com/hyperium/hyper/blob/master/examples/params.rs). We
will start by discussing key aspects of that example, then address how
to modify the approach for handling other types of posted data and
rendered responses.

The basic approach to handling posts is to take the request body
(which implements `futures::stream::Stream`) and apply a series of
adapters until it is transformed into response future
(`Service::Future`, which is `Box<Future<Item = Self::Response, Error
= Self::Error>>` in the `params.rs` example). While it appears easier
to transform the request body directly into the response body, that
approach makes it difficult to exit early if there is a problem, such
as a malformed request or a service is unavailable. Small quickly
rendered response bodies can be generated as part of the response
future. Larger responses that may take time to stream to the client
will need to be generated in a separate stream from the response body.

## Setup

The basic structure of the `'params.rs` example is the same as in the
[Echo, echo, echo](echo.md) guide. Aside from handling Post, which we
discuss below, the key differences are:

Import the `url` crate for form parsing:

```rust
extern crate url;
use url::form_urlencoded;
# fn main() {}
```

Define some strings for the form we wish to process, and some error
responses:

```rust
static INDEX: &[u8] = b"<html><body><form action=\"post\" method=\"post\">Name: <input type=\"text\" name=\"name\"><br>Number: <input type=\"text\" name=\"number\"><br><input type=\"submit\"></body></html>";
static MISSING: &[u8] = b"Missing field";
static NOTNUMERIC: &[u8] = b"Number field is not numeric";
```

## Parsing the Request Body

```rust
# extern crate futures;
# extern crate hyper;
# use hyper::Method::Post;
# use hyper::{Request, Response};
# use hyper::server::Service;
# use futures::{Future, Stream};
# struct ParamExample;
# impl Service for ParamExample {
#     type Request = Request;
#     type Response = Response;
#     type Error = hyper::Error;
#     type Future = Box<Future<Item = Self::Response, Error = Self::Error>>;
#     fn call(&self, req: Request) -> Self::Future {
#          match (req.method(), req.path()) {
		    (&Post, "/post") => {
			    Box::new(req.body().concat2().
				    map(|b| {
					    // see below
#					    Response::new().with_body("filler to compile")
				    }))
	        },
#			(_, _) => Box::new(futures::future::ok(Response::new().with_body("filler to compile")))
# 	    }
# 	}
# }
# fn main() {}
```

First concat the request body into a future containing the entire
request body, since we cannot do anything useful until all the data is
available. Then we map the body into our response, which is the main
engine of Post handling.


```rust
# extern crate hyper;
# extern crate url;
# use url::form_urlencoded;
# use std::collections::HashMap;
# use hyper::Chunk;
# fn main() {
# let b = Chunk::from("some data");
    let params = form_urlencoded::parse(b.as_ref()).into_owned().collect::<HashMap<String, String>>();
#	}
```

Parse the request body. `form_urlencoded::parse` always succeeds, so
we can directly collect our form data into a HashMap. Note that this
is a simplified use case. In principle names can appear multiple times
in a form, and the values should be rolled up into a HashMap<String,
Vec<String>>. However in this example the simpler approach is
sufficient.


```rust
# extern crate futures;
# extern crate hyper;
# extern crate url;
# use hyper::header::ContentLength;
# use hyper::{Post, Request, Response, StatusCode};
# use hyper::server::Service;
# use futures::{Future, Stream};
# use std::collections::HashMap;
# use url::form_urlencoded;

static MISSING: &[u8] = b"Missing field";
static NOTNUMERIC: &[u8] = b"Number field is not numeric";

# struct ParamExample;
# impl Service for ParamExample {
#     type Request = Request;
#     type Response = Response;
#     type Error = hyper::Error;
#     type Future = Box<Future<Item = Self::Response, Error = Self::Error>>;
#     fn call(&self, req: Request) -> Self::Future {
#          match (req.method(), req.path()) {
#		    (&Post, "/post") => {
#			    Box::new(req.body().concat2().
#				    map(|b| {
#                       let params = form_urlencoded::parse(b.as_ref()).into_owned().collect::<HashMap<String, String>>();
    let name = if let Some(n) = params.get("name") {
        n
    } else {
        return Response::new()
            .with_status(StatusCode::UnprocessableEntity)
            .with_header(ContentLength(MISSING.len() as u64))
            .with_body(MISSING);
    };
    let number = if let Some(n) = params.get("number") {
        if let Ok(v) = n.parse::<f64>() {
            v
        } else {
            return Response::new()
                .with_status(StatusCode::UnprocessableEntity)
                .with_header(ContentLength(NOTNUMERIC.len() as u64))
                .with_body(NOTNUMERIC);
        }
    } else {
        return Response::new()
            .with_status(StatusCode::UnprocessableEntity)
            .with_header(ContentLength(MISSING.len() as u64))
            .with_body(MISSING);
    };
#					    Response::new().with_body("filler to compile")
#				    }))
#	        },
#			(_, _) => Box::new(futures::future::ok(Response::new().with_body("filler to compile")))
# 	    }
# 	}
# }
# fn main() {}
```

Here we validate the submitted data, verifying the expected fields are
present, and that the numeric field is in fact a number. If that is
not the case we exit early with an appropriate `StatusCode`.

### Handling Json and Other Data Types

Parsing other data types follows the same pattern, although parsing
may fail. Even if you are certain your client side code will always
submit valid data, you have no garantee a Post came from your
client. To parse a Json Post:

```rust
# extern crate hyper;
# extern crate serde_json;
# use hyper::{Response, StatusCode};
# use hyper::header::ContentLength;
# fn f(b: &str) -> Response {
    let bad_request: &[u8] = b"Missing field";
    let json: serde_json::Value = if let Ok(j) = serde_json::from_slice(b.as_ref()) {
	    j
    } else {
        return Response::new()
            .with_status(StatusCode::BadRequest)
            .with_header(ContentLength(bad_request.len() as u64))
            .with_body(bad_request);
	};
# 	Response::new().with_body("filler to compile")
# }
# fn main() {}
```

## Generating the Response Body

```rust
# extern crate futures;
# extern crate hyper;
# use hyper::Method::Post;
# use hyper::header::ContentLength;
# use hyper::{Request, Response};
# use hyper::server::Service;
# use futures::{Future, Stream};
# struct ParamExample;
# impl Service for ParamExample {
#     type Request = Request;
#     type Response = Response;
#     type Error = hyper::Error;
#     type Future = Box<Future<Item = Self::Response, Error = Self::Error>>;
#     fn call(&self, req: Request) -> Self::Future {
#          match (req.method(), req.path()) {
#		    (&Post, "/post") => {
#			    Box::new(req.body().concat2().
#				    map(|b| {
#					    let name = "M. Filler Text";
#                       let number = 42;
    let body = format!("Hello {}, your number is {}", name, number);
    Response::new()
        .with_header(ContentLength(body.len() as u64))
        .with_body(body)
# }))
#	        },
#			(_, _) => Box::new(futures::future::ok(Response::new().with_body("filler to compile")))
# 	    }
# 	}
# }
# fn main() {}
```

Finally we generate the response body. In this case the body is a
simple string. More complex approaches, such as database queries or
web service calls, are addressed in the [Response
Strategies](response_strategies.md) guide.
