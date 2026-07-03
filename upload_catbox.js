/**
 * upload_catbox.js
 * Uploads the release APK to catbox.moe (free permanent file host, 200MB limit)
 * and prints the direct download URL.
 */
const https = require('https');
const fs = require('fs');
const path = require('path');

const APK_PATH = path.join(__dirname, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
const BOUNDARY = 'FormBoundaryCatboxPOSMashinani';

if (!fs.existsSync(APK_PATH)) {
  console.error('APK not found:', APK_PATH);
  process.exit(1);
}

const apkBuffer = fs.readFileSync(APK_PATH);

// catbox.moe multipart form: reqtype=fileupload, fileToUpload=<file>
const header = Buffer.from(
  '--' + BOUNDARY + '\r\n' +
  'Content-Disposition: form-data; name="reqtype"\r\n\r\n' +
  'fileupload\r\n' +
  '--' + BOUNDARY + '\r\n' +
  'Content-Disposition: form-data; name="userhash"\r\n\r\n' +
  '\r\n' +
  '--' + BOUNDARY + '\r\n' +
  'Content-Disposition: form-data; name="fileToUpload"; filename="pos-mashinani.apk"\r\n' +
  'Content-Type: application/vnd.android.package-archive\r\n\r\n'
);
const footer = Buffer.from('\r\n--' + BOUNDARY + '--\r\n');
const body = Buffer.concat([header, apkBuffer, footer]);

console.log('Uploading ' + (apkBuffer.length / 1024 / 1024).toFixed(1) + ' MB to catbox.moe...');

const req = https.request({
  hostname: 'catbox.moe',
  path: '/user/api.php',
  method: 'POST',
  headers: {
    'Content-Type': 'multipart/form-data; boundary=' + BOUNDARY,
    'Content-Length': body.length,
    'User-Agent': 'Mozilla/5.0',
  },
  timeout: 300000,
}, (res) => {
  let data = '';
  res.on('data', (c) => data += c);
  res.on('end', () => {
    const url = data.trim();
    console.log('\nServer response:', url);
    if (url.startsWith('https://')) {
      console.log('\n✅ APK uploaded successfully!');
      console.log('📥 Direct Download URL:');
      console.log('   ' + url);
      console.log('\n📝 Update download_apk_page.dart line 7 to:');
      console.log("   static const String apkUrl = '" + url + "';");
    } else {
      console.error('\n❌ Unexpected response:', url);
    }
  });
});

req.on('timeout', () => {
  console.error('Request timed out after 5 minutes');
  req.destroy();
});
req.on('error', (e) => console.error('Error:', e.message));

let sent = 0;
const CHUNK = 512 * 1024;
function writeChunk() {
  const slice = body.slice(sent, sent + CHUNK);
  if (slice.length === 0) { req.end(); return; }
  sent += slice.length;
  process.stdout.write('\r   Progress: ' + Math.round(sent / body.length * 100) + '%   ');
  if (req.write(slice)) {
    writeChunk();
  } else {
    req.once('drain', writeChunk);
  }
}
writeChunk();
