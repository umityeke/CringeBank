const fs = require('fs');
const path = require('path');

function walk(dir, acc = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath, acc);
    } else if (entry.isFile() && entry.name.endsWith('.dart')) {
      acc.push(fullPath);
    }
  }
  return acc;
}

const files = walk(path.join(__dirname, '..', 'lib'));
const bigramCounts = new Map();

function add(map, key) {
  map.set(key, (map.get(key) || 0) + 1);
}

for (const file of files) {
  const content = fs.readFileSync(file, 'utf8');
  for (let i = 0; i < content.length - 1; i += 1) {
    const first = content[i];
    if ('çÇıİğĞşŞÂÃÄÅðøþ'.includes(first)) {
      const pair = content.slice(i, i + 2);
      add(bigramCounts, pair);
    }
  }
}

const sorted = [...bigramCounts.entries()].sort((a, b) => b[1] - a[1]);
for (const [pair, count] of sorted.slice(0, 80)) {
  console.log(`${pair} ${count}`);
}
