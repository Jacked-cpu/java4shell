import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicLong;

public final class DecodeServer {
    private static final int HOT_LOOP = Integer.getInteger("lab.hotloop", 20000);
    private static final AtomicLong HITS = new AtomicLong();

    public static void main(String[] args) throws IOException {
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 8080;
        HttpServer server = HttpServer.create(new InetSocketAddress("0.0.0.0", port), 0);
        server.createContext("/health", ex -> respond(ex, 200, "ok\n"));
        server.createContext("/login", DecodeServer::login);
        server.start();
        System.out.printf("listening on 0.0.0.0:%d hotloop=%d%n", port, HOT_LOOP);
    }

    private static void login(HttpExchange ex) throws IOException {
        String auth = ex.getRequestHeaders().getFirst("Authorization");
        long n = HITS.incrementAndGet();
        int status = 401;

        if (auth != null && auth.regionMatches(true, 0, "Basic ", 0, 6)) {
            status = 400;
            byte[] payload = auth.substring(6).trim().getBytes(StandardCharsets.US_ASCII);
            for (int i = 0; i < HOT_LOOP; i++) {
                try {
                    Base64.getDecoder().decode(payload);
                    status = 200;
                } catch (IllegalArgumentException ignored) {
                }
            }
        }

        System.out.printf("request=%d authBytes=%d status=%d%n",
                n, auth == null ? 0 : auth.length(), status);
        ex.getResponseHeaders().set("WWW-Authenticate", "Basic realm=\"lab\"");
        respond(ex, status, status == 200 ? "decoded\n" : "no\n");
    }

    private static void respond(HttpExchange ex, int status, String body) throws IOException {
        byte[] out = body.getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(status, out.length);
        try (var os = ex.getResponseBody()) {
            os.write(out);
        }
    }
}
