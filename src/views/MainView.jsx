import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StyleSheet, View } from 'react-native';
import { useEffect, useState } from 'react';
import * as MediaLibrary from 'expo-media-library';
import MusicList from '../components/MusicList';
import SoundPanel from '../components/SoundPanel';

export default function MainView() {
    const [musicFileList, setMusicFileList] = useState([]);
    const [selectedAssetName, setSelectedAssetName] = useState(undefined);
    const [currentlySelectedMusicAsset, setCurrentlySelectedMusicAsset] = useState();

    const getAllMusicFilesToState = async () => {
        await MediaLibrary.requestPermissionsAsync();
        await MediaLibrary.getAssetsAsync({
            mediaType: MediaLibrary.MediaType.audio,
        }).then((assetsList) => { setMusicFileList(assetsList.assets); });
    };

    const getSelectedMusicAsset = () => {
        musicFileList.forEach(musicAsset => {
            if(musicAsset.filename === selectedAssetName) {
                setCurrentlySelectedMusicAsset(musicAsset);

                return;
            }
        });
    };

    useEffect(() => {
        getAllMusicFilesToState();
    }, []);

    useEffect(() => {
        const intervalId = setInterval(() => {
            getSelectedMusicAsset();
        }, 1000)
        return () => clearInterval(intervalId)
    }, [selectedAssetName]);

    // useEffect(() => {
    //     const intervalId = setInterval(() => {
    //         console.log("---- MainView ----");
    //         console.log("selectedAssetName: " + selectedAssetName);
    //         console.log("currentlySelectedMusicAsset: " + currentlySelectedMusicAsset);
    //     }, 1000)
    //     return () => clearInterval(intervalId)
    // });

    return(
        <SafeAreaProvider style={componentStyles}>
            <View style={componentStyles.viewContainer}>
                <View style={componentStyles.listElement}><MusicList list={musicFileList} updateItem={setSelectedAssetName}></MusicList></View>
                {selectedAssetName !== undefined ? <SoundPanel musicAsset={currentlySelectedMusicAsset}></SoundPanel> : ""}
            </View>
        </SafeAreaProvider>
    );
}

const componentStyles = StyleSheet.create({
    paddingTop: 30,
    viewContainer: {
        flex: 1,
        alignItems: "center"
    },
    listElement: {
        flex: 1
    }
});