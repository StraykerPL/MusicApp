import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StyleSheet } from 'react-native';
import GeneralLayout from '../components/GeneralLayout';
import SoundPanel from '../components/SoundPanel';
import { useEffect, useState } from 'react';
import * as MediaLibrary from 'expo-media-library';

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
    });

    return(
        <SafeAreaProvider style={componentStyles}>
            <GeneralLayout>
                <SoundPanel musicName={"Here will be name"} musicAuthor={"Here will be author"} musicAsset={musicFileList[0]}></SoundPanel>
            </GeneralLayout>
        </SafeAreaProvider>
    );
}

const componentStyles = StyleSheet.create({
    height: "100%",
    width: "100%",
    paddingTop: 25
});