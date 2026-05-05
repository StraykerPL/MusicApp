# Strayker Music End-user Guide

Strayker Music is a local music player for playing MP3 files from folders you
choose. The app does not scan every folder by default. It builds the music list
from the storage paths configured in Settings.

## Installing the App

### Android package

1. Download the latest Strayker Music APK from the official project release
   page or another trusted source.
2. Open the downloaded APK on your Android device.
3. If Android asks for permission to install apps from this source, allow it for
   the source you are using.
4. Follow the installation prompts.
5. Open Strayker Music from the app launcher.

### Play Store

Placeholder: add Play Store installation steps and link when the Play Store
listing is available.

### F-Droid

Placeholder: add F-Droid installation steps and link when the F-Droid listing is
available.

## First Start and Permissions

On first launch, Android may ask Strayker Music for storage access. Allow the
permission so the app can read MP3 files from the folders you configure.

If the main screen says that no sound files can be displayed, check these items:

- The selected storage folders contain `.mp3` files.
- The app has storage permission in Android settings.
- The selected folders are not restricted system folders.
- The search field is empty or matches the song name you expect to find.

## Start Configuration

Open the navigation drawer from the main screen, then choose **Settings**.

### Configure Music Folders

The app uses the **Storage paths to look for sound files** list to decide where
to search for music. By default, the configured path is:

```text
/storage/emulated/0/Music
```

To add a folder:

1. In Settings, press **+** in the storage paths section.
2. Choose a folder that contains MP3 files.
3. Press **Add selected folder**.
4. Press **Save**.

To remove a folder:

1. Tap the folder path in the storage paths list.
2. Press **-**.
3. Press **Save**.

Avoid selecting restricted Android system folders. Use shared media folders such
as Music, Download, or another folder outside the Android system directory.

### Configure Shuffle Repeat Prevention

The **Amount of repetitive songs prevention queue** setting controls how many
recently played songs are skipped when using shuffle.

- `0` disables repeat prevention.
- A higher number reduces the chance of recently played songs repeating.
- The app limits this value to the number of loaded songs.

Press **Save** after changing the value.

### Restore Default Settings

In Settings, press **Load Default** to restore the default music folder and
repeat-prevention value. Press **Save** if you want to keep those settings.

## Using the Main List

The main screen shows the current playlist. When the title is **Strayker Music**,
the app is showing **All Files**, which contains every loaded MP3 from the
configured storage paths.

Tap a song to play it. The currently selected song is marked with a music note.

The control buttons above the list provide:

- Music note: jump the list to the currently selected song. Press again to jump
  back to the top.
- Search: show or hide the song search field.
- Play/Pause: resume or pause the current song.
- Shuffle: choose and play a random song from the current list.
- Repeat/Next mode: available in custom playlists. Repeat keeps the current
  song looping; next mode moves through the playlist after each song.

The search field filters the visible song list by song name. Clear the field to
show the full current list again.

## Using Playlists

Strayker Music always has an **All Files** list. Custom playlists are created
and deleted in Settings, then selected from the navigation drawer.

### Create a Playlist

1. Open the navigation drawer.
2. Choose **Settings**.
3. In **Playlist Management**, type a playlist name.
4. Press **Create**.

Playlist names must pass the app's text validation and cannot duplicate an
existing playlist name.

### Select a Playlist

1. Open the navigation drawer.
2. Tap **All Files** or one of your custom playlists.

The app bar title changes to the selected playlist name. If a custom playlist is
empty, add songs from **All Files** first.

### Add a Song to a Playlist

1. Select **All Files** from the navigation drawer.
2. Long-press a song.
3. Choose the target playlist from the dialog.

If there are no custom playlists, create one in Settings first.

### Remove a Song from a Playlist

1. Select a custom playlist from the navigation drawer.
2. Long-press the song you want to remove.
3. Confirm removal.

Songs cannot be removed from **All Files** because it is generated from the
configured storage folders.

### Delete a Playlist

1. Open **Settings**.
2. Tap the playlist in **Playlist Management**.
3. Press **Delete**.

Deleting a playlist removes only the playlist entry and its song membership. It
does not delete audio files from device storage.

## Troubleshooting

### No Songs Appear

- Confirm your songs use the `.mp3` extension.
- Add the folder containing your music in Settings.
- Press **Save** after changing storage paths.
- Confirm Android storage permission is enabled for Strayker Music.
- Clear the search field.

### A Folder Cannot Be Selected

The app blocks restricted Android folders. Select a media folder such as Music,
Download, or another folder outside Android system paths.

### Shuffle Repeats Songs Too Often

Increase the repeat-prevention queue value in Settings. The value cannot be
higher than the number of loaded songs minus one.
