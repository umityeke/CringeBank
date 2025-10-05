const fs = require('fs');
const path = require('path');
const iconv = require('iconv-lite');

const preReplacements = [
  ['ğŸ', 'ðŸ'],
  ['ĞŸ', 'ÐŸ'],
  ['ç¼', 'Ã¼'],
  ['ç¶', 'Ã¶'],
  ['çœ', 'Ãœ'],
  ['ç–', 'Ã–'],
  ['ç‡', 'Ã‡'],
  ['ç§', 'Ã§'],
  ['ç', 'Ã'],
  ['ç¤', 'Ã¤'],
  ['ç¸', 'Ã¸'],
  ['ı±', 'Ä±'],
  ['I±', 'Ä±'],
  ['ı°', 'Ä°'],
  ['I°', 'Ä°'],
  ['ıŸ', 'ğ'],
  ['IŸ', 'Ğ'],
];

const postReplacements = [
  ['Â·', '·'],
  ['Â°', '°'],
  ['Â±', '±'],
  ['Â»', '»'],
  ['Â«', '«'],
  ['Â', ''],
  ['ı±', 'ı'],
  ['±', ''],
  ['§', ''],
  ['�Ÿ', 'ğ'],
  ['�', ''],
  ['Ä±', 'ı'],
  ['Ä°', 'İ'],
  ['ÄŸ', 'ğ'],
  ['Äž', 'Ğ'],
  ['ÅŸ', 'ş'],
  ['Åž', 'Ş'],
  ['Ã¼', 'ü'],
  ['Ãœ', 'Ü'],
  ['Ã¶', 'ö'],
  ['Ã–', 'Ö'],
  ['Ã§', 'ç'],
  ['Ã‡', 'Ç'],
];

const decodePatterns = [
  /Ã./g,
  /Ä./g,
  /Å./g,
  /ðŸ../g,
  /Ã¢../g,
];

const TURKISH_LOCALE = 'tr';

const simpleCharReplacements = [
  ['œ', 'ü'],
  ['Œ', 'Ü'],
  ['‡', 'Ç'],
  ['‚', '₺'],
];

const sequenceReplacements = [
  ['”””€', '>>> '],
  ['œ“', '• '],
  ['ğ‰', '🎉'],
];

const emojiSingleCharFallbacks = new Map([
  ['‰', 'Ž‰'],
]);

const targetedWordReplacements = [
  ['giriğ', 'giriş'],
  ['oluğ', 'oluş'],
  ['paylağ', 'paylaş'],
  ['yarığ', 'yarış'],
  ['bağar', 'başar'],
  ['bağlangıç', 'başlangıç'],
  ['bağvur', 'başvur'],
  ['bağlık', 'başlık'],
  ['bağlığ', 'başlığ'],
  ['bağlat', 'başlat'],
  ['bağlad', 'başlad'],
  ['bağka', 'başka'],
  ['ağk', 'aşk'],
  ['karğı', 'karşı'],
  ['bitiğ', 'bitiş'],
  ['iğlem', 'işlem'],
  ['iğle', 'işle'],
  ['kiği', 'kişi'],
  ['geliğ', 'geliş'],
  ['değiğ', 'değiş'],
];

const targetedPhraseReplacements = [
  [/bağa\s+çık/gi, 'başa çık'],
];

