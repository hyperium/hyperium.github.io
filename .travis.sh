#!/bin/sh

if [ ! -d tmp ]; then
    cargo new tmp
    cat >> tmp/Cargo.toml <<-EOF
hyper = { git = "https://github.com/hyperium/hyper" }
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
