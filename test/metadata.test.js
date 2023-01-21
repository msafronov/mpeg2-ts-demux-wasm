const { getInstance } = require('./utils/getInstance');
const { getDemuxedInstance  } = require('./utils/getDemuxedInstance');
const { getMetadataPacket } = require('./utils/getMetadataPacket');

const segment_449kb_5sec = require('./mocks/segment_449kb_5sec');

describe('metadata memory block', () => {
    describe('segment_449kb_5sec', () => {
        it('should be correct (packet number = 0)', async () => {
            const instance = await getInstance();
            const demuxedInstance = getDemuxedInstance(instance, segment_449kb_5sec);

            const metadataPacket = getMetadataPacket(demuxedInstance);
    
            expect(metadataPacket).toStrictEqual({
                pid: 256,
                offset: 655360,
                length: 23762,
                pts: 132006,
                dts: 126000,
            });
        });

        it('should be correct (packet number = 25)', async () => {
            const instance = await getInstance();
            const demuxedInstance = getDemuxedInstance(instance, segment_449kb_5sec);

            const packetNumber = 25;

            const metadataPacket = getMetadataPacket(demuxedInstance, packetNumber);
    
            expect(metadataPacket).toStrictEqual({
                pid: 257,
                offset: 743119,
                length: 235,
                pts: 162726,
                dts: 195069,
            });
        });
    });
});