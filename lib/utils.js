import streamEqual from 'stream-equal';
import { fs } from 'appium-support';


async function fileCompare (file1, file2) {
  try {
    return await streamEqual(fs.createReadStream(file1), fs.createReadStream(file2));
  } catch (err) {
    if (err.code === 'ENOENT') {
      // one of the files does not exist, so they cannot be the same
      return false;
    }
    throw err;
  }
}

export { fileCompare };
