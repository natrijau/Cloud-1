<?php
$cfg['blowfish_secret'] = '{{ pma_blowfish_secret }}';
$cfg['Servers'][1]['host'] = 'mariadb';
$cfg['Servers'][1]['port'] = '3306';
$cfg['Servers'][1]['auth_type'] = 'cookie';
$cfg['Servers'][1]['user'] = '{{ sql_user }}';
$cfg['Servers'][1]['password'] = '{{ sql_password }}';
$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';