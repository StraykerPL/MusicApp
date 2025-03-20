import { useEffect, useState } from "react";
import { StyleSheet, Text, View } from "react-native";
import { Audio } from 'expo-av';
import AntDesign from '@expo/vector-icons/AntDesign';
import { SoundPanelPropsModel } from "src/shared/models/SoundPanelPropsModel";
import { Sound } from "expo-av/build/Audio";
import { Asset } from "expo-media-library";

export default function SoundPanel({ musicAsset }: SoundPanelPropsModel) {
    const [soundBuffor, setSoundBuffor] = useState<Sound>();

    const loadMusicAsset = async () => {
        await soundBuffor?.loadAsync(musicAsset as Asset);
    };

    const play = async () => {
        const status = await soundBuffor?.getStatusAsync();
        if(!status?.isLoaded) {
            await loadMusicAsset();
        }

        await soundBuffor?.playAsync();
    };

    const stop = async () => {
        await soundBuffor?.pauseAsync();
    };

    useEffect(() => {
        setSoundBuffor(new Audio.Sound());
        return soundBuffor ? () => { soundBuffor.unloadAsync(); } : undefined;
    }, []);

    useEffect(() => {    
        async () => {
            await loadMusicAsset();
        };
        return soundBuffor ? () => { soundBuffor.unloadAsync(); } : undefined;
    }, [musicAsset]);

    return(
        <View style={componentStyles.soundPanel}>
            <View style={componentStyles.metaData}>
                <Text>{musicAsset?.filename}</Text>
                {/* <Text>{props.musicAsset.musicAuthor}</Text> */}
            </View>
            <View style={componentStyles.controlButtons}>
                <AntDesign.Button name="caretright" size={16} color="white" onPress={play} />
                <AntDesign.Button name="pause" size={16} color="white" onPress={stop} />
            </View>
        </View>
    );
}

const componentStyles = StyleSheet.create({
    soundPanel: {
        width: 300,
        height: 75,
        display: "flex",
        flexDirection: "row",
        justifyContent: "space-between",
        alignItems: "center",
        paddingRight: 20,
        paddingLeft: 20,
        backgroundColor: "lightblue",
        shadowColor: "#000",
        shadowOffset: {
            width: 0,
            height: 12,
        },
        shadowOpacity: 0.58,
        shadowRadius: 16.00,
        elevation: 24,
    },
    metaData: {
        display: "flex",
        flexDirection: "column",
        maxWidth: 150
    },
    controlButtons: {
        display: "flex",
        flexDirection: "row"
    }
});