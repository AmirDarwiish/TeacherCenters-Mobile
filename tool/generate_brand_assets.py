from pathlib import Path
from PIL import Image
import json
r=Path(__file__).resolve().parents[1];src=r/'assets/brand'
icon=Image.open(src/'rewaq-app-icon-1024.png').convert('RGB')
def resized(im,path,size):
 path.parent.mkdir(parents=True,exist_ok=True);im.resize(size,Image.Resampling.LANCZOS).save(path)
for density,px in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:resized(icon,r/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png',(px,px))
a=r/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((a/'Contents.json').read_text())['images']:
 size=int(float(item['size'].split('x')[0])*float(item['scale'][:-1]));resized(icon,a/item['filename'],(size,size))
for px in [192,512]:
 for name in ['Icon','Icon-maskable']:resized(icon,r/f'web/icons/{name}-{px}.png',(px,px))
small=Image.open(src/'rewaq-mark-small-32.png');small.thumbnail((32,32),Image.Resampling.LANCZOS)
favicon=Image.new('RGBA',(32,32));favicon.alpha_composite(small,((32-small.width)//2,(32-small.height)//2));favicon.save(r/'web/favicon.png')
# Keep original lockup proportions and its clear space on all launch surfaces.
logo=Image.open(src/'rewaq-logo-stacked-reverse-1024.png')
for scale,suffix in [(1,''),(2,'@2x'),(3,'@3x')]:
 im=logo.copy();im.thumbnail((140*scale,240*scale),Image.Resampling.LANCZOS);im.save(r/f'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{suffix}.png')
for density,scale in [('mdpi',1),('hdpi',1.5),('xhdpi',2),('xxhdpi',3),('xxxhdpi',4)]:
 im=logo.copy();im.thumbnail((int(140*scale),int(240*scale)),Image.Resampling.LANCZOS);p=r/f'android/app/src/main/res/drawable-{density}/rewaq_launch.png';p.parent.mkdir(parents=True,exist_ok=True);im.save(p)
for name in ['drawable','drawable-v21']:
 (r/f'android/app/src/main/res/{name}/launch_background.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item><shape><solid android:color="#0B2540" /></shape></item>
    <item><bitmap android:gravity="center" android:src="@drawable/rewaq_launch" /></item>
</layer-list>
''')
p=r/'ios/Runner/Base.lproj/LaunchScreen.storyboard';s=p.read_text().replace('red="1" green="1" blue="1"','red="0.043137" green="0.145098" blue="0.250980"');p.write_text(s)
# Android 12+ uses the system splash icon rather than the legacy bitmap.
for variant in ['values-v31','values-night-v31']:
 p=r/f'android/app/src/main/res/{variant}/styles.xml';p.parent.mkdir(parents=True,exist_ok=True);p.write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowSplashScreenBackground">#0B2540</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/rewaq_splash_mark</item>
    </style>
</resources>
''')
# System splash masks its central area: keep the original reverse mark inside it.
mark=Image.open(src/'rewaq-mark-reverse-512.png');mark.thumbnail((160,160),Image.Resampling.LANCZOS)
canvas=Image.new('RGBA',(288,288));canvas.alpha_composite(mark,((288-mark.width)//2,(288-mark.height)//2));p=r/'android/app/src/main/res/drawable-mdpi/rewaq_splash_mark.png';canvas.save(p)