function escapeRegExp(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function applyCase(match, replacement) {
  if (!match) return replacement;
  if (match === match.toLocaleUpperCase(TURKISH_LOCALE)) {
    return replacement.toLocaleUpperCase(TURKISH_LOCALE);
  }
  if (match === match.toLocaleLowerCase(TURKISH_LOCALE)) {
    return replacement.toLocaleLowerCase(TURKISH_LOCALE);
  }
  const first = match[0];
  const rest = match.slice(1);
  if (
    first === first.toLocaleUpperCase(TURKISH_LOCALE) &&
    rest === rest.toLocaleLowerCase(TURKISH_LOCALE)
  ) {
    const [repFirst, ...repRest] = replacement;
    return (
      repFirst.toLocaleUpperCase(TURKISH_LOCALE) +
      repRest.join('').toLocaleLowerCase(TURKISH_LOCALE)
    );
  }
  return replacement;
}

function applySimpleCharReplacements(text) {
  let result = text;
  for (const [from, to] of sequenceReplacements) {
    result = result.split(from).join(to);
  }
  for (const [from, to] of simpleCharReplacements) {
    result = result.split(from).join(to);
  }
  return result;
}

function applyTargetedPhraseReplacements(text) {
  let result = text;
  for (const [pattern, replacement] of targetedPhraseReplacements) {
    result = result.replace(pattern, (match) => applyCase(match, replacement));
  }
  return result;
}

function applyTargetedWordReplacements(text) {
  let result = text;
  const sorted = [...targetedWordReplacements].sort(
    ([a], [b]) => b.length - a.length,
  );
  for (const [source, target] of sorted) {
    const regex = new RegExp(escapeRegExp(source), 'gi');
    result = result.replace(regex, (match) => applyCase(match, target));
  }
  return result;
}

function applyEnDashFixes(text) {
  let result = text;
  result = result.replace(/–rn/gi, (match) => {
    const r = match[1];
    const n = match[2];
    const base = 'Örn';
    const isUpperR = r === r.toLocaleUpperCase(TURKISH_LOCALE);
    const isUpperN = n === n.toLocaleUpperCase(TURKISH_LOCALE);
    if (isUpperR && isUpperN) {
      return base.toLocaleUpperCase(TURKISH_LOCALE);
    }
    if (isUpperR) {
      return 'ÖRn';
    }
    if (isUpperN) {
      return 'ÖrN';
    }
    return base;
  });
  result = result.replace(/–([nzd])/gi, (match, letter) => {
    const isUpper = letter === letter.toLocaleUpperCase(TURKISH_LOCALE);
    const replaced = `Ö${letter.toLocaleLowerCase(TURKISH_LOCALE)}`;
    return isUpper
      ? replaced.toLocaleUpperCase(TURKISH_LOCALE)
      : replaced;
  });
  return result;
}

function needsDecoding(text) {
  return decodePatterns.some((pattern) => pattern.test(text));
}

function convertEmojiFragments(text) {
  return text.replace(/ðŸ([\s\S]{2})/g, (match, pair) => {
    const chars = [...pair];
    if (chars.length !== 2) {
      return match;
    }
    const [c1, c2] = chars;
    const b1 = iconv.encode(c1, 'windows-1252');
    const b2 = iconv.encode(c2, 'windows-1252');
    if (b1.length !== 1 || b2.length !== 1) {
      return match;
    }
    const bytes = Buffer.from([0xF0, 0x9F, b1[0], b2[0]]);
    return iconv.decode(bytes, 'utf8');
  });
}

function restoreEmojiArtifacts(text) {
  return text.replace(/ğ([\u0100-\uFFFF]{1,2})/g, (_, rest) => {
    if (rest.length === 1) {
      const mapped = emojiSingleCharFallbacks.get(rest);
      if (mapped) {
        return `ðŸ${mapped}`;
      }
    }
    if (rest.length === 2) {
      return `ðŸ${rest}`;
    }
    return `ğ${rest}`;
  });
}

function fixText(input) {
  let text = input;
  for (const [pattern, replacement] of preReplacements) {
    text = text.split(pattern).join(replacement);
  }

  text = restoreEmojiArtifacts(text);
  text = convertEmojiFragments(text);

  let iterations = 0;
  while (needsDecoding(text) && iterations < 5) {
    iterations += 1;
    const placeholders = new Map();
    let index = 0;
    const sanitized = text.replace(/[\u0100-\uFFFF]/g, (match) => {
      const key = `__UNI_${index++}__`;
      placeholders.set(key, match);
      return key;
    });

  const encoded = iconv.encode(sanitized, 'windows-1254');
    let decoded = iconv.decode(encoded, 'utf8');

    for (const [key, value] of placeholders.entries()) {
      decoded = decoded.split(key).join(value);
    }

    text = decoded;
  }

  for (const [pattern, replacement] of postReplacements) {
    text = text.split(pattern).join(replacement);
  }

  text = applySimpleCharReplacements(text);
  text = applyEnDashFixes(text);
  text = applyTargetedPhraseReplacements(text);
  text = applyTargetedWordReplacements(text);

  return text;
}

function walk(dir, list = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath, list);
    } else if (entry.isFile() && entry.name.endsWith('.dart')) {
      list.push(fullPath);
    }
  }
  return list;
}

const targetDirs = [path.join(__dirname, '..', 'lib')];
const files = targetDirs.flatMap((dir) => walk(dir));

let changedCount = 0;
for (const file of files) {
  const original = fs.readFileSync(file, 'utf8');
  const fixed = fixText(original);
  if (fixed !== original) {
    fs.writeFileSync(file, fixed, 'utf8');
    changedCount += 1;
    console.log(`Fixed ${path.relative(path.join(__dirname, '..'), file)}`);
  }
}

console.log(`Updated ${changedCount} files.`);
