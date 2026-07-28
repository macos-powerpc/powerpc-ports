#include <unistd.h>

int main(void)
{
    write(1, "hello from musl-xnu ppc\n", 24);
    return 0;
}
