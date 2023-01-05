#!/bin/bash

source '.env'

wat2wasm ./src/mpeg2-ts.wat -o $BINARY_OUTPUT_PATH

echo "====="
echo "WASM"
echo "size: $(wc -c $BINARY_OUTPUT_PATH | awk '{print $1}') bytes"
echo "====="