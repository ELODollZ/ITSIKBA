sudo bash << 'EOF'
set -e

echo "[+] Opdaterer system"
apt update -y
apt install -y nginx php-fpm

echo "[+] Finder PHP-version"
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_SOCK="/run/php/php$PHP_VER-fpm.sock"

echo "[+] PHP: $PHP_VER"
echo "[+] Socket: $PHP_SOCK"

systemctl enable nginx
systemctl enable php$PHP_VER-fpm
systemctl restart php$PHP_VER-fpm
systemctl restart nginx

echo "[+] Opretter webroot"
mkdir -p /var/www/exam_demo/uploads
chown -R www-data:www-data /var/www/exam_demo

#######################################
# 1️⃣ FORSIDE – SÅRBAR LFI / TRAVERSAL
#######################################
cat > /var/www/exam_demo/index.php << 'PHP'
<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

/*
 ⚠️ BEVIDST SÅRBAR – PATH TRAVERSAL (LFI)
 Klassisk: app forventer filer i uploads/
*/
$base = "/var/www/exam_demo/uploads/";
chdir($base); // <-- KRITISK: gør ../../ muligt

if (isset($_GET['file'])) {
    echo "<h3>Fil-indhold:</h3><pre>";
    readfile($_GET['file']);
    echo "</pre>";
    exit;
}
?>
<!DOCTYPE html>
<html>
<head><title>Exam Demo</title></head>
<body>
<h2>Velkommen</h2>
<p>Intern filvisning.</p>
<p><b>Demo:</b> <code>?file=../../etc/passwd</code></p>
<p><a href="login.php">Secure admin</a></p>
</body>
</html>
PHP

############################
# 2️⃣ LOGIN
############################
cat > /var/www/exam_demo/login.php << 'PHP'
<?php
session_start();

$USER = "BachelorAfleveringEksamensUser2026";
$PASS = "BachelorAfleveringEksamensPasswd2026";

if (isset($_POST['u'], $_POST['p'])) {
    if ($_POST['u'] === $USER && $_POST['p'] === $PASS) {
        $_SESSION['auth'] = true;
        header("Location: secureadmin.php");
        exit;
    }
    $err = "Forkert login";
}
?>
<h2>Secure Admin Login</h2>
<?php if (!empty($err)) echo "<p style=color:red>$err</p>"; ?>
<form method="post">
User: <input name="u"><br>
Pass: <input type="password" name="p"><br>
<input type="submit" value="Login">
</form>
PHP

#######################################
# 3️⃣ SECURE ADMIN – FILSYSTEM-SØGNING
#######################################
cat > /var/www/exam_demo/secureadmin.php << 'PHP'
<?php
session_start();
if (empty($_SESSION['auth'])) {
    header("Location: login.php");
    exit;
}

$results = [];

if (isset($_GET['q']) && strlen($_GET['q']) > 0) {
    $needle = basename($_GET['q']);
    $it = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator("/", FilesystemIterator::SKIP_DOTS)
    );

    foreach ($it as $file) {
        if (stripos($file->getFilename(), $needle) !== false) {
            $results[] = $file->getPathname();
        }
        if (count($results) >= 20) break;
    }
}
?>
<h2>Secure Admin</h2>
<p>Login OK</p>

<form>
Søg efter filnavn:
<input name="q">
<input type="submit" value="Søg">
</form>

<?php
if ($results) {
    echo "<h3>Resultater:</h3><pre>";
    foreach ($results as $r) echo htmlspecialchars($r) . "\n";
    echo "</pre>";
}
?>
PHP

############################
# NGINX
############################
cat > /etc/nginx/sites-available/default << NGINX
server {
    listen 80;
    server_name _;

    root /var/www/exam_demo;
    index index.php;

    autoindex off;

    location / {
        try_files \$uri \$uri/ /index.php =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
    }
}
NGINX

nginx -t
systemctl reload nginx

echo "======================================="
echo " ✅ ENDELIG DEMO KLAR"
echo "======================================="
echo ""
echo " LFI / Traversal:"
echo "  http://<VM-IP>/?file=../../etc/passwd"
echo ""
echo " Secure admin:"
echo "  http://<VM-IP>/login.php"
echo ""
echo " Login:"
echo "  User: BachelorAfleveringEksamensUser2026"
echo "  Pass: BachelorAfleveringEksamensPasswd2026"
echo ""
echo "======================================="
EOF
