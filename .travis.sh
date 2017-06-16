#!/bin/sh

if [ ! -d tmp ]; then
    cargo new tmp
    cat >> tmp/Cargo.toml <<-EOF
futures = "0.1.14"
hyper = "0.11"
hyper-tls = "0.1"
tokio-core = "0.1"
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
