#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {

  char *dir_path;
  if (argc == 1) {
    dir_path = ".";
  } else if (argc == 2) {
    dir_path = argv[1];
  } else {
    fprintf(stderr, "usage: %s [directory]\n", argv[0]);
    exit(2);
  }

  DIR *dir = opendir(dir_path);

  if (NULL == dir) {
    fprintf(stderr, "Couldn't open '%s'\n", dir_path);
    exit(1);
  }

  struct dirent *entry;
  while ( (entry = readdir(dir)) ) {
    printf("%s\n", entry->d_name);
  }

  return 0;
}
