/**
 * upload_apk.js
 * Uploads the release APK to Firebase Storage using the Firebase CLI credentials
 * and makes it publicly accessible for download.
 */
const fs = require('fs');
const path = require('path');
const https = require('https');

const PROJECT_ID = 'tikach-pos';
const BUCKET = `${PROJECT_ID}.firebasestorage.app`;
const APK_LOCAL = path.join(__dirname, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
const DEST_OBJECT = 'downloads/pos-mashinani.apk';

// Firebase tools configstore location
const CONFIG_PATH = path.join(
  process.env.USERPROFILE || process.env.HOME || '',
  '.config', 'configstore', 'firebase-tools.json'
);

function getTokens() {
  if (!fs.existsSync(CONFIG_PATH)) {
    throw new Error(`Firebase config not found at: ${CONFIG_PATH}. Please run 'firebase login' first.`);
  }
  const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  if (!config.tokens) throw new Error('No tokens found in firebase-tools config. Run "firebase login".');
  return config.tokens;
}

function refreshAccessToken(refreshToken) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      client_secret: 'j9iVZfS8ggCdFoQFKvl8iEtt', // Firebase CLI public client secret
    });
    const req = https.request({
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        if (res.statusCode === 200) {
          const resp = JSON.parse(data);
          resolve(resp.access_token);
        } else {
          reject(new Error(`Token refresh failed: ${data}`));
        }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function getAccessToken() {
  const tokens = getTokens();
  const now = Date.now();
  // If token expires in >5min, use it directly
  if (tokens.access_token && tokens.expires_at && (tokens.expires_at - now) > 300000) {
    console.log('   Using cached access token.');
    return tokens.access_token;
  }
  // Otherwise refresh
  console.log('   Refreshing access token...');
  return refreshAccessToken(tokens.refresh_token);
}

function uploadViaRestApi(accessToken) {
  const apkBuffer = fs.readFileSync(APK_LOCAL);
  const fileSize = apkBuffer.length;
  const encodedObject = encodeURIComponent(DEST_OBJECT);
  const uploadPath = `/upload/storage/v1/b/${BUCKET}/o?uploadType=media&name=${encodedObject}`;

  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'storage.googleapis.com',
      path: uploadPath,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Length': fileSize,
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`Upload failed: HTTP ${res.statusCode}\n${data}`));
        }
      });
    });
    req.on('error', reject);

    // Stream the file in chunks
    let offset = 0;
    const CHUNK = 256 * 1024; // 256KB chunks
    process.stdout.write('   Uploading');
    function writeChunk() {
      const slice = apkBuffer.slice(offset, offset + CHUNK);
      if (slice.length === 0) {
        req.end();
        return;
      }
      offset += slice.length;
      const pct = Math.round((offset / fileSize) * 100);
      process.stdout.write(`\r   Uploading... ${pct}%  `);
      if (req.write(slice)) {
        writeChunk();
      } else {
        req.once('drain', writeChunk);
      }
    }
    writeChunk();
  });
}

function makePublic(accessToken) {
  const encodedObject = encodeURIComponent(DEST_OBJECT);
  const aclPath = `/storage/v1/b/${BUCKET}/o/${encodedObject}/acl`;
  const body = JSON.stringify({ entity: 'allUsers', role: 'READER' });

  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'storage.googleapis.com',
      path: aclPath,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        if (res.statusCode === 200 || res.statusCode === 201) resolve();
        else reject(new Error(`makePublic failed: HTTP ${res.statusCode}\n${data}`));
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function main() {
  if (!fs.existsSync(APK_LOCAL)) {
    console.error(`❌ APK not found at:\n   ${APK_LOCAL}`);
    process.exit(1);
  }

  const sizeMb = (fs.statSync(APK_LOCAL).size / 1024 / 1024).toFixed(1);
  console.log(`\n📦 APK: ${APK_LOCAL} (${sizeMb} MB)`);
  console.log(`📤 Destination: gs://${BUCKET}/${DEST_OBJECT}\n`);

  console.log('🔐 Getting access token...');
  let accessToken;
  try {
    accessToken = await getAccessToken();
    console.log('   ✅ Token ready.\n');
  } catch (err) {
    console.error(`❌ Auth error: ${err.message}`);
    process.exit(1);
  }

  try {
    await uploadViaRestApi(accessToken);
    console.log('\n✅ Upload complete!');

    process.stdout.write('🌐 Making file publicly accessible...');
    await makePublic(accessToken);
    console.log(' Done!');

    const publicUrl = `https://storage.googleapis.com/${BUCKET}/${DEST_OBJECT}`;
    console.log('\n🎉 APK is now publicly available!');
    console.log(`\n   Download URL:\n   ${publicUrl}\n`);
    console.log('📝 Next: Update download_apk_page.dart line 7 to:');
    console.log(`   static const String apkUrl = '${publicUrl}';\n`);

  } catch (err) {
    console.error(`\n❌ Error: ${err.message}`);
    process.exit(1);
  }
}

main();
