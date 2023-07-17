import { useState } from 'react';
import { FlatList, Button, StyleSheet, Text, View } from 'react-native';
import * as MediaLibrary from 'expo-media-library';
import { Audio } from 'expo-av';

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
    <View style={styles.container}>
      <Text>Open up App.js to start working on your app!</Text>
      <Button title='Press to get music!' onPress={ok}></Button>
      {console.log(media)}
      <FlatList
        data={fileList}
        renderItem={({item}) => <Button title={item.filename} onPress={play}></Button>}
      />
      <Button title='Stop Music' onPress={stop}></Button>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    display: 'flex',
    flexDirection: "column",
    backgroundColor: 'grey',
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%'
  },
});
