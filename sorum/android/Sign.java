// APK 서명기. 안드로이드는 서명 없는 APK를 설치하지 않아요.
// v2(APK 전체) 서명을 넣어요. 안드로이드 7.0 이상은 v2 서명만으로 설치돼요.
import com.android.apksig.ApkSigner;
import java.io.File;
import java.io.FileInputStream;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.X509Certificate;
import java.util.Collections;

public class Sign {
    public static void main(String[] a) throws Exception {
        // 사용법: java Sign <키스토어.p12> <비밀번호> <별칭> <입력.apk> <출력.apk>
        KeyStore ks = KeyStore.getInstance("PKCS12");
        try (FileInputStream in = new FileInputStream(a[0])) { ks.load(in, a[1].toCharArray()); }
        PrivateKey key = (PrivateKey) ks.getKey(a[2], a[1].toCharArray());
        X509Certificate cert = (X509Certificate) ks.getCertificate(a[2]);
        ApkSigner.SignerConfig cfg = new ApkSigner.SignerConfig.Builder("SORUM", key, Collections.singletonList(cert)).build();
        new ApkSigner.Builder(Collections.singletonList(cfg))
            .setInputApk(new File(a[3])).setOutputApk(new File(a[4]))
            .setMinSdkVersion(24).setV1SigningEnabled(false).setV2SigningEnabled(true)
            .build().sign();
    }
}
