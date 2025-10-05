const fs = require('fs');
const path = require('path');

const file = process.argv[2];
const substring = process.argv[3];
if (!file || !substring) {
  console.error('Usage: node inspect_string.js <file> <substring>');
  process.exit(1);
}

const content = fs.readFileSync(file, 'utf8');
const index = content.indexOf(substring);
if (index === -1) {
  console.error('Substring not found');
  process.exit(1);
}
const slice = content.slice(index, index + substring.length + 5);
console.log('Slice:', slice);
for (const char of slice) {
  console.log(`${char} U+${char.codePointAt(0).toString(16).toUpperCase()}`);
}
