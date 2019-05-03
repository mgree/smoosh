#include <stdio.h>

int main(int argc, char *argv[]) {
  for (int i = 0; i < argc; i += 1) {
    printf("argv[%d] = \"%s\";\n", i, argv[i]);
  }

  return 0;
}
