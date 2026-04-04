#!/usr/bin/env bash

cargo build --release --target x86_64-apple-darwin
cargo build --release --target aarch64-apple-darwin

lipo -create \
  target/x86_64-apple-darwin/release/libquicksilver.a \
  target/aarch64-apple-darwin/release/libquicksilver.a \
  -output libquicksilver_universal.a
