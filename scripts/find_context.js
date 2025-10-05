const fs = require('fs');
const path = process.argv[2];
const target = process.argv[3];
if (!path || !target) {
  console.error('Usage: node find_context.js <file> <target>');
  process.exit(1);
}
const text = fs.readFileSync(path, 'utf8');
for (let i = 0; i < text.length; i += 1) {
  if (text.startsWith(target, i)) {
    const before = text.slice(Math.max(0, i - 5), i);
    const after = text.slice(i + target.length, i + target.length + 5);
    console.log(`${before}[${target}]${after}`);
  }
}
