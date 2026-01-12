sudo bash << 'EOF'
set -e
echo "[+] Opdaterer system"
apt update -y
echo "[+] Installerer nginx og php-fpm"
apt install -y nginx php-fpm
echo "[+] Starter nginx"
systemctl enable nginx
systemctl start nginx
echo "[+] Opretter webroot og filer"
mkdir -p /var/www/exam_demo
chown -R $USER:$USER /var/www/exam_demo
USERNAME="BachelorAfleveringEksamensUser2026/09/01SuperCredentials"
PASSWORD="BachelorAfleveringEksamensPasswd2026/09/01SuperCredentials"
echo "[+] Opretter index.php (login-side)"
cat > /var/www/exam_demo/index.php << 'EOF2'
<?php
session_start();
$USERNAME = 'BachelorAfleveringEksamensUser2026/09/01SuperCredentials';
$PASSWORD = 'BachelorAfleveringEksamensPasswd2026/09/01SuperCredentials';
if (isset($_POST['username']) && isset($_POST['password'])) {
    if ($_POST['username'] === $USERNAME && $_POST['password'] === $PASSWORD) {
        $_SESSION['logged_in'] = true;
        header('Location: secureadminside.php');
        exit;
    } else {
        $error = "Forkert brugernavn eller password!";
    }
}
?>
<!DOCTYPE html>
<html>
<head><title>Login</title></head>
<body>
<h2>Login</h2>
<?php if(!empty($error)) echo "<p style='color:red;'>$error</p>"; ?>
<form method="post">
Username: <input type="text" name="username"><br>
Password: <input type="password" name="password"><br>
<input type="submit" value="Login">
</form>
</body>
</html>
EOF2
echo "[+] Opretter secureadminside.php"
cat > /var/www/exam_demo/secureadminside.php << 'EOF2'
<?php
session_start();
if (!isset($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
    header('Location: index.php');
    exit;
}
?>
<!DOCTYPE html>
<html>
<head><title>Secure Admin Side</title></head>
<body>
<h2>Velkommen til Secure Admin Side!</h2>
<p>Adgang givet.</p>
</body>
</html>
EOF2
echo "[+] Opretter sårbar adminside.php"
cat > /var/www/exam_demo/adminside.php << 'EOF2'
<?php
// DEMO sårbar side
echo "<pre>";
readfile('/etc/passwd');
echo "</pre>";
EOF2
echo "[+] Opsætning af Nginx site"
cat > /etc/nginx/sites-available/default << 'EOF2'
server {
    listen 80;
    server_name _;

    root /var/www/exam_demo;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }
}
EOF2
echo "[+] Tester nginx-konfiguration"
nginx -t
echo "[+] Genindlæser nginx"
systemctl reload nginx
echo ""
echo "========================================"
echo " ✅ OPSÆTNING FÆRDIG"
echo "========================================"
echo ""
echo " TEST FLOW:"
echo " 1) Browser:  http://<VM-IP>/             → Login-side (index.php)"
echo " 2) Username: $USERNAME"
echo "    Password: $PASSWORD"
echo " 3) Ved korrekt login → /secureadminside.php"
echo " 4) Sårbar side (kun demo): http://<VM-IP>/adminside.php → læser /etc/passwd"
echo ""
EOF