
vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO Starfield-Reverse-Engineering/CommonLibSF
  REF 206ebb33392d2ec8b7de5fbac7e17a29dba8bec1
  SHA512 3DEF960040FF1A9331EA98DA6653B8EAA05D7FB91958BB0773713A71DA2D0E581DF3B4E21339E61AFA8CD59B526B5904D0E184E855650ACA6EF5265700B90E9C
  HEAD_REF main)
 
set(VCPKG_POLICY_EMPTY_PACKAGE enabled)

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")

vcpkg_install_cmake()
vcpkg_cmake_config_fixup(
  PACKAGE_NAME CommonLibSF 
  CONFIG_PATH lib/cmake)
vcpkg_copy_pdbs()

file(GLOB CMAKE_CONFIGS "${CURRENT_PACKAGES_DIR}/share/CommonLibSF/CommonLibSF/*.cmake")
file(INSTALL ${CMAKE_CONFIGS} DESTINATION "${CURRENT_PACKAGES_DIR}/share/CommonLibSF")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/share/CommonLibSF/CommonLibSF")

file(
  INSTALL "${SOURCE_PATH}/COPYING"
  DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
  RENAME copyright)
