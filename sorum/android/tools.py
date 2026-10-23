"""build.sh가 쓰는 작은 도우미들: 웹앱 오프라인화, 아이콘 그리기, zip 정렬, 정렬 검사."""
import re, sys, zipfile
from pathlib import Path


def offline_html(src, dst):
    """구글 폰트 링크를 앱 안에 넣은 폰트(assets/fonts)로 바꾸고, 완전한 HTML 문서로 감싸요."""
    s = Path(src).read_text(encoding="utf-8")
    s = re.sub(r'<link rel="preconnect"[^>]*>\n', "", s)
    s = re.sub(r'<link rel="stylesheet" href="https://fonts.googleapis.com[^>]*>\n', "", s)
    faces = ('<style>\n@font-face{font-family:"Do Hyeon";src:url(fonts/DoHyeon.ttf) format("truetype");font-display:swap}\n'
             '@font-face{font-family:"Gowun Dodum";src:url(fonts/GowunDodum.ttf) format("truetype");font-display:swap}\n</style>\n')
    head = ('<!doctype html>\n<html lang="ko">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            '<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}[hidden]{display:none!important}</style>\n')
    Path(dst).write_text(head + faces + '</head>\n<body>\n' + s + '\n</body>\n</html>\n', encoding="utf-8")


def subset(src_html, dst_dir, *fonts):
    """폰트 다이어트: 자주 쓰는 한글 2,350자 + 영문·숫자·기호 + 앱에 실제로 쓰인 글자만 남겨요.
    목록에 없는 글자를 입력하면 그 글자만 휴대폰 기본 글꼴로 보여요."""
    from fontTools import subset as ft
    chars = set(Path(src_html).read_text(encoding="utf-8"))
    chars |= {chr(c) for c in range(0x20, 0x7F)}
    for hi in range(0xB0, 0xC9):          # KS X 1001 한글 영역(EUC-KR)
        for lo in range(0xA1, 0xFF):
            try:
                chars.add(bytes([hi, lo]).decode("euc-kr"))
            except UnicodeDecodeError:
                pass
    text = "".join(sorted(chars))
    for f in fonts:
        out = Path(dst_dir) / Path(f).name
        ft.main([f, f"--text={text}", f"--output-file={out}", "--layout-features=*"])


def icon(font, out_dir):
    """런처 아이콘: 소주병 청록 바탕에 호박색 '소름'."""
    from PIL import Image, ImageDraw, ImageFont
    sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for dpi, px in sizes.items():
        big = 768
        img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([24, 24, big - 24, big - 24], radius=170, fill=(15, 31, 28, 255))
        d.rounded_rectangle([24, 24, big - 24, big - 24], radius=170, outline=(44, 74, 67, 255), width=10)
        f = ImageFont.truetype(font, 300)
        d.text((big / 2, big / 2 + 8), "소름", font=f, fill=(243, 183, 72, 255), anchor="mm")
        p = Path(out_dir) / f"mipmap-{dpi}"
        p.mkdir(parents=True, exist_ok=True)
        img.resize((px, px), Image.LANCZOS).save(p / "ic_launcher.png")


def align(src, dst):
    """zipalign 대신: 압축 안 한(STORED) 파일의 시작 위치를 4바이트 경계에 맞춰요.
    안드로이드 11 이상은 resources.arsc가 이렇게 정렬돼 있어야 설치를 허락해요."""
    zin = zipfile.ZipFile(src)
    with zipfile.ZipFile(dst, "w") as zout:
        for info in zin.infolist():
            data = zin.read(info.filename)
            ni = zipfile.ZipInfo(info.filename, date_time=info.date_time)
            ni.compress_type = info.compress_type
            ni.external_attr = info.external_attr
            if ni.compress_type == zipfile.ZIP_STORED:
                offset = zout.fp.tell() + 30 + len(ni.filename.encode("utf-8"))
                pad = (-offset) % 4
                ni.extra = b"\x00" * pad
            zout.writestr(ni, data)


def check(apk):
    """정렬 검사: STORED 파일이 전부 4바이트 경계에서 시작하는지 확인해요."""
    bad = []
    with zipfile.ZipFile(apk) as z, open(apk, "rb") as fp:
        for i in z.infolist():
            if i.compress_type != zipfile.ZIP_STORED:
                continue
            fp.seek(i.header_offset + 26)
            n, m = int.from_bytes(fp.read(2), "little"), int.from_bytes(fp.read(2), "little")
            if (i.header_offset + 30 + n + m) % 4:
                bad.append(i.filename)
    print("정렬 OK" if not bad else "정렬 안 맞음: " + ", ".join(bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    {"html": offline_html, "subset": subset, "icon": icon, "align": align, "check": check}[sys.argv[1]](*sys.argv[2:])
