USE [master]
GO

CREATE DATABASE ssc
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'ssc', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQL01\MSSQL\DATA\ssc.mdf' , SIZE = 8192KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'ssc_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQL01\MSSQL\DATA\ssc_log.ldf' , SIZE = 8192KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
 WITH CATALOG_COLLATION = DATABASE_DEFAULT, LEDGER = OFF
GO

IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [ssc].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO

ALTER DATABASE [ssc] COLLATE SQL_Latin1_General_CP1_CS_AS
GO
ALTER DATABASE [ssc] SET AUTO_UPDATE_STATISTICS_ASYNC ON 
GO
ALTER DATABASE [ssc] SET ALLOW_SNAPSHOT_ISOLATION ON 
GO
ALTER DATABASE [ssc] SET READ_COMMITTED_SNAPSHOT ON 
GO
ALTER DATABASE [ssc] SET ANSI_NULL_DEFAULT ON 
GO
CREATE LOGIN fortify_user WITH PASSWORD = 'Str0ngRuntimePass!'
GO

USE [ssc]
GO

CREATE USER fortify_user FOR LOGIN fortify_user
GO
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA :: dbo TO fortify_user
GO
GRANT EXECUTE ON SCHEMA :: dbo TO fortify_user
GO
GRANT ALTER ON SCHEMA :: dbo TO fortify_user
GO
GRANT CREATE TABLE TO fortify_user
GO
GRANT CREATE VIEW TO fortify_user
GO
GRANT CREATE PROCEDURE TO fortify_user
GO
GRANT CREATE FUNCTION TO fortify_user
GO
EXEC sp_addrolemember 'db_ddladmin', 'fortify_user'
GO