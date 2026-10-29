"""Generate public client build options from the owner's Android Firebase config.
Never put a Firebase service-account private key into this file or the APK.
"""
import json
import os
from pathlib import Path

source = os.environ.get('FIREBASE_ANDROID_CONFIG', '').strip()
if not source:
    Path('firebase-build.json').write_text(json.dumps({'PUSH_ENABLED': 'false'}))
    print('Firebase client configuration is absent; push is disabled in this build.')
else:
    config = json.loads(source)
    client = next(c for c in config['client'] if c['client_info']['android_client_info']['package_name'] == 'com.zeiia.teacher_centers_mobile')
    values = {
        'PUSH_ENABLED': 'true',
        'FIREBASE_API_KEY': client['api_key'][0]['current_key'],
        'FIREBASE_PROJECT_ID': config['project_info']['project_id'],
        'FIREBASE_SENDER_ID': config['project_info']['project_number'],
        'FIREBASE_APP_ID': client['client_info']['mobilesdk_app_id'],
    }
    if not all(values.values()):
        raise ValueError('Incomplete Firebase client configuration')
    Path('firebase-build.json').write_text(json.dumps(values))
    print('Firebase Android client configuration prepared; values are not logged.')
