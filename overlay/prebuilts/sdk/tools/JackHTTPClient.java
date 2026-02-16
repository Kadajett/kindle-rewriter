import java.net.*;
import java.io.*;
import javax.net.ssl.*;
import java.security.*;
import java.security.cert.X509Certificate;
import java.util.*;

public class JackHTTPClient {
    public static void main(String[] args) {
        try {
            run(args);
        } catch (ConnectException e) {
            // Connection refused — equivalent to curl exit code 7
            System.exit(7);
        } catch (SSLException e) {
            // SSL error — equivalent to curl exit code 35
            System.exit(35);
        } catch (SocketTimeoutException e) {
            // Timeout — equivalent to curl exit code 28
            System.exit(28);
        } catch (Exception e) {
            // Other errors
            System.exit(1);
        }
    }

    static void run(String[] args) throws Exception {
        if (args.length < 5) {
            System.err.println("Usage: JackHTTPClient <keystore> <truststore> <password> <method> <url> [header:Name=Value] [field=path]");
            System.exit(1);
        }

        String keystorePath = args[0];
        String password = args[2];
        String method = args[3];
        String urlStr = args[4];

        // Parse remaining args: headers (header:X=Y), data (data:X), and form fields (field=value)
        List<String[]> headers = new ArrayList<>();
        List<String> formArgs = new ArrayList<>();
        String bodyData = null;
        for (int i = 5; i < args.length; i++) {
            if (args[i].startsWith("header:")) {
                String hdr = args[i].substring(7);
                int eq = hdr.indexOf("=");
                if (eq > 0) {
                    headers.add(new String[]{hdr.substring(0, eq), hdr.substring(eq + 1)});
                }
            } else if (args[i].startsWith("data:")) {
                bodyData = args[i].substring(5);
            } else if (args[i].contains("=")) {
                formArgs.add(args[i]);
            }
        }

        // Load client keystore for mutual TLS client cert
        KeyStore ks = KeyStore.getInstance("JKS");
        ks.load(new FileInputStream(keystorePath), password.toCharArray());

        KeyManagerFactory kmf = KeyManagerFactory.getInstance("SunX509");
        kmf.init(ks, password.toCharArray());

        // Trust all server certs (equivalent to curl -k / --insecure)
        TrustManager[] trustAll = new TrustManager[] {
            new X509TrustManager() {
                public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
                public void checkClientTrusted(X509Certificate[] c, String a) {}
                public void checkServerTrusted(X509Certificate[] c, String a) {}
            }
        };

        SSLContext ctx = SSLContext.getInstance("TLS");
        ctx.init(kmf.getKeyManagers(), trustAll, null);

        HttpsURLConnection.setDefaultSSLSocketFactory(ctx.getSocketFactory());
        HttpsURLConnection.setDefaultHostnameVerifier((h, s) -> true);

        URL url = new URL(urlStr);
        HttpsURLConnection conn = (HttpsURLConnection) url.openConnection();
        conn.setRequestMethod(method);
        conn.setConnectTimeout(300000);

        // Set headers
        for (String[] hdr : headers) {
            conn.setRequestProperty(hdr[0], hdr[1]);
        }

        // Handle --data body content (e.g. for HEAD version checks)
        if (bodyData != null && formArgs.isEmpty()) {
            conn.setDoOutput(true);
            OutputStream os = conn.getOutputStream();
            os.write(bodyData.getBytes("UTF-8"));
            os.flush();
            os.close();
        }

        // Handle file upload for PUT with multipart
        if (!formArgs.isEmpty()) {
            String boundary = "----JackBoundary" + System.currentTimeMillis();
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "multipart/form-data; boundary=" + boundary);

            OutputStream os = conn.getOutputStream();
            for (String arg : formArgs) {
                String[] parts = arg.split("=", 2);
                String fieldName = parts[0];
                String filePath = parts[1];

                os.write(("--" + boundary + "\r\n").getBytes());
                if (new File(filePath).exists()) {
                    os.write(("Content-Disposition: form-data; name=\"" + fieldName + "\"; filename=\"" + new File(filePath).getName() + "\"\r\n").getBytes());
                    os.write("Content-Type: application/octet-stream\r\n\r\n".getBytes());
                    FileInputStream fis = new FileInputStream(filePath);
                    byte[] buf = new byte[4096];
                    int n;
                    while ((n = fis.read(buf)) > 0) os.write(buf, 0, n);
                    fis.close();
                } else {
                    os.write(("Content-Disposition: form-data; name=\"" + fieldName + "\"\r\n").getBytes());
                    os.write(("Content-Type: text/plain\r\n\r\n").getBytes());
                    os.write(filePath.getBytes());
                }
                os.write("\r\n".getBytes());
            }
            os.write(("--" + boundary + "--\r\n").getBytes());
            os.flush();
            os.close();
        }

        int code = conn.getResponseCode();

        // Read response body
        try {
            InputStream is = (code >= 400) ? conn.getErrorStream() : conn.getInputStream();
            if (is != null) {
                byte[] buf = new byte[4096];
                int n;
                while ((n = is.read(buf)) > 0) {
                    System.err.write(buf, 0, n);
                }
                is.close();
            }
        } catch (Exception e) { /* ignore */ }

        // Print HTTP code to stdout (for jack-admin's --write-out '%{http_code}')
        System.out.print(code);

        if (code >= 400) System.exit(22); // curl -f exit code
    }
}
