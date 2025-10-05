const iconv = require('iconv-lite');

function fix(text) {
  const placeholderMap = new Map();
  let index = 0;
  const sanitized = text.replace(/[\u0100-\uFFFF]/g, (match) => {
    const key = `__UNI_${index++}__`;
    placeholderMap.set(key, match);
    return key;
  });
  const encoded = iconv.encode(sanitized, 'latin1');
  let decoded = iconv.decode(encoded, 'utf8');
  for (const [key, value] of placeholderMap.entries()) {
    decoded = decoded.split(key).join(value);
  }
  return decoded;
}

const input = 'gü';
const utf8Bytes = Buffer.from(input, 'utf8');
const cp1254String = iconv.decode(utf8Bytes, 'windows-1254');
const reencodedBytes = Buffer.from(cp1254String, 'utf8');
const cp1254Again = iconv.decode(reencodedBytes, 'windows-1254');
const third = Buffer.from(cp1254Again, 'utf8');
const cp1254Third = iconv.decode(third, 'windows-1254');

console.log('original:', input);
console.log('step1 cp1254:', cp1254String);
console.log('step2 cp1254:', cp1254Again);
console.log('step3 cp1254:', cp1254Third);
