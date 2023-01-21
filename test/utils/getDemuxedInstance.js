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
    getDemuxedInstance,
};