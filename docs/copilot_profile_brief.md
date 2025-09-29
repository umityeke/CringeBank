# SimpleProfileScreen – Sahiplik Kuralları Özeti

Bu not, GitHub Copilot veya yeni geliştiriciler için profil ekranındaki sahiplik (isOwnProfile) davranışlarını kodsuz olarak özetler.

## Sahiplik Nasıl Tespit Ediliyor?
- Ekranda görüntülenen `User` nesnesinin `id` değeri, Firebase Auth kullanıcısının `uid` değeriyle eşleşiyorsa profil sahip olarak kabul edilir.
- `SimpleProfileScreen` widget'ına `userId` ya da `initialUser` aracılığıyla aktarılan kimlikler de aday listesine eklenir.
- Firebase'den ya da `UserService.currentUser` üzerinden alınan kimlikler ile aday kümesi kesişiyorsa görünüm "kendi profilimiz" sayılır.
- Hedef kimlik bilinmiyorsa (`candidateIds` boşsa) ekran varsayılan olarak sahiplenmiş kabul edilir ve kullanıcı giriş yapmaya yönlendirilir.

## Sahibi Olduğumuz Profillerde Gösterilen Öğeler
- Başlık kartındaki eylem alanında **Profili Düzenle** ve **Krep Paylaş** butonları aktif olur (yalnızca `_canEditProfile` olumluysa).
- Biyografi alanı boşsa, kullanıcıyı kendini tanıtmaya teşvik eden uyarı metni gösterilir.
- Takip et / Mesaj gönder alanı gizlenir.

## Başka Kullanıcılara Ait Profillerde Gösterilen Öğeler
- Başlık kartındaki eylem alanı **Takip Et / Takip Ediliyor** butonu ve **Mesaj Gönder** butonuna dönüşür.
- Biyografi boşsa, "Bu kullanıcı henüz profilini doldurmadı." mesajı gösterilir; teşvik metni yalnızca profil sahibine özeldir.
- Takip işlemi devam ederken buton bekleme durumuna geçer; sonuç başarıysa sayaçlar yerel olarak güncellenir.

## Ortak Davranışlar
- Profil istatistikleri, mağaza kartı ve paylaşılan krepler tüm ziyaretçiler için aynı şekilde görünür.
- Kullanıcının paylaşımları yoksa bilgilendirme metni sahiplik durumuna göre iki farklı mesaj döndürür ("Henüz paylaştığın krep yok" vs. "Bu kullanıcı henüz krep paylaşmamış").
- Mesaj butonuna tıklandığında gerçek mesajlaşma hazır olana dek bilgi amaçlı bir Snackbar gösterilir.

## Firestore ve Takip İşlemleri Notu
- Firestore güvenlik kuralları `followersCount` alanında ±1 değişimlere özel izin verir; bu sayede takip/çıkma işlemleri hata vermeden çalışır.
- `UserService` tarafında takip/çıkma işlemleri transaction kullanır ve yerel cache’i temizleyerek arayüzün güncel kalmasını sağlar.

Bu özet, Copilot'un yeni taleplere yanıt verirken sahiplik bağlamını doğru kullanmasına yardımcı olmak için yazılmıştır.