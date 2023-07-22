import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StyleSheet, View } from 'react-native';
import { useEffect, useState } from 'react';
import * as MediaLibrary from 'expo-media-library';
import MusicList from '../components/MusicList';
import SoundPanel from '../components/SoundPanel';

export default function MainView() {
    const [musicFileList, setMusicFileList] = useState([]);

    const getAllMusicFilesToState = async () => {
        await MediaLibrary.requestPermissionsAsync();
        const assetsList = await MediaLibrary.getAssetsAsync({
            mediaType: MediaLibrary.MediaType.audio,
        });

        setMusicFileList(assetsList.assets);
    };

    useEffect(() => {
        getAllMusicFilesToState();
    }, []);

    return(
        <SafeAreaProvider style={componentStyles}>
            <View style={componentStyles.viewContainer}>
                <View style={componentStyles.listElement}><MusicList list={musicFileList}></MusicList></View>
                <SoundPanel musicAsset={musicFileList[0]}></SoundPanel>
            </View>
        </SafeAreaProvider>
    );
}

const componentStyles = StyleSheet.create({
    paddingTop: 25,
    viewContainer: {
        flex: 1,
        alignItems: "center"
    },
    listElement: {
        flex: 1
    }
});