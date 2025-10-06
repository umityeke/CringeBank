:setvar DB_NAME "CringeBank"
:setvar APP_LOGIN "cringebank_app"
:setvar APP_USER "cringebank_app"
:setvar APP_PASSWORD "ChangeMe!Immediately1"

/*
  Usage:
    sqlcmd -S localhost,1433 -U sa -P "<AdminPassword>" -b -i provision_sql.sql \
      -v DB_NAME="CringeBank" APP_LOGIN="cringebank_app" APP_USER="cringebank_app" APP_PASSWORD="Strong#Pass123"
*/

IF DB_ID('$(DB_NAME)') IS NULL
BEGIN
    EXEC('CREATE DATABASE [' + '$(DB_NAME)' + ']');
END
GO

USE [$(DB_NAME)];
GO

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'$(APP_LOGIN)')
BEGIN
    EXEC('CREATE LOGIN [' + '$(APP_LOGIN)' + '] WITH PASSWORD = ''' + '$(APP_PASSWORD)' + ''', CHECK_POLICY = ON');
END
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'$(APP_USER)')
BEGIN
    EXEC('CREATE USER [' + '$(APP_USER)' + '] FOR LOGIN [' + '$(APP_LOGIN)' + ']');
END
GO

EXEC('ALTER ROLE db_datareader ADD MEMBER [' + '$(APP_USER)' + ']');
EXEC('ALTER ROLE db_datawriter ADD MEMBER [' + '$(APP_USER)' + ']');
GO

ALTER DATABASE [$(DB_NAME)] SET READ_COMMITTED_SNAPSHOT ON;
GO
