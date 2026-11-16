-- Version test local (valeurs en dur)
CREATE DATABASE IF NOT EXISTS `wordpress`;
CREATE USER IF NOT EXISTS 'wp_user'@'%' IDENTIFIED BY 'testpass';
CREATE USER IF NOT EXISTS 'wp_user'@'localhost' IDENTIFIED BY 'testpass';
GRANT ALL PRIVILEGES ON `wordpress`.* TO 'wp_user'@'%';
GRANT ALL PRIVILEGES ON `wordpress`.* TO 'wp_user'@'localhost';
FLUSH PRIVILEGES;