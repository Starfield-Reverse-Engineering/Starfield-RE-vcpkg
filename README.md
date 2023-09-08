# Starfield Reverse Engineering vcpkg Registry

## CommonLibSF

[![VCPKG_VER](https://img.shields.io/static/v1?label=vcpkg%20registry&message=2023-09-08&color=green&style=flat)](https://github.com/Starfield-Reverse-Engineering/Starfield-RE-vcpkg)

### Including CommonLibSF in your project

#### Using the example plugin
( TODO )

#### Manual
CommonLibSF is available as a vcpkg port. To add it to your project, 

1. Create a `vcpkg-configuration.json` file in the project root (next to `vcpkg.json`) OR append the existing `vcpkg.json` with the following contents:

```json
{
    "default-registry": {
        "kind": "git",
        "repository": "https://github.com/microsoft/vcpkg",
        "baseline": "<SHA>"
    },
    "registries": [
        {
            "kind": "git",
            "repository": "https://github.com/Starfield-Reverse-Engineering/Starfield-RE-vcpkg",
            "baseline": "<SHA>",
            "packages": [
                "commonlibsf"
            ]
        }
    ]
}
```

2. Install the package through `vcpkg.json`, append it to your existing dependencies:

```json
{
    "dependencies": [
        "commonlibsf"
    ]
}
```

3. Link it in your `CMakeLists.txt`:

```cmake
find_package(CommonLibSF CONFIG REQUIRED)
target_link_libraries(
    ${PROJECT_NAME}
    PRIVATE
    CommonLibSF::CommonLibSF
)
```
