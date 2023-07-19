import { useState } from 'react';
import * as MediaLibrary from 'expo-media-library';
import { Audio } from 'expo-av';
import MainView from './src/views/MainView';

export default function App() {
  const [media, setMedia] = useState(null);
  const [fileList, setFileList] = useState([]);
  const [sound, setSound] = useState();

  const ok = async () => {
    await MediaLibrary.requestPermissionsAsync();
    const media = await MediaLibrary.getAssetsAsync({
      mediaType: MediaLibrary.MediaType.audio,
    });

    setMedia(media);
    setFileList(media.assets);
  };

  const play = async () => {
    const { sound } = await Audio.Sound.createAsync(fileList[0]);
    setSound(sound);

    await sound.playAsync();
  };

  const stop = async () => {
    await sound.unloadAsync();
  };

  return (
    <MainView></MainView>
  );
}
