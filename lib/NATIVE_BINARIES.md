# Vendored native binaries

`objectbox.dll` is retained so Dart and Flutter tests launched from the project
root can load ObjectBox on Windows. The ObjectBox Dart loader checks
`lib/objectbox.dll` before relying on the operating system search path.

- Upstream: ObjectBox C `v5.3.2`
- Release asset: `objectbox-windows-x64.zip`
- Release URL: <https://github.com/objectbox/objectbox-c/releases/download/v5.3.2/objectbox-windows-x64.zip>
- Release asset SHA-256: `57d7db013bbb46efe415307c9f3baf7564bdc40818ee1f1c42046f4241403d63`
- `lib/objectbox.dll` SHA-256: `614d00e1f6c7b23d676e784c39b67f56ed6a7889d172e7080ac52122d4695c6e`

CI verifies the DLL hash before tests. When upgrading ObjectBox, download the
new official release asset, verify its published digest, replace the DLL, and
update both this document and the CI hash in the same change.
