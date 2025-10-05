const fs = require('fs');
const path = process.argv[2];
const keyword = process.argv[3];
if (!path || !keyword) {
  console.error('Usage: node inspect_line.js <file> <keyword>');
  process.exit(1);
}
const lines = fs.readFileSync(path, 'utf8').split('\n');
const line = lines.find((l) => l.includes(keyword));
if (!line) {
  console.error('Keyword not found');
  process.exit(1);
}
console.log(line);
for (const ch of line) {
  console.log(`${ch} U+${ch.codePointAt(0).toString(16).toUpperCase()}`);
}
