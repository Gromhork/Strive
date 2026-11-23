import java.io.File;
import java.security.Key;
import java.security.KeyStore;
import java.security.PrivateKey;

/**
 * Release workflow check (see .github/workflows/release.yml): opens the keystore and reads the
 * signing key the same way the Android Gradle plugin does, so a wrong ANDROID_KEY_PASSWORD fails
 * with a clear message instead of as an obscure Gradle signing error. (keytool cannot check it:
 * for PKCS12 keystores it silently ignores -keypass.)
 *
 * Usage: KEYSTORE_PASSWORD=... KEY_PASSWORD=... KEY_ALIAS=... java CheckKey.java KEYSTORE_FILE
 */
public class CheckKey {
  public static void main(String[] args) throws Exception {
    char[] storePassword = System.getenv("KEYSTORE_PASSWORD").toCharArray();
    char[] keyPassword = System.getenv("KEY_PASSWORD").toCharArray();
    String alias = System.getenv("KEY_ALIAS");
    KeyStore keyStore;
    try {
      keyStore = KeyStore.getInstance(new File(args[0]), storePassword);
    } catch (Exception e) {
      fail("Keystore check failed: wrong ANDROID_KEYSTORE_PASSWORD or broken ANDROID_KEYSTORE_BASE64 (" + e + ").");
      return;
    }
    if (!keyStore.isKeyEntry(alias)) {
      fail("Keystore check failed: ANDROID_KEY_ALIAS is not a key entry in the keystore.");
    }
    Key key;
    try {
      key = keyStore.getKey(alias, keyPassword);
    } catch (Exception e) {
      fail("Key check failed: wrong ANDROID_KEY_PASSWORD (" + e.getClass().getSimpleName() + ").");
      return;
    }
    if (!(key instanceof PrivateKey)) {
      fail("Key check failed: ANDROID_KEY_ALIAS does not hold a private key.");
    }
    System.out.println("Signing key OK (" + keyStore.getType() + ", " + key.getAlgorithm() + ").");
  }

  private static void fail(String message) {
    System.out.println("::error::" + message);
    System.exit(1);
  }
}
