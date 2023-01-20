const fs = require('fs');

const segmentFile = fs.readFileSync('./assets/segment_449kb_5sec.m2t');
const segmentFileData = Uint8Array.from(segmentFile);

module.exports = segmentFileData;