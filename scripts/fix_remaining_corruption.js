const fs = require('fs');
const path = require('path');

// Bozuk karakter ve doğru karşılıkları
const replacements = [
  // Avatar emoji düzeltmeleri - önce özel durumlar
  { pattern: /'ğ''/g, replacement: "'👤'" },
  
  // Özel durumlar - emoji parçaları ve garbled text
  { pattern: /etti„Ÿin/g, replacement: 'ettiğin' },
  { pattern: /bağlayabilirsin/g, replacement: 'başlayabilirsin' },
  { pattern: /release †'/g, replacement: "release →" },
  
  // Yaygın kelime ve hece düzeltmeleri (case-insensitive)
  { pattern: /aldığın/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Aldığın' : 'aldığın' },
  { pattern: /alınamaz/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Alınamaz' : 'alınamaz' },
  { pattern: /analiz/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Analiz' : 'analiz' },
  { pattern: /ayrılmalısın/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Ayrılmalısın' : 'ayrılmalısın' },
  { pattern: /bağlanmış/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Bağlanmış' : 'bağlanmış' },
  { pattern: /bağlı/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Bağlı' : 'bağlı' },
  { pattern: /başarıyla/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Başarıyla' : 'başarıyla' },
  { pattern: /başlayabilirsin/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Başlayabilirsin' : 'başlayabilirsin' },
  { pattern: /başlığı/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Başlığı' : 'başlığı' },
  { pattern: /beğeni/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Beğeni' : 'beğeni' },
  { pattern: /benzersiz/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Benzersiz' : 'benzersiz' },
  { pattern: /birine/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Birine' : 'birine' },
  { pattern: /borsa/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Borsa' : 'borsa' },
  { pattern: /değeri/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Değeri' : 'değeri' },
  { pattern: /değilsin/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Değilsin' : 'değilsin' },
  { pattern: /değişiklik/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Değişiklik' : 'değişiklik' },
  { pattern: /deneyin/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Deneyin' : 'deneyin' },
  { pattern: /desteği/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Desteği' : 'desteği' },
  { pattern: /diğer/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Diğer' : 'diğer' },
  { pattern: /dokunarak/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Dokunarak' : 'dokunarak' },
  { pattern: /düzenle/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Düzenle' : 'düzenle' },
  { pattern: /ediliyor/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Ediliyor' : 'ediliyor' },
  { pattern: /efektleri/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Efektleri' : 'efektleri' },
  { pattern: /emin/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Emin' : 'emin' },
  { pattern: /erişim/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Erişim' : 'erişim' },
  { pattern: /ettiğim/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Ettiğim' : 'ettiğim' },
  { pattern: /ettiğin/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Ettiğin' : 'ettiğin' },
  { pattern: /fark ettim/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Fark ettim' : 'fark ettim' },
  { pattern: /fiziksel/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Fiziksel' : 'fiziksel' },
  { pattern: /fotoğraf/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Fotoğraf' : 'fotoğraf' },
  { pattern: /geri/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Geri' : 'geri' },
  { pattern: /giriş/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Giriş' : 'giriş' },
  { pattern: /göndererek/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Göndererek' : 'göndererek' },
  { pattern: /göster/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Göster' : 'göster' },
  { pattern: /hemen/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Hemen' : 'hemen' },
  { pattern: /içeriğin/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'İçeriğin' : 'içeriğin' },
  { pattern: /için/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'İçin' : 'için' },
  { pattern: /işlem/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'İşlem' : 'işlem' },
  { pattern: /isteğe/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'İsteğe' : 'isteğe' },
  { pattern: /istediğin/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'İstediğin' : 'istediğin' },
  { pattern: /istediğinizden/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'İstediğinizden' : 'istediğinizden' },
  { pattern: /kalsın/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Kalsın' : 'kalsın' },
  { pattern: /katıldığın/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Katıldığın' : 'katıldığın' },
  { pattern: /kaydedilemedi/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Kaydedilemedi' : 'kaydedilemedi' },
  { pattern: /kayıtlı/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Kayıtlı' : 'kayıtlı' },
  { pattern: /kimliği/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Kimliği' : 'kimliği' },
  { pattern: /kontrol/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Kontrol' : 'kontrol' },
  { pattern: /korunacak/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Korunacak' : 'korunacak' },
  { pattern: /krepi/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Krepi' : 'krepi' },
  { pattern: /krepin/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Krepin' : 'krepin' },
  { pattern: /kullan/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Kullan' : 'kullan' },
  { pattern: /kullanıcılar/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Kullanıcılar' : 'kullanıcılar' },
  { pattern: /mesaj/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Mesaj' : 'mesaj' },
  { pattern: /mesajlağma/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Mesajlaşma' : 'mesajlaşma' },
  { pattern: /mevcut/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Mevcut' : 'mevcut' },
  { pattern: /olduğunu/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Olduğunu' : 'olduğunu' },
  { pattern: /olmadığını/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Olmadığını' : 'olmadığını' },
  { pattern: /onayladığında/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Onayladığında' : 'onayladığında' },
  { pattern: /önce/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Önce' : 'önce' },
  { pattern: /paylaş/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Paylaş' : 'paylaş' },
  { pattern: /profilinde/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Profilinde' : 'profilinde' },
  { pattern: /resim/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Resim' : 'resim' },
  { pattern: /satığı/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Satışı' : 'satışı' },
  { pattern: /satın/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Satın' : 'satın' },
  { pattern: /seçili/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Seçili' : 'seçili' },
  { pattern: /seçin/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Seçin' : 'seçin' },
  { pattern: /silmek/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Silmek' : 'silmek' },
  { pattern: /sipariş/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Sipariş' : 'sipariş' },
  { pattern: /sonra/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Sonra' : 'sonra' },
  { pattern: /takip/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Takip' : 'takip' },
  { pattern: /tekrar/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Tekrar' : 'tekrar' },
  { pattern: /tertemiz/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Tertemiz' : 'tertemiz' },
  { pattern: /topluluğa/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Topluluğa' : 'topluluğa' },
  { pattern: /ürüne/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Ürüne' : 'ürüne' },
  { pattern: /uyumluluğu/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Uyumluluğu' : 'uyumluluğu' },
  { pattern: /yalnızken/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Yalnızken' : 'yalnızken' },
  { pattern: /yansıyacaktır/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Yansıyacaktır' : 'yansıyacaktır' },
  { pattern: /yaparak/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Yaparak' : 'yaparak' },
  { pattern: /yarışma/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Yarışma' : 'yarışma' },
  { pattern: /yorum/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Yorum' : 'yorum' },
  
  // Composite patterns
  { pattern: /çoklu/gi, replacement: match => match[0] === match[0].toUpperCase() ? 'Çoklu' : 'çoklu' },
];

function fixFile(filePath) {
  try {
    let content = fs.readFileSync(filePath, 'utf8');
    let modified = false;
    
    for (const { pattern, replacement } of replacements) {
      const before = content;
      content = content.replace(pattern, replacement);
      if (content !== before) {
        modified = true;
      }
    }
    
    if (modified) {
      fs.writeFileSync(filePath, content, 'utf8');
      console.log(`✓ Fixed: ${filePath}`);
      return true;
    }
    return false;
  } catch (err) {
    console.error(`✗ Error fixing ${filePath}:`, err.message);
    return false;
  }
}

function walkDir(dir, fileCallback) {
  const files = fs.readdirSync(dir);
  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat.isDirectory()) {
      if (!['build', 'node_modules', '.git', '.dart_tool'].includes(file)) {
        walkDir(filePath, fileCallback);
      }
    } else if (file.endsWith('.dart')) {
      fileCallback(filePath);
    }
  });
}

// Ana çalıştırma
const libDir = path.join(__dirname, '..', 'lib');
let fixedCount = 0;

console.log('🔧 Kalan bozuk karakterleri düzeltiliyor...\n');
walkDir(libDir, (filePath) => {
  if (fixFile(filePath)) {
    fixedCount++;
  }
});

console.log(`\n✨ Tamamlandı! ${fixedCount} dosya düzeltildi.`);
