#!/bin/sh

if [ ! -e tmp/Cargo.toml ]; then
    if [ ! -d tmp ]; then
        cargo new tmp
    else
        cargo init tmp
    fi
    cat >> tmp/Cargo.toml <<-EOF
futures = "0.1.14"
hyper = "0.11"
hyper-tls = "0.1"
tokio-core = "0.1"
service-fn = { git = "https://github.com/tokio-rs/service-fn" }
EOF
    cargo build --manifest-path tmp/Cargo.toml
fi

status=0
for f in `git ls-files | grep '\.md$'`; do
    echo $f
    rustdoc --test $f -L tmp/target/debug/deps
    s=$?
    if [ "$s" != "0" ]; then
        status=$s
    fi
done

exit $status
