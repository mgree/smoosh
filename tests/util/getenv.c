#include <stdlib.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
  for (int i = 1; i < argc; i += 1) {
    char *var = argv[i];
    char *val = getenv(var);
    if (NULL == val) {
      printf("%s is unset\n", var);
    } else {
      printf("%s='%s'\n", var, val);
    }
  }
}
