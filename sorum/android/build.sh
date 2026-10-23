#!/usr/bin/env bash
# 소름테스트 APK 빌드 스크립트
# 필요한 것: Java 17+, Maven, Python 3 + Pillow (+ 선택: fonttools), curl, 인터넷(Maven Central, Google Fonts)
# 결과물: sorum/android/out/sorumtest.apk
set -euo pipefail
cd "$(dirname "$0")"
HERE=$(pwd)
OUT="$HERE/out"; WORK="$OUT/work"
rm -rf "$WORK"; mkdir -p "$WORK/assets/fonts" "$WORK/res" "$OUT"

echo "1/7 빌드 도구 내려받기 (Maven Central)"
[ -d "$OUT/lib" ] || mvn -q dependency:copy-dependencies -DoutputDirectory="$OUT/lib"
CP=$(ls "$OUT"/lib/*.jar | tr '\n' ':')
unzip -o -q -j "$OUT"/lib/apktool-lib-*.jar prebuilt/linux/aapt2_64 prebuilt/android-framework.jar -d "$OUT/bin"
chmod +x "$OUT/bin/aapt2_64"

echo "2/7 폰트를 앱 안에 넣기 (술집에서 인터넷이 안 돼도 글꼴 유지)"
[ -f "$OUT/DoHyeon.ttf" ] || curl -sSfL -o "$OUT/DoHyeon.ttf" https://fonts.gstatic.com/s/dohyeon/v21/TwMN-I8CRRU2zM86HFE3.ttf
[ -f "$OUT/GowunDodum.ttf" ] || curl -sSfL -o "$OUT/GowunDodum.ttf" https://fonts.gstatic.com/s/gowundodum/v12/3Jn5SD_00GqwlBnWc1TUJF0F.ttf
if python3 -c "import fontTools" 2>/dev/null; then
  python3 tools.py subset ../app.html "$WORK/assets/fonts" "$OUT/DoHyeon.ttf" "$OUT/GowunDodum.ttf"
else
  echo "   (fonttools가 없어서 폰트를 통째로 넣어요. 'pip install fonttools'면 APK가 훨씬 작아져요)"
  cp "$OUT/DoHyeon.ttf" "$OUT/GowunDodum.ttf" "$WORK/assets/fonts/"
fi

echo "3/7 웹앱(../app.html)을 오프라인용으로 변환"
python3 tools.py html ../app.html "$WORK/assets/index.html"

echo "4/7 아이콘 그리기"
python3 tools.py icon "$OUT/DoHyeon.ttf" "$WORK/res"

echo "5/7 코드(smali) → classes.dex"
java -cp "$CP" org.jf.smali.Main assemble --api 24 -o "$WORK/classes.dex" smali

echo "6/7 매니페스트·아이콘·웹앱 묶기 (aapt2)"
"$OUT/bin/aapt2_64" compile --dir "$WORK/res" -o "$WORK/res.zip"
"$OUT/bin/aapt2_64" link -o "$WORK/base.apk" -I "$OUT/bin/android-framework.jar" \
  --manifest AndroidManifest.xml --min-sdk-version 24 --target-sdk-version 34 \
  -A "$WORK/assets" -0 ttf "$WORK/res.zip"
(cd "$WORK" && zip -q base.apk classes.dex)
python3 tools.py align "$WORK/base.apk" "$WORK/aligned.apk"

echo "7/7 서명"
KS="${SORUM_KEYSTORE:-$HOME/.sorum/sorum-release.p12}"
PW="${SORUM_KEYSTORE_PASS:-sorum-local}"
if [ ! -f "$KS" ]; then
  mkdir -p "$(dirname "$KS")"
  keytool -genkeypair -keystore "$KS" -storetype PKCS12 -storepass "$PW" -keypass "$PW" \
    -alias sorum -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Sorum Test" >/dev/null 2>&1
  echo "   새 서명 키를 만들었어요: $KS (업데이트 설치하려면 이 파일을 보관하세요)"
fi
javac -nowarn -cp "$CP" -d "$WORK" Sign.java
java --add-exports java.base/sun.security.x509=ALL-UNNAMED --add-exports java.base/sun.security.pkcs=ALL-UNNAMED --add-exports java.base/sun.security.util=ALL-UNNAMED -cp "$CP$WORK" Sign "$KS" "$PW" sorum "$WORK/aligned.apk" "$OUT/sorumtest.apk"
python3 tools.py check "$OUT/sorumtest.apk"
echo "완료: $OUT/sorumtest.apk ($(du -h "$OUT/sorumtest.apk" | cut -f1))"
