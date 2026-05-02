--- src/streaming/stream-receiver-connection.c	2026-01-12 21:39:59.000000000 +0800
+++ src/streaming/stream-receiver-connection.c	2026-02-08 03:58:47.000000000 +0800
@@ -312,10 +312,14 @@
                 nd_log(NDLS_DAEMON, NDLP_WARNING,
                        "STREAM RCV '%s' [from [%s]:%s]: cannot set TCP_KEEPIDLE on socket %d",
                        rrdhost_hostname(rpt->host), rpt->remote_ip, rpt->remote_port, rpt->sock.fd);
+#endif
+#ifdef TCP_KEEPINTVL
             if (setsockopt(rpt->sock.fd, IPPROTO_TCP, TCP_KEEPINTVL, &interval, sizeof(interval)) != 0)
                 nd_log(NDLS_DAEMON, NDLP_WARNING,
                        "STREAM RCV '%s' [from [%s]:%s]: cannot set TCP_KEEPINTVL on socket %d",
                        rrdhost_hostname(rpt->host), rpt->remote_ip, rpt->remote_port, rpt->sock.fd);
+#endif
+#ifdef TCP_KEEPCNT
             if (setsockopt(rpt->sock.fd, IPPROTO_TCP, TCP_KEEPCNT, &count, sizeof(count)) != 0)
                 nd_log(NDLS_DAEMON, NDLP_WARNING,
                        "STREAM RCV '%s' [from [%s]:%s]: cannot set TCP_KEEPCNT on socket %d",
