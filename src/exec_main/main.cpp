#include <app_hello_world/app_hello_world.hpp>


static int program_main(int argc, char* argv[])
{
    int ret = -1;
    ret = app_hello_world(argc, argv);
    return ret;
}

int main(int argc, char* argv[])
{
    int ret = -1;
    ret = program_main(argc, argv);
    return ret;
}
