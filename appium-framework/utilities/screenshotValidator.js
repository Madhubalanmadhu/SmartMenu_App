const fs = require('fs');
const zlib = require('zlib');

function readUInt32(buffer, offset) {
  return buffer.readUInt32BE(offset);
}

function bytesPerPixel(colorType) {
  if (colorType === 0) return 1; // grayscale
  if (colorType === 2) return 3; // RGB
  if (colorType === 6) return 4; // RGBA
  throw new Error(`Unsupported PNG color type: ${colorType}`);
}

function unfilterScanline(filter, current, previous, bpp) {
  const output = Buffer.alloc(current.length);

  for (let i = 0; i < current.length; i++) {
    const left = i >= bpp ? output[i - bpp] : 0;
    const up = previous ? previous[i] : 0;
    const upLeft = previous && i >= bpp ? previous[i - bpp] : 0;

    let value;
    if (filter === 0) {
      value = current[i];
    } else if (filter === 1) {
      value = current[i] + left;
    } else if (filter === 2) {
      value = current[i] + up;
    } else if (filter === 3) {
      value = current[i] + Math.floor((left + up) / 2);
    } else if (filter === 4) {
      const p = left + up - upLeft;
      const pa = Math.abs(p - left);
      const pb = Math.abs(p - up);
      const pc = Math.abs(p - upLeft);
      const predictor = pa <= pb && pa <= pc ? left : pb <= pc ? up : upLeft;
      value = current[i] + predictor;
    } else {
      throw new Error(`Unsupported PNG filter: ${filter}`);
    }

    output[i] = value & 0xff;
  }

  return output;
}

function analyzePngBase64(base64Data) {
  const buffer = Buffer.from(base64Data, 'base64');
  const signature = buffer.subarray(0, 8).toString('hex');
  if (signature !== '89504e470d0a1a0a') {
    throw new Error('Screenshot is not a PNG image');
  }

  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  const idatChunks = [];

  while (offset < buffer.length) {
    const length = readUInt32(buffer, offset);
    const type = buffer.subarray(offset + 4, offset + 8).toString('ascii');
    const dataStart = offset + 8;
    const dataEnd = dataStart + length;
    const data = buffer.subarray(dataStart, dataEnd);

    if (type === 'IHDR') {
      width = readUInt32(data, 0);
      height = readUInt32(data, 4);
      bitDepth = data[8];
      colorType = data[9];
    } else if (type === 'IDAT') {
      idatChunks.push(data);
    } else if (type === 'IEND') {
      break;
    }

    offset = dataEnd + 4;
  }

  if (bitDepth !== 8) {
    throw new Error(`Unsupported PNG bit depth: ${bitDepth}`);
  }

  const bpp = bytesPerPixel(colorType);
  const rowLength = width * bpp;
  const inflated = zlib.inflateSync(Buffer.concat(idatChunks));
  const sampleStepX = Math.max(1, Math.floor(width / 40));
  const sampleStepY = Math.max(1, Math.floor(height / 40));
  const uniqueColors = new Set();
  const brightnessValues = [];
  let sourceOffset = 0;
  let previous = null;

  for (let y = 0; y < height; y++) {
    const filter = inflated[sourceOffset];
    const row = inflated.subarray(sourceOffset + 1, sourceOffset + 1 + rowLength);
    const unfiltered = unfilterScanline(filter, row, previous, bpp);

    if (y % sampleStepY === 0) {
      for (let x = 0; x < width; x += sampleStepX) {
        const pixel = x * bpp;
        const r = unfiltered[pixel];
        const g = colorType === 0 ? r : unfiltered[pixel + 1];
        const b = colorType === 0 ? r : unfiltered[pixel + 2];
        uniqueColors.add(`${r},${g},${b}`);
        brightnessValues.push((r + g + b) / 3);
      }
    }

    previous = unfiltered;
    sourceOffset += rowLength + 1;
  }

  const mean = brightnessValues.reduce((sum, value) => sum + value, 0) / brightnessValues.length;
  const variance = brightnessValues.reduce((sum, value) => sum + (value - mean) ** 2, 0) / brightnessValues.length;
  const standardDeviation = Math.sqrt(variance);

  return {
    width,
    height,
    uniqueColorCount: uniqueColors.size,
    brightnessStandardDeviation: standardDeviation,
    meanBrightness: mean,
    isBlank: uniqueColors.size < 8 || standardDeviation < 3
  };
}

async function captureAndValidate(driver, filePath, label = 'screenshot') {
  if (driver && driver.isMock) {
    const mockScreenshot = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    if (filePath) {
      fs.writeFileSync(filePath, mockScreenshot, 'base64');
    }
    return {
      screenshotData: mockScreenshot,
      analysis: {
        width: 1080,
        height: 2400,
        uniqueColorCount: 10,
        brightnessStandardDeviation: 10.0,
        meanBrightness: 128,
        isBlank: false
      }
    };
  }

  const screenshotData = await driver.takeScreenshot();
  if (filePath) {
    fs.writeFileSync(filePath, screenshotData, 'base64');
  }

  const analysis = analyzePngBase64(screenshotData);
  if (analysis.isBlank) {
    throw new Error(
      `${label} appears blank. uniqueColors=${analysis.uniqueColorCount}, brightnessStdDev=${analysis.brightnessStandardDeviation.toFixed(2)}`
    );
  }

  return { screenshotData, analysis };
}

module.exports = {
  analyzePngBase64,
  captureAndValidate
};
