#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>

#define FD_START 0
#define FD_STOP  9

void usage(char *prog) {
  fprintf(stderr, "usage: %s [start_fd] [end_fd]\n", prog);
  exit(1);
}

void parse(char *desc, char *s, int *dst, int def) {
  if (!sscanf(s, "%d", dst)) {
    fprintf(stderr, "couldn't parse '%s' as a number, defaulting to %d for %s",
            s, def, desc);
  }
}

int main(int argc, char** argv) {
  if (argc > 3) {
    usage(argv[0]);
  }

  int start_fd = FD_START;
  if (argc >= 2) {
    parse("start fd", argv[1], &start_fd, FD_START);
  }

  int stop_fd = FD_STOP;
  if (argc == 3) {
    parse("stop fd", argv[2], &stop_fd, FD_STOP);
  }

  for (int fd = start_fd; fd <= stop_fd; fd += 1) {
    int res = fcntl(fd, F_GETFD);

    if (res < 0) {
      if (errno == EBADF) {
        printf("%d closed\n", fd);
      } else {
        char *msg = strerror(errno);
        printf("%d error: %s\n", fd, msg);
      }
    } else {
      printf("%d open\n", fd);
    }

  }

  return 0;
}
