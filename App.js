import { useState } from 'react';
import * as MediaLibrary from 'expo-media-library';
import MainView from './src/views/MainView';

export default function App() {
  const [media, setMedia] = useState(null);
  const [fileList, setFileList] = useState([]);

  const ok = async () => {
    await MediaLibrary.requestPermissionsAsync();
    const media = await MediaLibrary.getAssetsAsync({
      mediaType: MediaLibrary.MediaType.audio,
    });

    setMedia(media);
    setFileList(media.assets);
  };

  return (
    <MainView></MainView>
  );
}
