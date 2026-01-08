--- src/proto_sockpair.c	2025-11-26 22:55:57.000000000 +0800
+++ src/proto_sockpair.c	2025-12-22 05:16:41.000000000 +0800
@@ -237,12 +237,15 @@ int send_fd_uxst(int fd, int send_fd)
 	struct iovec iov;
 	struct msghdr msghdr;
 
-	char cmsgbuf[CMSG_SPACE(sizeof(int))] = {0};
-	char buf[CMSG_SPACE(sizeof(int))] = {0};
+	char cmsgbuf[CMSG_SPACE(sizeof(int))];
+	char buf[CMSG_SPACE(sizeof(int))];
 	struct cmsghdr *cmsg = (void *)buf;
 
 	int *fdptr;
 
+	memset(cmsgbuf, 0, sizeof(cmsgbuf));
+	memset(buf, 0, sizeof(buf));
+
 	iov.iov_base = iobuf;
 	iov.iov_len = sizeof(iobuf);
 
