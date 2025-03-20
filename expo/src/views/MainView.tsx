import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StyleSheet, View } from 'react-native';
import { useEffect, useState } from 'react';
import MusicList from '../components/MusicList';
import SoundPanel from '../components/SoundPanel';
import { Asset, getAssetsAsync, requestPermissionsAsync, MediaType, PagedInfo } from 'expo-media-library';

export default function MainView() {
    const [musicFileList, setMusicFileList] = useState<Asset[]>([]);
    const [selectedAssetName, setSelectedAssetName] = useState<string>();
    const [currentlySelectedMusicAsset, setCurrentlySelectedMusicAsset] = useState<Asset>();

    const getAllMusicFilesToState = async () => {
        await requestPermissionsAsync();
        await getAssetsAsync({
            mediaType: MediaType.audio
        }).then((assetsList: PagedInfo<Asset>) => { setMusicFileList(assetsList.assets); });
    };

    const getSelectedMusicAsset = () => {
        musicFileList.forEach((musicAsset: Asset) => {
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
        const intervalId: NodeJS.Timer = setInterval(() => {
            getSelectedMusicAsset();
        }, 1000);
        return () => clearInterval(intervalId);
    }, [selectedAssetName]);

    return(
        <SafeAreaProvider style={componentStyles.default}>
            <View style={componentStyles.viewContainer}>
                <View style={componentStyles.listElement}><MusicList list={musicFileList} updateItem={setSelectedAssetName}></MusicList></View>
                {selectedAssetName !== undefined ? <SoundPanel musicAsset={currentlySelectedMusicAsset}></SoundPanel> : ""}
            </View>
        </SafeAreaProvider>
    );
}

const componentStyles = StyleSheet.create({
    default: {
        paddingTop: 30
    },
    viewContainer: {
        flex: 1,
        alignItems: "center"
    },
    listElement: {
        flex: 1
    }
});