const path = require('path');
const express = require('express');
const cors = require('cors');
const compression = require('compression');

require('dotenv').config();

const app = express();

app.use(cors());
app.use(compression());
app.use(express.static(path.join(__dirname)));
app.use('/assets', express.static(path.join(__dirname, '../assets')));

app.get('/mpeg2-ts-demux.wasm', (req, res) => {
  return res.sendFile(path.join(__dirname, '..', process.env.BINARY_OUTPUT_PATH));
});

app.listen(5000, () => {
  console.log('[+] http://localhost:5000/');
});