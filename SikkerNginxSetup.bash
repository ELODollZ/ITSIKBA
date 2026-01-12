sudo bash << 'EOF'
set -e
echo "[+] Opdaterer system"
apt update -y
echo "[+] Installerer nginx og php-fpm"
apt install -y nginx php-fpm
echo "[+] Starter services"
systemctl enable nginx
systemctl start nginx
systemctl start php*-fpm || true
PHP_SOCK=$(ls /run/php/php*-fpm.sock | head -n1)
echo "[+] Fundet PHP socket: $PHP_SOCK"
echo "[+] Opretter webroot"
mkdir -p /var/www/exam_demo
chown -R www-data:www-data /var/www/exam_demo
echo "[+] Login-side"
cat > /var/www/exam_demo/index.php << 'PHP'
<?php
session_start();
$U='BachelorAfleveringEksamensUser2026/09/01SuperCredentials';
$P='BachelorAfleveringEksamensPasswd2026/09/01SuperCredentials';
if(isset($_POST['username'],$_POST['password'])){
 if($_POST['username']===$U && $_POST['password']===$P){
  $_SESSION['ok']=true;
  header('Location: secureadminside.php'); exit;
 } else $e="Forkert login";
}
?>
<h2>Login</h2>
<?php if(!empty($e)) echo "<p style=color:red>$e</p>"; ?>
<form method=post>
User: <input name=username><br>
Pass: <input type=password name=password><br>
<input type=submit value=Login>
</form>
PHP
echo "[+] Secure admin"
cat > /var/www/exam_demo/secureadminside.php << 'PHP'
<?php
session_start();
if(empty($_SESSION['ok'])){ header('Location: index.php'); exit; }
echo "<h2>Secure Admin Side</h2><p>Login OK</p>";
PHP
echo "[+] SÅRBAR ADMINSIDE (viser /etc/passwd)"
cat > /var/www/exam_demo/adminside.php << 'PHP'
<?php
echo "<pre>";
readfile('/etc/passwd');
echo "</pre>";
PHP
echo "[+] Nginx config"
cat > /etc/nginx/sites-available/default << NGINX
server {
    listen 80;
    server_name _;
    root /var/www/exam_demo;
    index index.php;

    autoindex off;

    if (\$request_uri ~* "\.\.") { return 403; }

    location / {
        try_files \$uri \$uri/ /index.php =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
    }
}
NGINX
echo "[+] Tester nginx"
nginx -t
echo "[+] Reload nginx"
systemctl reload nginx
echo "======================================="
echo " ✅ KLAR"
echo "======================================="
echo " /                → login-side"
echo " /secureadminside.php → kræver login"
echo " /adminside.php   → Viser /etc/passwd"
echo "======================================="
EOF