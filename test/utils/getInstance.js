const fs = require('fs');

require('dotenv').config();

const file = fs.readFileSync(process.env.BINARY_OUTPUT_PATH);

const getInstance = () => {
  return WebAssembly.instantiate(file, {
      env: {
          log(value) {
              console.log('log:', value);
          },
      },
  })
    .then(({ instance }) => {
        return instance;
    });
};

const getDemuxedInstance = (instance, segment) => {
    instance.exports.malloc(segment.byteLength);

    const segmentBuffer = new Uint8ClampedArray(
        instance.exports.memory.buffer,
        instance.exports.s_offset.value,
    );

    segmentBuffer.set(segment);

    instance.exports.demux();

    return instance;
};

module.exports = {
    getInstance,
    getDemuxedInstance,
};