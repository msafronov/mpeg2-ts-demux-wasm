const fs = require('fs');

require('dotenv').config();

const file = fs.readFileSync(process.env.BINARY_OUTPUT_PATH);

const getInstance = () => {
  return WebAssembly.instantiate(file)
    .then(({ instance }) => {
        return instance;
    });
};

module.exports = {
    getInstance,
};