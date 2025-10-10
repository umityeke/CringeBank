/*
  Bu dosya yalnızca dokümantasyon amaçlıdır.

  Realtime Mirror bileşenlerini dağıtmak için sqlcmd paketi kullanın:

    sqlcmd -S <sunucu> -d <veritabani> -G -b -i deploy_realtime_mirror.sqlcmd
    sqlcmd -S <sunucu> -d <veritabani> -U <kullanici> -P <parola> -b -i deploy_realtime_mirror.sqlcmd

  sqlcmd komutları (`:r`, `:on error exit`) yalnızca `deploy_realtime_mirror.sqlcmd` dosyasında bulunmaktadır.
*/

PRINT 'Lütfen deploy_realtime_mirror.sqlcmd dosyasını sqlcmd ile çalıştırın.';
GO
