CREATE DATABASE IF NOT EXISTS tabla_movil
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE tabla_movil;

CREATE TABLE IF NOT EXISTS evaluaciones (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  participant VARCHAR(160) NOT NULL,
  social VARCHAR(120) NOT NULL DEFAULT '',
  control VARCHAR(120) NOT NULL DEFAULT '',
  expression VARCHAR(120) NOT NULL DEFAULT '',
  interpretation VARCHAR(120) NOT NULL DEFAULT '',
  technique VARCHAR(120) NOT NULL DEFAULT '',
  creativity VARCHAR(120) NOT NULL DEFAULT '',
  discipline VARCHAR(120) NOT NULL DEFAULT '',
  matter VARCHAR(120) NOT NULL DEFAULT '',
  shift VARCHAR(70) NOT NULL DEFAULT '',
  title VARCHAR(160) NOT NULL DEFAULT '',
  technique_score TINYINT UNSIGNED NOT NULL DEFAULT 0,
  expression_score TINYINT UNSIGNED NOT NULL DEFAULT 0,
  choreography_score TINYINT UNSIGNED NOT NULL DEFAULT 0,
  costume_score TINYINT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT chk_technique_score CHECK (technique_score <= 25),
  CONSTRAINT chk_expression_score CHECK (expression_score <= 25),
  CONSTRAINT chk_choreography_score CHECK (choreography_score <= 25),
  CONSTRAINT chk_costume_score CHECK (costume_score <= 25)
) ENGINE=InnoDB;