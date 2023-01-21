#!/bin/bash

source '.env'

# wat modules concatenation

declare -a wat_modules_array=(
    # it should be first
    ./src/_main.wat

    ./src/mpeg2-ts.wat
    ./src/h264.wat
    ./src/adts.wat
    ./src/fmp4.wat
)

rm -rf ./tmp
mkdir ./tmp
touch ./tmp/output.wat

for wat_module in "${wat_modules_array[@]}"
do
   cat $wat_module | sed '1,1d' | sed '$d' 1>> ./tmp/output.wat
done

echo -e "(module\n$(cat ./tmp/output.wat)" > ./tmp/output.wat
echo ")" >> ./tmp/output.wat

# compilation

wat2wasm ./tmp/output.wat -o $BINARY_OUTPUT_PATH

echo "====="
echo "WASM"
echo "size: $(wc -c $BINARY_OUTPUT_PATH | awk '{print $1}') bytes"
echo "====="