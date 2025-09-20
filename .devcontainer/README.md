1) Add the `.devcontainer/` files to the root of the repository (push to a branch or your fork).


2) Open the repo in GitHub and create a Codespace (Code → Codespaces → New codespace on branch...).


3) After the container builds, the `postCreateCommand` runs `flutter pub get`.


4) To run the app in Codespaces (web):
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080


Then in the Codespaces UI, open the Ports pane and make port 8080 public. Open the forwarded URL to preview your app.


5) Notes & limitations:
* Codespaces cannot access host USB devices and cannot start Android emulators inside the container. For mobile testing you can:
- build an APK (`flutter build apk`) and download it to install on a device, or
- run the app on a physical device connected to your laptop and use ADB over network (advanced), or
- use a remote device farm / simulator outside Codespaces.
* If you need CI/Release builds for Android, consider using GitHub Actions with a runner that has Android toolchain or use the `Dockerfile.android` and a larger Codespace machine, but check disk and CPU requirements.
