---
title: Advanced Client Usage
layout: guide
---

## POST
Now that we've seen how to make a GET request, let's look at how to make a POST request. This is useful when you need to send data to the server, such as when submitting a form or uploading a file.

To make a POST request, we'll need to change a few things from our GET request:

1. We'll set the method to POST.
2. We'll need to provide a request body.
3. We'll need to specify the type of data in our body by adding a `hyper::header::CONTENT_TYPE` header. 

For the body, we have a couple of options. We can use a simple string, a JSON string, or we can use raw bytes. Let's look at all three:

```rust
# extern crate http_body_util;
# extern crate hyper;
# extern crate hyper_util;
# extern crate tokio;
# use http_body_util::Empty;
# use hyper::body::Bytes;
# use hyper::Request;
# use hyper_util::rt::TokioIo;
# use tokio::net::TcpStream;
# async fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
# let url = "http://httpbin.org/ip".parse::<hyper::Uri>()?;
# let host = url.host().expect("uri has no host");
# let port = url.port_u16().unwrap_or(80);
# let addr = format!("{}:{}", host, port);
# let stream = TcpStream::connect(addr).await?;
# let io = TokioIo::new(stream);
# let (mut sender, conn) = hyper::client::conn::http1::handshake(io).await?;
# tokio::task::spawn(async move {
# if let Err(err) = conn.await {
# println!("Connection failed: {:?}", err);
# }
# });

// The authority of our URL will be the hostname of the httpbin remote
let authority = url.authority().unwrap().clone();

// For plain text
let req_body = Full::<Bytes>::from("Some plain text as a body.");
let req = Request::builder()
    .method(hyper::Method::POST)
    .header(hyper::header::HOST, authority.as_str())
    .header(hyper::header::CONTENT_TYPE, "text/plain")
    .body(req_body)?;

// For JSON data
let json_data = r#"{"key": "value"}"#;
let req_body = Full::<Bytes>::from(json_data);
let req = Request::builder()
    .method(hyper::Method::POST)
    .header(hyper::header::HOST, authority.as_str())
    .header(hyper::header::CONTENT_TYPE, "application/json")
    .body(req_body)?;

// For binary data
let binary_data = vec![0u8; 128]; // Example binary data
let req_body = Full::<Bytes>::from(binary_data);
let req = Request::builder()
    .method(hyper::Method::POST)
    .header(hyper::header::HOST, authority.as_str())
    .header(hyper::header::CONTENT_TYPE, "application/octet-stream")
    .body(req_body)?;


let res = sender.send_request(req).await?;

println!("Response status: {}", res.status());
# Ok(())
# }
# fn main() {}
```