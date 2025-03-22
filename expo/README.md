# MusicApp

This project is a simple PoC of mobile application, on React Native.

Cases to check:
- how much time is needed to create app?
- what knowledge is needed?
- what hardware is required for development process?

## Tech Stack

- React Native,
- TypeScript,
- Expo Framework,

## Getting Started

There are two branches in this repo: `main` and `migrate-from-expo`.
The first one delivers MusicApp on Expo Framework, second one contains migrated code from Expo, which is not working, because everything Expo-related was remove. On this branch, I've performed some research work with external React Native libraries without commiting to branch.

Steps to run app locally:

- Setup environment for Expo, [tutorial here](https://reactnative.dev/docs/environment-setup?guide=quickstart), or setup environment for native development, [tutorial here](https://reactnative.dev/docs/environment-setup?guide=native),
- Clone repo,
- Run `npm install` or `yarn install`,
- Run command provided in `project.json` for `start` script, depending on selected branch,

## PoC Results

- It's possible to create such app in about 2 days, with Expo Framework and not following best practices/project patterns. This value is predicted for developer, that already knows Expo and React Native.
When developing without Expo, time will be about 3-5 days (same, not following any good practices/patterns). That's because clear React Native requires using external third-party libraries. Problem is here, that a lot of libraries requires some configuration and most of them are not maintained activly, so more errors are likely to happen during work. Libraries checked are listed below:

    - [react-native-sound](https://github.com/zmxv/react-native-sound) - not supported,
    - [react-native-get-music-files](https://github.com/cinder92/react-native-get-music-files) - not supported,
    - [react-native-track-player](https://github.com/doublesymmetry/react-native-track-player) - supported, TypeScript config + file system library needed,
    - [react-native-file-access](https://github.com/alpha0010/react-native-file-access) - supported, compatibility needs to be maintained based on React Native version + config in Gradle,
    - [react-native-audio-toolkit](https://github.com/react-native-audio-toolkit/react-native-audio-toolkit) - not supported, Gradle + Java code config + local playback only on Android + file system library needed,

- React Native + TypeScript + StyleSheet API is a must, at least Junior level. Expo Framework knowledge is not strictly necessary, depends on chosen approach.

- All info about support can be shown by switching "Development OS" and "Target OS" on "Native" tab of React Native docs [here](https://reactnative.dev/docs/environment-setup), Expo-based development is possible on every platform, where Node.js is available.

## Licensing

This project is licensed under MIT/X11 license.

## Contact

If you have any suggestions or you want to ask me something, go to official [Strayker Software Discord Server!](https://discord.gg/ytdkCVD)
