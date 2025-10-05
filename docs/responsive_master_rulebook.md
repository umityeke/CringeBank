# CringeBank Responsive Master Rulebook

## 🎯 Amaç

- Tüm arayüzler (özellikle mobil ve tablet) piksel bozulması, taşma, scroll sapması olmadan, enterprise-kalitede render olacak.
- Herhangi bir kural ihlali build süreçlerinde **FAIL** olarak sayılır.

## 🪟 Breakpoint Tanımları (tek kaynak gerçek)
| Ad | Genişlik | Cihaz |
| --- | --- | --- |
| xs | 0 – 359 px | küçük telefon |
| sm | 360 – 599 px | normal telefon |
| md | 600 – 1023 px | büyük tel / küçük tablet |
| lg | 1024 – 1279 px | tablet |
| xl | 1280 – 1919 px | laptop / masaüstü |
| xxl | ≥ 1920 px | geniş ekran / TV |

**Grid kolon sayısı:**
- xs–sm → 1
- md → 2
- lg–xl → 3–4

- xxl → 5–6

## 🌐 Web (Tailwind / HTML / CSS)

### 1. Tailwind yapılandırması

```js
// tailwind.config.js
export default {
  theme: {
    container: {
      center: true,
      screens: {
        xl: '1280px',
        '2xl': '1440px',
      },
    },
    screens: {
      xs: '360px',

      sm: '360px',

      md: '600px',
      lg: '1024px',
      xl: '1280px',
      '2xl': '1920px',
    },
  },
};
```

### 2. Grid ve container

```css
.cb-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: clamp(8px, 1.2vw, 24px);
  max-width: 1440px;
  margin: 0 auto;
  padding: var(--gap);
}
```

### 3. Kartlar

```css
.cb-card {
  display: flex;
  flex-direction: column;
  min-width: 0;
  overflow: hidden;
  border-radius: 16px;
}

.cb-card * {
  min-width: 0;
}

.cb-img {
  width: 100%;
  aspect-ratio: 16 / 9;
  object-fit: cover;
  display: block;
}

.cb-title {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.cb-sub {
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  display: -webkit-box;
  overflow: hidden;
}

.cb-btn {
  height: 44px;
  min-width: 44px;
}
```

### 4. Tipografi

```css
:root {
  --t-14: clamp(14px, 1.2vw, 16px);
  --t-18: clamp(18px, 1.6vw, 20px);
}

body {
  font-size: var(--t-14);
  line-height: 1.5;
}
```

### 5. A11y & performans

- Dokunma hedefi ≥ 44×44 px
- `:focus-visible` aktif
- Görseller `loading="lazy"` ve `decoding="async"`
- Yatay scroll yok
- CLS < 0.1, Lighthouse ≥ 90 (accessibility & best-practices)

## 📱 Flutter

### 1. Breakpoints

```dart
class CBk {
  static const xs = 0.0;
  static const sm = 360.0;
  static const md = 600.0;
  static const lg = 1024.0;
  static const xl = 1280.0;
  static const xxl = 1920.0;
}
```

### 2. Responsive helper

```dart
T cb<T>(
  BuildContext context, {
  required T xs,
  T? md,
  T? lg,
  T? xl,
  T? xxl,
}) {
  final width = MediaQuery.of(context).size.width;

  if (width >= CBk.xxl && xxl != null) return xxl;
  if (width >= CBk.xl && xl != null) return xl;
  if (width >= CBk.lg && lg != null) return lg;
  if (width >= CBk.md && md != null) return md;
  return xs;
}
```

### 3. Grid kuralı

```dart
GridView.builder(
  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 300,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 16 / 10,
  ),
  itemBuilder: …,
);
```

### 4. Metin ve görseller

```dart
Text(title, maxLines: 1, overflow: TextOverflow.ellipsis);
Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis);
AspectRatio(
  aspectRatio: 16 / 9,
  child: Image.network(url, fit: BoxFit.cover),
);
SizedBox(
  height: 44,
  width: double.infinity,
  child: FilledButton(...),
);
```

### 5. Focus & TV

```dart
FocusTraversalGroup(
  child: Shortcuts(
    shortcuts: {
      LogicalKeySet(LogicalKeyboardKey.arrowRight): NextFocusIntent(),
    },
    child: …,
  ),
);
```

## 🧪 Otomatik Denetim (CI)

### Playwright responsive test (`tests/responsive.spec.ts`)

Viewport’lar: 360×740 → 1920×1080.
Her boyutta şu koşullar doğrulanır:

- `document.scrollWidth <= clientWidth`
- `.cb-card` taşma yok
- `.cb-img` oranı ≈ 16 / 9 (±1 %)
- Tap hedefleri ≥ 44 px

### Lighthouse (`lighthouserc.json`)

```json
{
  "extends": "lighthouse:default",
  "settings": {
    "onlyCategories": ["accessibility", "best-practices"]
  },
  "ci": {
    "assert": {
      "assertions": {
        "categories:accessibility": ["error", { "minScore": 0.9 }],
        "categories:best-practices": ["error", { "minScore": 0.9 }]
      }
    }
  }
}
```

### Flutter Golden test (`test/goldens/responsive_golden_test.dart`)

- Aynı viewport matrisi kullanılmalı.
- Overflow hatası **FAIL**.
- Golden screenshot farklıysa **FAIL**.

## ✅ Definition of Done

- Hiçbir breakpoint’te yatay scroll veya taşma yok.
- Telefon: tek sütun, tablet: iki sütun.
- Kart oranı 16 : 9 ± 1 %.
- Metinler ellipsis / clamp ile sınırlı.
- Butonlar ≥ 44×44 px.
- CLS ≤ 0.1, Lighthouse ≥ 90.
- Flutter analyzer’da overflow uyarısı yok.
- Golden ve Playwright testleri geçer.

## 🧠 Copilot Emir Cümlesi

> “CringeBank arayüzü tüm ekranlarda, özellikle telefon ve tablette, sıfır taşma-sapma ile çalışacak. Belirlenen breakpoints, grid kolon sayıları, aspect-ratio 16 : 9, metinlerde ellipsis ve dokunma hedefi ≥ 44px kurallarına uymayan her değişiklik CI’da FAIL sayılacak. Responsive hatası olan commit veya PR otomatik reddedilecek.”

---

### Kullanım Notları

- Yeni feature geliştirmelerinde UX incelemesini bu doküman referans alınarak tamamlayın.
- CI pipeline’ına yeni testler eklerken burada listelenen kontrolleri baz alın.
- PR incelemelerinde “Responsive Master Rulebook” maddesi geçmeden onay vermeyin.
