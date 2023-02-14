#include <app_hello_world/app_hello_world.hpp>
#include <fmt/core.h>

int app_hello_world(int argc, char* argv[])
{
    fmt::print("[{}] Hello World!\n", argv[0]);
    return 0;
}
