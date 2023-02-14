# C++ project template

## Dependency
1. Install conan package manager
2. Adjust installation location of conan packages
    ```shell
    # show
    conan config get storage.path
    # change
    conan config set storage.path=<your path>
    ```

## Build
```shell
mkdir build
cd build
cmake ..
cmake --build . --parallel
```
