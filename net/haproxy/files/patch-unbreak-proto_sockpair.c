Reverts https://github.com/haproxy/haproxy/commit/10c14a1ed049707854614f28cd57e5fd43ec3b31

--- src/proto_sockpair.c	2025-11-26 22:55:57.000000000 +0800
+++ src/proto_sockpair.c	2025-12-22 05:16:41.000000000 +0800
@@ -239,12 +239,12 @@
  */
 int send_fd_uxst(int fd, int send_fd)
 {
-	char iobuf[2] = {0};
+	char iobuf[2];
 	struct iovec iov;
 	struct msghdr msghdr;
 
-	char cmsgbuf[CMSG_SPACE(sizeof(int))] = {0};
-	char buf[CMSG_SPACE(sizeof(int))] = {0};
+	char cmsgbuf[CMSG_SPACE(sizeof(int))];
+	char buf[CMSG_SPACE(sizeof(int))];
 	struct cmsghdr *cmsg = (void *)buf;
 
 	int *fdptr;
