const initialSettings = {
    isLittleEndian: true,
    positionPid: 0,
    positionOffset: 2,
    positionLength: 6,
    positionPts: 10,
    positionDts: 14,
};

const getMetadataPacket = (instance, packetNumber = 0, settings = initialSettings) => {
    const packetNumberOffset = packetNumber * instance.exports.m_p_len.value;

    const instanceData = new Uint8ClampedArray(
        instance.exports.memory.buffer,
    );

    const metadata = instanceData.slice(
        instance.exports.m_offset.value,
        (
            instance.exports.m_offset.value +
            instance.exports.m_len.value
        ),
    );

    const metadataView = new DataView(metadata.buffer);

    return {
        pid: metadataView.getInt16(
            packetNumberOffset + settings.positionPid,
            settings.isLittleEndian,
        ),

        offset: metadataView.getInt32(
            packetNumberOffset + settings.positionOffset,
            settings.isLittleEndian,
        ),

        length: metadataView.getInt32(
            packetNumberOffset + settings.positionLength,
            settings.isLittleEndian,
        ),

        pts: metadataView.getInt32(
            packetNumberOffset + settings.positionPts,
            settings.isLittleEndian,
        ),

        dts: metadataView.getUint32(
            packetNumberOffset + settings.positionDts,
            settings.isLittleEndian,
        ),
    };
};

module.exports = {
    initialSettings,
    getMetadataPacket,
};